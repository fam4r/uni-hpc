# HPC Project

Fabrizio Margotta 789072

HPC course - Professor Moreno Marzolla

Ingegneria e Scienze Informatiche

Università di Bologna - Sede di Cesena

Academic Year 2018/2019

## Description

https://www.moreno.marzolla.name/teaching/high-performance-computing/2018-2019/earthquake.html

> Lo scopo del progetto è di implementare versioni parallele di un semplice
> modello matematico di propagazione dei terremoti. Il modello che consideriamo
> è una estensione in due dimensioni dell’automa cellulare [Burridge-Knopoff
> (BK)](https://pubs.geoscienceworld.org/ssa/bssa/article-abstract/57/3/341/116471/model-and-theoretical-seismicity).

## Details

I chose OpenMP and CUDA implementations.

## Report

The report can be found in `./report/report-789072.pdf`.

## Errors

:warning: reported errors, try to not make the same mistakes in your project :warning:

- OpenMP: it is unnecessary to run tests with more threads than the number of
    logical processors: the overhead is expected in that case and should not be
    reported
- the formula for the `alpha` parameter is wrong, the correct one derived from
    the definition of Tparallel is `alpha = (p T_parallel - T_serial) / (p
    T_serial - T_serial)` and in any case it is useful to informally demonstrate
    Moore's law "only"; clearly it should not be considered in your report
- a weak scaling > 1 is a nonsense, if you obtain such results you may want to
    review the operation used to compute the matrix size, eg.
    - given p the number of processors
    - given N the initial matrix size
    - given a O(n^2) algorithm
    - the matrix size should be proportional to sqrt(p)
- avoid the use of atomic functions (such as `atomicAdd`) in CUDA computations
    for reduction operators: it basically leads to serial computations
    - use shared memory to compute partial reductions for each thread block
        instead
    - perform atomic operations to accumulate a final result using the partial
        ones, if necessary
    - see http://developer.download.nvidia.com/assets/cuda/files/reduction.pdf

## Requirements

Install OpenMP and CUDA in your system (ArchLinux `openmp` and `cuda`).

To plot install Matplotlib and NumPy (ArchLinux `python-matplotlib` and
`python-numpy`).

### Unibo usage

I provided useful `zsh-autoenv` functions to send sources, compile, compute and
get results from Unibo servers.

Provide a proper ssh configuration, like:

```ssh-config
Host uniomp unicuda uniext
    User [redacted]

Host uniext
    HostName [redacted]

Host uniomp
    HostName [redacted]
    ProxyJump uniext
```

so you can use commands like `runcuda`.

## OpenMP

Compile:

```bash
cd src
make clean
make openmp
```

Run simulation:

```bash
./omp-earthquake [nsteps [n]] > ./data/omp-simulation.dat

# example
./omp-earthquake 100000 256 > ./data/omp-simulation.dat
```

Plot simulation results running `plot-simulation.py`. The graph will be located
at `graphs/omp-earthquake.png`.

### Performance evaluation

Run `hpc-perf-evaluation.py`.

More info [here](#performance-evaluation-script).

Results will be available in the `data` folder as CSV files.

#### Weak scaling

Understanding professor's script:

```
N0=256
# p from 1 to 64 for example
PROB_SIZE=`echo -e "e(l($N0 * $N0 * $N0 * $p)/3)" | bc -l -q`
```

See: http://phodd.net/gnu-bc/bcfaq.html

## CUDA

Compile:

```bash
cd src
make clean
make cuda
```

Run simulation:

```bash
./cuda-earthquake [nsteps [n]] > ./data/cuda-simulation.dat

# example
./cuda-earthquake 100000 256 > ./data/cuda-simulation.dat
```

Plot simulation results running `plot-timings-cuda.py`. The graph will be
located at `graphs/cuda-timings.png`.

### Performance evaluation

Run `hpc-perf-evaluation-cuda.py`.

More info [here](#performance-evaluation-script).

Results will be available in the `data` folder as CSV files.

## Performance evaluation script

Made for problems involving matrixes, but built for general-purpose uses.

Program timings **must** be managed and printed by the program itself, since a
wrapper script like that one cannot separately consider the serial and the
parallel portions of the execution time.

### Features

- supports multiple domain size (matrix size)
- computes average execution time (by running the program N times)
- computes speedup
- computes strong scaling
- computes weak scaling
- saves computation results into CSV files (easy to plot!)
- verbose logging
