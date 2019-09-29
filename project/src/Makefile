# Fabrizio Margotta 789072

## Makefile per il progetto di High Performance Computing
## 2018/2019, corso di laurea in Ingegneria e Scienze Informatiche,
## Universita' di Bologna sede di Cesena.

## Ultima modifica: 2019-02-26, Fabrizio Margotta <fabrizio.margotta(at)studio.unibo.it>

## Questo Makefile compila i file "omp-*.c" usando il flag -fopenmp, i
## file "cuda-*.cu" con il compilatore nvcc, e i file "mpi-*.c" con
## mpicc.
##
## Questo makefile fornisce i seguenti target:
##
## make         compila tutti i sorgenti disponibili
## make clean   cancella i file temporanei e gli eseguibili
## make openmp  compila la versione OpenMP
## make mpi     compila la versione MPI
## make cuda    compila la versione CUDA
## make plot    produce il grafico di esempio usando la versione seriale

EXE_OMP:=$(basename $(wildcard omp-*.c))
EXE_MPI:=$(basename $(wildcard mpi-*.c))
EXE_CUDA:=$(basename $(wildcard cuda-*.cu))
EXE_SERIAL:=earthquake
EXE:=$(EXE_OMP) $(EXE_MPI) $(EXE_SERIAL) $(EXE_CUDA)
CFLAGS+=-std=c99 -Wall -Wpedantic -O2 -D_XOPEN_SOURCE=600
NVCC:=nvcc
NVCFLAGS+=-Wno-deprecated-gpu-targets #-DPRINT_DEBUG

.PHONY: clean plot

ALL: $(EXE)

% : %.cu
	$(NVCC) $(NVCFLAGS) $< -o $@

$(EXE_OMP): CFLAGS+=-fopenmp
$(EXE_OMP): LDLIBS+=-lgomp
openmp: $(EXE_OMP)

$(EXE_MPI): CC=mpicc
mpi: $(EXE_MPI)

cuda: $(EXE_CUDA)

plot: $(EXE_SERIAL)
	./$(EXE_SERIAL) 100000 256 > out
	gnuplot plot.gp

clean:
	\rm -f $(EXE) *.o *~ *.png out
