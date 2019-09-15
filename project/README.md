# HPC Project

Fabrizio Margotta 789072

HPC course - Professor Moreno Marzolla

Ingegneria e Scienze Informatiche

Università di Bologna - Sede di Cesena

Academic Year 2018/2019

## Description

https://www.moreno.marzolla.name/teaching/high-performance-computing/2018-2019/earthquake.html

> Lo scopo del progetto è di implementare versioni parallele di un semplice modello matematico di propagazione dei terremoti. Il modello che consideriamo è una estensione in due dimensioni dell’automa cellulare [Burridge-Knopoff (BK)](https://pubs.geoscienceworld.org/ssa/bssa/article-abstract/57/3/341/116471/model-and-theoretical-seismicity).

## Details

I chose OpenMP and CUDA implementations.

## Report

The report can be found in `./report/report-789072.pdf`.

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
./omp-earthquake [nsteps [n]] > graphs/data/omp-simulation.dat

# example
./omp-earthquake 100000 256 > graphs/data/omp-simulation.dat
```

Plot simulation results:

```bash
cd graphs
./plot-simulation.py
feh omp-earthquake.png
```

### Performance evaluation

#### Speedup

Formula: Tserial / Tparallel

Run speedup calculation (takes some time):

```bash
cd src
./omp-speedup.sh 1>graphics/data/omp-speedup.dat 2>graphics/data/omp-strong.dat
```

1) computes the simulation using `#cores` from 1 to `n_cores` * 2 (1, 2,4, 8 , 16...) and for differet matrix sizes (eg. `256`, `512` and `1024`)
2) takes timing for each computation
3) calculates the speedup (formula `Tserial / Tparallel`)
4) calculates the strong efficiency (see [Strong efficiency](#strong-efficiency))

**NOTE**: it ignores the non-parallelizable portion of the simulation (matrix initialization) beacuse it takes negligible timings.

Plot speedup graphics:

```bash
cd graphics
./plot-speedup.py
feh omp-speedup.png
```

#### Strong efficiency

Formula: Speedup / n\_threads

Strong efficiency data has been calculated in the speedup script.

```bash
cd graphics
./plot-strong.py
feh omp-strong.png
```

#### Weak efficiency

Formula: T1 / Tp

Run tests:

```bash
./omp-weak-scaling.sh > graphics/data/omp-weak.dat
./plot-weak.py
feh omp-weak.png
```

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
./cuda-earthquake [nsteps [n]] > graphs/data/cuda-simulation.dat

# example
./cuda-earthquake 100000 256 > graphs/data/cuda-simulation.dat
```

----------

Plot simulation results:

```bash
cd graphs
./plot-simulation.py
feh cuda-earthquake.png
#./plot-simulation.sh omp-simulation.dat omp-earthquake.png
```

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
