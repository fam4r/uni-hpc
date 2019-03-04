function sendomp() {
    scp {Makefile,earthquake.c,omp-earthquake.c,hpc.h} uniomp:/home/local/STUDENTI/fabrizio.margotta/
}

function sendcuda() {
    scp {Makefile,earthquake.c,cuda-earthquake.cu,hpc.h} unicuda:/home/local/STUDENTI/fabrizio.margotta/
}

function recvres() {
    echo "TODO"
}
