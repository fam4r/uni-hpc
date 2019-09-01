#!/bin/bash

# Credits: Prof. Moreno Marzolla

# Questo script exegue il programma omp-earthquake sfruttando OpenMP con
# un numero di core da 1 a 8 (estremi inclusi). Il test con p
# processori viene effettuato su un input che ha dimensione (p * N0 *
# N0 * N0)^(1/3), dove N0 e' la dimensione dell'input nel caso base.
# In altre parole, il test con p processori viene effettuato su un
# input che richiede (in teoria) p volte il tempo richiesto dal caso
# base. Pertanto, questo script puo' essere utilizzato per stimare la
# weak scaling efficiency.

N0=256 # base problem size
steps=100000 # steps of computation
CORES=`nproc` # number of cores

timings=()

nthreads=()
pow=0
n=2
for ((i=0; pow != $((`nproc` * 2)); i++)); do
    pow=$(( n ** i ))
    nthreads+=(${pow})
done

echo -e "p\tWEAK"

for p in `seq ${nthreads[-1]}`; do
    echo -e -n "${p}"
    PROB_SIZE=`echo "e(l(${N0} * ${N0} * ${N0} * ${p})/3)" | bc -l -q`
    out_file=/dev/null
    res_file=res${p}
    OMP_NUM_THREADS=${p} ./omp-earthquake ${steps} ${PROB_SIZE} 1>${out_file} 2>${res_file}
    if [[ ${p} == 1 ]]; then
        t_serial=`grep 'parallel' ${res_file} | cut -d ':' -f2 | cut -d ' ' -f2`
    fi
    t_parallel=`grep 'parallel' ${res_file} | cut -d ':' -f2 | cut -d ' ' -f2`
    weak_scaling=$(printf '%.4f\n' "$(echo "scale=4; ${t_serial} / ${t_parallel}" | bc -l -q)")
    echo -e -n "\t${weak_scaling}"
    echo
    rm ${out_file} ${res_file} 2>/dev/null
done
