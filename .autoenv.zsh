function sendomp() {
    scp {Makefile,earthquake.c,omp-earthquake.c,hpc.h} uniomp:/home/local/STUDENTI/fabrizio.margotta/
}

function computeomp() {
    ssh uniomp "cd ~; make clean; make; ./omp-earthquake 100000 256 > out"
}

function recvomp() {
    scp uniomp:/home/local/STUDENTI/fabrizio.margotta/out .
}

function runomp() {
    sendomp
    computeomp
    recvomp
}

function sendcuda() {
    scp {Makefile,earthquake.c,cuda-earthquake.cu,hpc.h} unicuda:/home/local/STUDENTI/fabrizio.margotta/
}

function recvcuda() {
    scp unicuda:/home/local/STUDENTI/fabrizio.margotta/out .
}
