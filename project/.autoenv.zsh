function sendomp() {
    scp {Makefile,earthquake.c,omp-earthquake.c,hpc.h,hpc-perf-evaluation.py} uniomp:/home/local/STUDENTI/fabrizio.margotta/
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
    if [[ $? == 0 ]]; then
        recvomp
    else
        echo "execution failed, not sending results..."
    fi
}

function sendcuda() {
    scp {Makefile,earthquake.c,cuda-earthquake.cu,hpc.h,hpc-perf-evaluation-cuda.py} unicuda:/home/local/STUDENTI/fabrizio.margotta/
}

function computecuda() {
    ssh unicuda "cd ~;\
        make clean;\
        make;\
        ./cuda-earthquake 100000 256 > out"
}

function recvcuda() {
    scp unicuda:/home/local/STUDENTI/fabrizio.margotta/data/cuda-timings-py.csv .
}

function runcuda() {
    sendcuda
    computecuda
    if [[ $? == 0 ]]; then
        recvcuda
    else
        echo "execution failed, not sending results..."
    fi
}
