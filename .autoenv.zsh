function sendomp() {
    scp {Makefile,omp-earthquake.c,hpc.h} uniomp:/home/local/STUDENTI/fabrizio.margotta/
}

function sendcuda() {
    scp {Makefile,cuda-earthquake.cu,hpc.h} unicuda:/home/local/STUDENTI/fabrizio.margotta/
}

function recvres() {
    echo "TODO"
}
