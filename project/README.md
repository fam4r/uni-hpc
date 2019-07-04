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

## Run

### Requirements

Install OpenMP and CUDA in your system (ArchLinux `openmp` and `cuda`).

To plot install `gnuplot`.

To run the code please execute the following instructions:

```
make clean
make
./omp-earthquake 100000 256 > out # to run OpenMP implementation
./cuda-earthquake.cu 100000 256 > out # to run CUDA implementation
./plot.sh <filename>.png # dynamic image creation
# feh earthquake.png
# feh omp-earthquake.png
# feh cuda-earthquake.png
```
