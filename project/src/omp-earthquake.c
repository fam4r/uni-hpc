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

/* energia massima */
#define EMAX 4.0f
/* energia da aggiungere ad ogni timestep */
#define EDELTA 1e-4f
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
    int i = 0, j = 0;

    /* Inizializzo la matrice reale (SENZA HALO) con i valori casuali */
    for (i = HALO; i < n - HALO; i++ ) {
        for (j = HALO; j < n - HALO; j++ ) {
            *IDX(grid, i, j, n) = randab(fmin, fmax);
        }
    }

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
}

/**
 * Somma delta a tutte le celle del dominio grid di dimensioni
 * n*n. Questa funzione realizza il passo 1 descritto nella specifica
 * del progetto.
 */
void increment_energy( float *grid, int n, float delta )
{
    /* Only add delta for internal (NO HALO) matrix cells */
#pragma omp parallel for default(none) shared(n,delta,grid)
    for (int i = HALO; i < n - HALO; i++) {
        for (int j = HALO; j < n - HALO; j++) {
            *IDX(grid, i, j, n) += delta;
        }
    }
}

/**
 * Restituisce il numero di celle la cui energia e' strettamente
 * maggiore di EMAX.
 */
int count_cells( float *grid, int n )
{
    /* Looping the internal (NO HALO) matrix */
    int c = 0;
#pragma omp parallel for default(none) shared(n,grid) reduction(+:c)
    for (int i = HALO; i < n - HALO; i++) {
        for (int j = HALO; j < n - HALO; j++) {
            if ( *IDX(grid, i, j, n) > EMAX ) {
                c++;
            }
        }
    }
    return c;
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
#pragma omp parallel for default(none) shared(n,cur,next) collapse(2)
    for (int i = HALO; i < n - HALO; i++) {
        for (int j = HALO; j < n - HALO; j++) {
            float F = *IDX(cur, i, j, n);
            float *out = IDX(next, i, j, n);

            /* Se l'energia del vicino di sinistra (se esiste) e'
               maggiore di EMAX, allora la cella (i,j) ricevera'
               energia addizionale FDELTA = EMAX/4 */
            /* Looking to all neighbors*/

            if (*IDX(cur, i, j - 1, n) > EMAX) { F += FDELTA; }
            if (*IDX(cur, i, j + 1, n) > EMAX) { F += FDELTA; }
            if (*IDX(cur, i - 1, j, n) > EMAX) { F += FDELTA; }
            if (*IDX(cur, i + 1, j, n) > EMAX) { F += FDELTA; }

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
float average_energy(float *grid, int n)
{
    float sum = 0.0f;
#pragma omp parallel for default(none) shared(n,grid) reduction(+:sum)
    for (int i = HALO; i < n - HALO; i++) {
        for (int j = HALO; j < n - HALO; j++) {
            sum += *IDX(grid, i, j, n);
        }
    }
    return (sum / (n*n));
}

int main( int argc, char* argv[] )
{
    float *cur, *next;
    int s, n = 256, nsteps = 2048;
    float Emean;
    int c;

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
    const size_t size = n*n*sizeof(float);

    /* Allochiamo i domini */
    cur = (float*)malloc(size); assert(cur);
    next = (float*)malloc(size); assert(next);

    /* L'energia iniziale di ciascuna cella e' scelta
       con probabilita' uniforme nell'intervallo [0, EMAX*0.1] */
    /* L'inizializzazione delle ghost cell a 0 è gestita internamente */
    const double ts_start = hpc_gettime();
    setup(cur, n, 0, EMAX*0.1f);
    const double s_elapsed = hpc_gettime() - ts_start;
    fprintf(stderr, "%s : %.8f seconds taken for serial portion\n", argv[0], s_elapsed);

    const double tp_start = hpc_gettime();
    for (s=0; s<nsteps; s++) {
        /* L'ordine delle istruzioni che seguono e' importante */
        increment_energy(cur, n, EDELTA);
        c = count_cells(cur, n);
        propagate_energy(cur, next, n);
        Emean = average_energy(next, n);

        printf("%d %f\n", c, Emean);

        float *tmp = cur;
        cur = next;
        next = tmp;
    }
    const double p_elapsed = hpc_gettime() - tp_start;

    double Mupdates = (((double)n)*n/1.0e6f)*nsteps; /* milioni di celle aggiornate per ogni secondo di wall clock time */
    fprintf(stderr, "%s : %.4f Mupdates in %.4f seconds (%f Mupd/sec)\n", argv[0], Mupdates, p_elapsed, Mupdates/p_elapsed);
    fprintf(stderr, "%s : %.4f seconds taken for parallel portion\n", argv[0], p_elapsed);
    fprintf(stderr, "%s : Total execution time: %.4f seconds\n", argv[0], s_elapsed + p_elapsed);
    fprintf(stderr, "%s : alpha value (fraction of the total execution time of the serial program): %.8f\n", argv[0], s_elapsed/(s_elapsed + p_elapsed));

    /* Libera la memoria */
    free(cur);
    free(next);

    return EXIT_SUCCESS;
}
