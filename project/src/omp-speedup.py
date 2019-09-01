#!/usr/bin/env python3

import math
import os
import csv
import logging
logging.basicConfig(level=logging.INFO)

exe_name = "omp-earthquake"
steps = 100000
#p_size = [256, 512, 1024]
p_size = [256]

# [1, 2, 4, 8, 16, 32, 64] threads used
#n_threads = list(2**x for x in range(0,6))
n_threads = [1, 8]

# run the simulation N times and take the average execution time
n_run = 1

compute_weak = True
weak_psize = 256

# csv info
speedup_filename = "graphs/data/omp-simulation-py.dat"
strong_filename = "graphs/data/omp-strong-py.dat"

weak_scaling = dict()

def compute_weak_scaling():
    for i in range(1, n_threads[len(n_threads) - 1] + 1):
        avg_exe_time = 0
        for k in range(1, n_run + 1):
            out_file = "/dev/null"
            res_file = "res_weak{}_{}".format(i, k)
            p_size_weak = round(math.pow(math.log((weak_psize ** 3) * i), 1/3), 4)
            logging.info("run #{}: L{}, {} thread".format(k, p_size_weak, i))
            res_file = "res_weak{}_{}".format(i, k)
            os.system("OMP_NUM_THREADS={} ./{} {} {} > {} 2>{}"
                .format(i, exe_name, steps, p_size_weak, out_file, res_file))
            with open(res_file) as f:
                for l in f:
                    if "parallel" in l:
                        exe_time = float(l.split(':')[1].split(' ')[1])
                        logging.info("exe_time #{} = {}".format(k, exe_time))
                        avg_exe_time += exe_time
                        logging.info("avg_exe_time #{} = {}".format(k, avg_exe_time))
        if i == 1:
            t_serial = avg_exe_time
            logging.info("t_serial = {}".format(t_serial))
        weak_scaling[i] = round(float(t_serial / avg_exe_time),4)
        logging.info("weak_scaling = {}".format(weak_scaling))

compute_weak_scaling()

t_serial = dict()
speedup = dict()
strong_scaling = dict()
for i in n_threads: # for each number of threads
    speedup[i] = dict()
    strong_scaling[i] = dict()

# run speedup / strong
for i in n_threads: # for each number of threads
    for j in p_size: # for each problem size
        avg_exe_time = 0
        for k in range(1, n_run + 1):
            logging.info("run #{}: L{}, {} thread".format(k, j, i))
            out_file = "/dev/null"
            res_file = "res{}_{}_{}".format(j, i, k)
            os.system("OMP_NUM_THREADS={} ./{} {} {} > {} 2>{}"
                .format(i, exe_name, steps, j, out_file, res_file))
            with open(res_file) as f:
                for l in f:
                    if "parallel" in l:
                        exe_time = float(l.split(':')[1].split(' ')[1])
                        logging.info("exe_time #{} = {}".format(k, exe_time))
                        avg_exe_time += exe_time
                        logging.info("avg_exe_time #{} = {}".format(k, avg_exe_time))
        avg_exe_time /= n_run
        logging.info("avg_exe_time = {}".format(avg_exe_time))
        if i == 1:
            t_serial[j] = avg_exe_time
            logging.info(t_serial)
        speedup[i][j] = round(float(t_serial[j] / avg_exe_time), 4)
        logging.info("speedup = {}".format(speedup))
        strong_scaling[i][j] = round(float(speedup[i][j] / i), 4)
        logging.info("strong_scaling = {}".format(strong_scaling))

with open(speedup_filename, mode='w') as speedup_file, open(strong_filename,
        mode='w') as strong_file:
    # speedup
    speedup_fieldnames = ['THREAD']
    speedup_fieldnames += p_size
    speedup_writer = csv.DictWriter(speedup_file, speedup_fieldnames)
    speedup_writer.writeheader()

    # strong efficiency
    strong_fieldnames = ['THREAD']
    strong_fieldnames += p_size
    strong_writer = csv.DictWriter(strong_file, strong_fieldnames)
    strong_writer.writeheader()

    for i in n_threads:
        row = speedup[i]
        row["THREAD"] = i
        speedup_writer.writerow(row)
        row = strong_scaling[i]
        row["THREAD"] = i
        strong_writer.writerow(row)
