function sendomp() {
    scp {Makefile,earthquake.c,omp-earthquake.c,hpc.h} uniomp:/home/local/STUDENTI/fabrizio.margotta/
}

function sendcuda() {
    scp {Makefile,earthquake.c,cuda-earthquake.cu,hpc.h} unicuda:/home/local/STUDENTI/fabrizio.margotta/
}

function recvomp() {
    scp uniomp:/home/local/STUDENTI/fabrizio.margotta/out .
}

function recvcuda() {
    scp unicuda:/home/local/STUDENTI/fabrizio.margotta/out .
}
