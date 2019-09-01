#!/bin/bash

# Outputs the speedup values (Tserial / Tparallel) for each computation

psize=( 256 512 1024 ) # matrix side length
steps=100000 # steps of computation
# number of threads (from 1 to `nproc` * 2 stepping of power of 2)
# NB: `nproc` output must be a power of 2 (TODO FIX while nproc-=1 != potenza
# del 2 valida)
# single thread MUST be first execution!
nthreads=()
pow=0
n=2
for ((i=0; pow != $((`nproc` * 2)); i++)); do
    pow=$(( n ** i ))
    nthreads+=(${res})
done
#nthreads=( 1 8 4 ) # MANUAL (DEBUG)

# printing first row, ex:
#THREAD  256     512    1024
echo -e -n "THREAD"
echo -e -n "THREAD" >&2
for i in "${psize[@]}"; do
    echo -e -n "\t${i}"
    echo -e -n "\t${i}" >&2
done

echo
echo >&2

strong_scaling=0

# computing speedup values
t_serial=()
t_parallel=1
for j in "${nthreads[@]}"; do
    n=0
    echo -e -n "${j}"
    echo -e -n "${j}" >&2
    for i in "${psize[@]}"; do
        #out_file=out${i}_${j}
        out_file=/dev/null
        res_file=res${i}_${j}
        # the very simulation run
        OMP_NUM_THREADS=${j} ./omp-earthquake ${steps} ${i} > ${out_file} 2>${res_file}
        # storing serial computation results
        if [[ ${j} == 1 ]]; then
            t_serial+=(`grep 'parallel' ${res_file} | cut -d ':' -f2 | cut -d ' ' -f2`)
            #echo -e "\nt_serial=${t_serial}" # DEBUG PRINT
            # with one thread Tparallel = Tserial
            t_parallel=${t_serial[n]}
            #echo -e "\nt_parallel=${t_parallel}" # DEBUG PRINT
        else
            t_parallel=`grep 'parallel' ${res_file} | cut -d ':' -f2 | cut -d ' ' -f2`
            #echo -e "\nt_parallel=${t_parallel}" # DEBUG PRINT
        fi
        #echo -e "\nbefore bc" # DEBUG PRINT
        # speedup = Tserial / Tparallel (floating point precision: 4 digits)
        speedup=`echo "scale=4; ${t_serial[n]} / ${t_parallel}" | bc -l -q`
        echo -e -n "\t${speedup}"
        #echo -e "\nspeedup=${speedup}" # DEBUG PRINT
        strong_scaling=$(printf '%.4f\n' "$(echo "scale=4; ${speedup} / ${j}" | bc -l -q)")
        echo -e -n "\t${strong_scaling}" >&2
        (( n+=1 ))
        #echo -e "\tn=${n}" # DEBUG PRINT
        rm ${out_file} ${res_file} 2>/dev/null
    done
    echo
    echo >&2
done
