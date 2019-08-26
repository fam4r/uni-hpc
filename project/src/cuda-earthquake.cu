/* Fabrizio Margotta 789072 */

/****************************************************************************
 *
 * earthquake.c - Simple 2D earthquake model
 *
 * Copyright (C) 2018 Moreno Marzolla <moreno.marzolla(at)unibo.it>
 * Last updated on 2018-12-29
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * ---------------------------------------------------------------------------
 *
 * Versione di riferimento del progetto di High Performance Computing
 * 2018/2019, corso di laurea in Ingegneria e Scienze Informatiche,
 * Universita' di Bologna. Per una descrizione del modello si vedano
 * le specifiche sulla pagina del corso:
 *
 * http://moreno.marzolla.name/teaching/HPC/
 *
 * Per compilare:
 *
 * gcc -D_XOPEN_SOURCE=600 -std=c99 -Wall -Wpedantic earthquake.c -o earthquake
 *
 * (il flag -D_XOPEN_SOURCE=600 e' superfluo perche' viene settato
 * nell'header "hpc.h", ma definirlo tramite la riga di comando fa si'
 * che il programma compili correttamente anche se inavvertitamente
 * non si include "hpc.h", o per errore non lo si include come primo
 * file come necessario).
 *
 * Per eseguire il programma si puo' usare la riga di comando seguente:
 *
 * ./earthquake 100000 256 > out
 *
 * Il primo parametro indica il numero di timestep, e il secondo la
 * dimensione (lato) del dominio. L'output consiste in coppie di
 * valori numerici (100000 in questo caso) il cui significato e'
 * spiegato nella specifica del progetto.
 *
 ****************************************************************************/
#include "hpc.h"
#include <stdio.h>
#include <stdlib.h>     /* rand() */
#include <assert.h>

/* We use 2D blocks of size (BLKDIM * BLKDIM) to compute
   the next configuration of the automaton */
#define BLKDIM 32

/* We use 1D blocks of (BLKDIM_REDUCTION) threads to perform reduction
 * operations */
#define BLKDIM_REDUCTION 1024

/* energia massima */
#define EMAX 4.0f
/* energia da aggiungere ad ogni timestep */
#define EDELTA 1e-4f
/* dimensione halo */
#define HALO 1

/**
 * Restituisce un puntatore all'elemento di coordinate (i,j) del
 * dominio grid con n colonne.
 * NB: n è comprensiovo di HALO.
 */
__device__ __host__ static inline float *IDX(float *grid, int i, int j, int n)
{
    return (grid + i*n + j);
}

/**
 * Restituisce un numero reale pseudocasuale con probabilita' uniforme
 * nell'intervallo [a, b], con a < b.
 */
float randab( float a, float b )
{
    return a + (b-a)*(rand() / (float)RAND_MAX);
}

/**
 * Inizializza il dominio grid di dimensioni n*n con valori di energia
 * scelti con probabilità uniforme nell'intervallo [fmin, fmax], con
 * fmin < fmax.
 *
 * NON PARALLELIZZARE QUESTA FUNZIONE: rand() non e' thread-safe,
 * qundi non va usata in blocchi paralleli OpenMP; inoltre la funzione
 * non si "comporta bene" con MPI (i dettagli non sono importanti, ma
 * posso spiegarli a chi e' interessato). Di conseguenza, questa
 * funzione va eseguita dalla CPU, e solo dal master (se si usa MPI).
 */
void setup( float* grid, int n, float fmin, float fmax )
{
    int i = 0, j = 0;

#ifdef PRINT_DEBUG
    fprintf(stderr, "setup: start internal matrix\n");
#endif
    /* Inizializzo la matrice interna (SENZA HALO) con i valori casuali */
    for(i = HALO; i < n - HALO; i++) {
        for(j = HALO; j < n - HALO; j++) {
            *IDX(grid, i, j, n) = randab(fmin, fmax);
        }
    }
#ifdef PRINT_DEBUG
    fprintf(stderr, "setup: internal matrix complete\n");
#endif

    /*
     * Note: assuming max HALO value = 1
     * If HALO would be bigger, those loops need to be handled
     * by external-looping other HALO layers (concept idea).
     */

    /* Fill matrix top and bottom with zeroes (HALO) */
    for (j = 0 ; j < n; j++) {
        *IDX(grid, 0, j, n) = 0.0f; /* TOP */
        *IDX(grid, j, 0, n) = 0.0f; /* LEFT */
        *IDX(grid, n - HALO, j, n) = 0.0f; /* BOTTOM */
        *IDX(grid, j, n - HALO, n) = 0.0f; /* RIGHT */
    }
#ifdef PRINT_DEBUG
    fprintf(stderr, "setup: halo complete\n");
#endif
}

/**
 * Somma delta a tutte le celle del dominio grid di dimensioni
 * n*n. Questa funzione realizza il passo 1 descritto nella specifica
 * del progetto.
 */
__global__ void increment_energy(float *grid, int n, float delta)
{
    const int i = HALO + blockIdx.y * blockDim.y + threadIdx.y;
    const int j = HALO + blockIdx.x * blockDim.x + threadIdx.x;

    if (i < n - HALO && j < n - HALO) {
        *IDX(grid, i, j, n) += delta;
    }
}

/**
 * Restituisce il numero di celle la cui energia e' strettamente
 * maggiore di EMAX.
 */
__global__ void count_cells(float *grid, int n, int *c)
{
    const int i = HALO + blockIdx.x * blockDim.x + threadIdx.x;
    const int array_size = n * n;

    /* concept
       sono un thread (cella)
       se mio valore > EMAX
       scrivo 1 nella variabile
       */

    /* nelle note ho scritto che le operazioni atomiche su N grandi sono
     * dispensiose, forse non conviene lasciarlo così, provare a fare un array
     * grande n*n in cui in ogni cella un thread salva 1 o 0 in base a se il
     * valore supera EMAX e poi faccio la riduzione su quell'array */

    /* usare && */
    if (i < array_size) {
        if ( grid[i] > EMAX ) {
            atomicAdd(c, 1);
        }
    }
}

/**
 * Distribuisce l'energia di ogni cella a quelle adiacenti (se
 * presenti). cur denota il dominio corrente, next denota il dominio
 * che conterra' il nuovo valore delle energie. Questa funzione
 * realizza il passo 2 descritto nella specifica del progetto.
 */
__global__ void propagate_energy( float *cur, float *next, int n )
{
    const int i = HALO + blockIdx.y * blockDim.y + threadIdx.y;
    const int j = HALO + blockIdx.x * blockDim.x + threadIdx.x;

    const float FDELTA = EMAX/4;
    float F = *IDX(cur, i, j, n);
    float *out = IDX(next, i, j, n);

    if (i < n - HALO && j < n - HALO) {
        if ((j > 0)     && (*IDX(cur, i, j - 1, n) > EMAX)) { F += FDELTA; }
        if ((j < n - 1) && (*IDX(cur, i, j + 1, n) > EMAX)) { F += FDELTA; }
        if ((i > 0)     && (*IDX(cur, i - 1, j, n) > EMAX)) { F += FDELTA; }
        if ((i < n - 1) && (*IDX(cur, i + 1, j, n) > EMAX)) { F += FDELTA; }

        if (F > EMAX) {
            F -= EMAX;
        }

        /* Si noti che il valore di F potrebbe essere ancora
           maggiore di EMAX; questo non e' un problema:
           l'eventuale eccesso verra' rilasciato al termine delle
           successive iterazioni vino a riportare il valore
           dell'energia sotto la foglia EMAX. */
        *out = F;
    }
}

/**
 * Restituisce l'energia media delle celle del dominio grid di
 * dimensioni n*n. Il dominio non viene modificato.
 */
__global__ void average_energy(float *grid, int n, float *Emean)
{
    const int i = HALO + blockIdx.x * blockDim.x + threadIdx.x;
    const int array_size = n * n;

    if (i < array_size) {
        atomicAdd(Emean, grid[i]);
    }
}

int main( int argc, char* argv[] )
{
    float *cur;
    float *d_cur, *d_next;
    int s, width = 256, nsteps = 2048;
    float Emean;
    float *d_Emean;
    int c;
    int *d_c;

    srand(19); /* Inizializzazione del generatore pseudocasuale */

    if ( argc > 3 ) {
        fprintf(stderr, "Usage: %s [nsteps [n]]\n", argv[0]);
        return EXIT_FAILURE;
    }

    if ( argc > 1 ) {
        nsteps = atoi(argv[1]);
    }

    if ( argc > 2 ) {
        width = atoi(argv[2]);
    }

    /* width (e size) è la dimensione COMPRESA di HALO */
    width = width + (2 * HALO);
    const size_t domain_size = width*width*sizeof(float *);
    const size_t count_size = sizeof(int);
    const size_t emean_size = sizeof(float);

    /* 1D thread blocks used for reduction operations */
    dim3 reduBlock(BLKDIM_REDUCTION);
    dim3 reduGrid((width + BLKDIM_REDUCTION-1)/BLKDIM_REDUCTION);

    /* 2D thread blocks used for the update step */
    dim3 stepBlock(BLKDIM, BLKDIM);
    dim3 stepGrid((width + BLKDIM-1)/BLKDIM, (width + BLKDIM-1)/BLKDIM);

    /* Allochiamo i domini */
    cur = (float*)malloc(domain_size);
    assert(cur);

    /* Allocate space for device copies of cur, next, c*/
    cudaSafeCall(cudaMalloc((void **)&d_cur, domain_size) );
    cudaSafeCall(cudaMalloc((void **)&d_next, domain_size) );
    cudaSafeCall(cudaMalloc((void **)&d_c, count_size) );
    cudaSafeCall(cudaMalloc((void **)&d_Emean, emean_size) );
#ifdef PRINT_DEBUG
    fprintf(stderr, "cudaMalloc complete\n");
#endif
    /* L'energia iniziale di ciascuna cella e' scelta
       con probabilita' uniforme nell'intervallo [0, EMAX*0.1] */
    setup(cur, width, 0, EMAX*0.1);
#ifdef PRINT_DEBUG
    fprintf(stderr, "setup complete\n");
#endif

    /* Copying data from host to device */
    cudaMemcpy(&d_cur, &cur, domain_size, cudaMemcpyHostToDevice);
#ifdef PRINT_DEBUG
    fprintf(stderr, "cudaMemcpy (host -> device) complete\n");
#endif
    c = 0;
    cudaMemcpy(d_c, &c, count_size, cudaMemcpyHostToDevice);
#ifdef PRINT_DEBUG
    fprintf(stderr, "cudaMemcpy (host -> device) complete\n");
#endif
    Emean = 0.0f;
    cudaMemcpy(d_Emean, &Emean, emean_size, cudaMemcpyHostToDevice);
#ifdef PRINT_DEBUG
    fprintf(stderr, "cudaMemcpy (host -> device) complete\n");
#endif

    const double tstart = hpc_gettime();
    for (s=0; s<nsteps; s++) {
        /* L'ordine delle istruzioni che seguono e' importante */

        /* increment_energy(cur, width, EDELTA); */
        /* <<<nBlocks, nThreadsPerBlock>>> */
        increment_energy<<<stepGrid, stepBlock>>>(d_cur, width, EDELTA);
        cudaDeviceSynchronize();

        /* c = count_cells(cur, width); */
        /* RIDUZIONE -> thread block 1D */
        count_cells<<<reduGrid, reduBlock>>>(d_cur, width, d_c); /* kernel must return void -> changed */
        cudaDeviceSynchronize();
        cudaMemcpy(&c, d_c, count_size, cudaMemcpyDeviceToHost);

        /* propagate_energy(cur, next, width); */
        propagate_energy<<<stepGrid, stepBlock>>>(d_cur, d_next, width);
        cudaDeviceSynchronize();

        /* Emean = average_energy(next, width); */
        /* RIDUZIONE -> thread block 1D */
        average_energy<<<reduGrid, reduBlock>>>(d_next, width, d_Emean); /* kernel must return void -> changed */
        cudaDeviceSynchronize();
        cudaMemcpy(&Emean, d_Emean, emean_size, cudaMemcpyDeviceToHost);
        /* compute mean in CPU */
        Emean = (Emean / (width * width));

        printf("%d %f\n", c, Emean);

        /* swap cur and next on the GPU */
        float *d_tmp = d_cur;
        d_cur = d_next;
        d_next = d_tmp;
    }
    const double elapsed = hpc_gettime() - tstart;

    double Mupdates = (((double)width)*width/1.0e6)*nsteps; /* milioni di celle aggiornate per ogni secondo di wall clock time */
    fprintf(stderr, "%s : %.4f Mupdates in %.4f seconds (%f Mupd/sec)\n", argv[0], Mupdates, elapsed, Mupdates/elapsed);

    /* Free memory on host */
    free(cur);
    /* Free memory on device */
    cudaFree(d_cur);
    cudaFree(d_next);
    cudaFree(d_c);
    cudaFree(d_Emean);

    return EXIT_SUCCESS;
}
