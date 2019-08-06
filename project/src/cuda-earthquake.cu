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

#define BLKSIZE 1024

/* energia massima */
#define EMAX 4.0f
/* energia da aggiungere ad ogni timestep */
#define EDELTA 1e-4
/* dimensione halo */
#define HALO 1

/**
 * Restituisce un puntatore all'elemento di coordinate (i,j) del
 * dominio grid con n colonne.
 */
static inline float *IDX(float *grid, int i, int j, int n)
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
    for ( int i=0; i<n; i++ ) {
        for ( int j=0; j<n; j++ ) {
            *IDX(grid, i, j, n) = randab(fmin, fmax);
        }
    }
}

/**
 * Somma delta a tutte le celle del dominio grid di dimensioni
 * n*n. Questa funzione realizza il passo 1 descritto nella specifica
 * del progetto.
 */
void increment_energy( float *grid, int n, float delta )
{
    for (int i=0; i<n; i++) {
        for (int j=0; j<n; j++) {
            *IDX(grid, i, j, n) += delta;
        }
    }
}

/**
 * Restituisce il numero di celle la cui energia e' strettamente
 * maggiore di EMAX.
 */
void count_cells( float *grid, int n, int *c)
{
    *c = 0;
    for (int i=0; i<n; i++) {
        for (int j=0; j<n; j++) {
            if ( *IDX(grid, i, j, n) > EMAX ) { (*c)++; }
        }
    }
}

/**
 * Distribuisce l'energia di ogni cella a quelle adiacenti (se
 * presenti). cur denota il dominio corrente, next denota il dominio
 * che conterra' il nuovo valore delle energie. Questa funzione
 * realizza il passo 2 descritto nella specifica del progetto.
 */
void propagate_energy( float *cur, float *next, int n )
{
    const float FDELTA = EMAX/4;
    for (int i=0; i<n; i++) {
        for (int j=0; j<n; j++) {
            float F = *IDX(cur, i, j, n);
            float *out = IDX(next, i, j, n);

            /* Se l'energia del vicino di sinistra (se esiste) e'
               maggiore di EMAX, allora la cella (i,j) ricevera'
               energia addizionale FDELTA = EMAX/4 */
            if ((j>0) && (*IDX(cur, i, j-1, n) > EMAX)) { F += FDELTA; }
            /* Idem per il vicino di destra */
            if ((j<n-1) && (*IDX(cur, i, j+1, n) > EMAX)) { F += FDELTA; }
            /* Idem per il vicino in alto */
            if ((i>0) && (*IDX(cur, i-1, j, n) > EMAX)) { F += FDELTA; }
            /* Idem per il vicino in basso */
            if ((i<n-1) && (*IDX(cur, i+1, j, n) > EMAX)) { F += FDELTA; }

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
}

/**
 * Restituisce l'energia media delle celle del dominio grid di
 * dimensioni n*n. Il dominio non viene modificato.
 */
void average_energy(float *grid, int n, float *Emean)
{
    float sum = 0.0f;
    for (int i=0; i<n; i++) {
        for (int j=0; j<n; j++) {
            sum += *IDX(grid, i, j, n);
        }
    }

    *Emean = (sum / (n*n));
}

int main( int argc, char* argv[] )
{
    float *cur;
    float *d_cur, *d_next;
    int s, n = 256, nsteps = 2048;
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
        n = atoi(argv[2]);
    }

    /* n (e size) è la dimensione COMPRESA di HALO */
    n = n + (2 * HALO);
    const size_t domain_size = n*n*sizeof(float);
    const size_t counter_size = sizeof(int);
    const size_t emean_size = sizeof(float);

    /* Allochiamo i domini */
    cur = (float*)malloc(domain_size);
    assert(cur);

    /* Allocate space for device copies of cur, next, c*/
    CudaSafeCall(cudaMalloc((void **)&d_cur, domain_size) );
    CudaSafeCall(cudaMalloc((void **)&d_next, domain_size) );
    CudaSafeCall(cudaMalloc((void **)&d_c, counter_size) );
    CudaSafeCall(cudaMalloc((void **)&d_Emean, emean_size) );

    /* L'energia iniziale di ciascuna cella e' scelta
       con probabilita' uniforme nell'intervallo [0, EMAX*0.1] */
    setup(cur, n, 0, EMAX*0.1);

    /* Copying data from host to device */
    cudaMemcpy(d_cur, &cur, domain_size, cudaMemcpyHostToDevice);

    const double tstart = hpc_gettime();
    for (s=0; s<nsteps; s++) {

        /* L'ordine delle istruzioni che seguono e' importante */
        /*
        increment_energy(cur, n, EDELTA);
        c = count_cells(cur, n);
        propagate_energy(cur, next, n);
        Emean = average_energy(next, n);
        */

        increment_energy<<<1,1>>>(d_cur, n, EDELTA);

        count_cells<<<1,1>>>(d_cur, n, d_c); /* kernel must return void -> changed */
        cudaMemcpy(&c, d_c, counter_size, cudaMemcpyDeviceToHost);

        propagate_energy<<<1,1>>>(d_cur, d_next, n);

        average_energy<<<1,1>>>(d_next, n, d_Emean); /* kernel must return void -> changed */
        cudaMemcpy(&Emean, d_Emean, emean_size, cudaMemcpyDeviceToHost);

        printf("%d %f\n", c, Emean);

        /* swap cur and next on the GPU */
        float *d_tmp = d_cur;
        d_cur = d_next;
        d_next = d_tmp;
    }
    const double elapsed = hpc_gettime() - tstart;

    double Mupdates = (((double)n)*n/1.0e6)*nsteps; /* milioni di celle aggiornate per ogni secondo di wall clock time */
    fprintf(stderr, "%s : %.4f Mupdates in %.4f seconds (%f Mupd/sec)\n", argv[0], Mupdates, elapsed, Mupdates/elapsed);

    /* Libera la memoria */
    free(cur);

    /* Libera la memoria */
    cudaFree(d_cur);
    cudaFree(d_next);
    cudaFree(d_c);
    cudaFree(d_Emean);

    return EXIT_SUCCESS;
}
