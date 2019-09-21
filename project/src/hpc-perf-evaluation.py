#!/usr/bin/env python3

import os
import csv
import logging
logging.basicConfig(level=logging.INFO)

# executable variables
exe_name = "omp-earthquake"
steps = 100000
matrix_sides = [256, 512, 1024]
# matrix_sides = [256]

# [1, 2, 4, 8, 16, 32, 64] threads used
threads = list(2**x for x in range(0, 6))
# threads = [1, 8]

# run the simulation N times and take the average execution time
total_run = 5

compute_weak = True
weak_psize = 256

# csv info
timings_filename = "./data/omp-timings-py.csv"
speedup_filename = "./data/omp-speedup-py.csv"
strong_filename = "./data/omp-strong-py.csv"
weak_filename = "./data/omp-weak-py.csv"


def compute_weak_scaling():
    logging.info("###################### WEAK SCALING #######################")
    for thread in range(1, 17):
        avg_exe_time = 0
        for k in range(1, total_run + 1):
            out_file = "/dev/null"
            res_file = "./data/res_weak{}_{}".format(thread, k)
            # e(l($N0 * $N0 * $N0 * $p)/3)
            p_size_weak = round(weak_psize * (thread**(1. / 3.)), 4)
            logging.info("run #{}: L{}, {} thread".format(
                k, p_size_weak, thread))
            os.system("OMP_NUM_THREADS={} ./{} {} {} > {} 2>{}".format(
                thread, exe_name, steps, p_size_weak, out_file, res_file))
            with open(res_file) as f:
                for line in f:
                    if "parallel" in line:
                        exe_time = float(line.split(':')[1].split(' ')[1])
                        logging.info("exe_time #{} = {}".format(k, exe_time))
                        avg_exe_time += exe_time
                        logging.info("avg_exe_time #{} = {}".format(
                            k, avg_exe_time))
        avg_exe_time /= total_run
        logging.info("avg_exe_time = {}".format(avg_exe_time))
        if thread == 1:
            t_serial = avg_exe_time
            logging.info("t_serial = {}".format(t_serial))
        weak_scaling[thread] = round(float(t_serial / avg_exe_time), 4)
        logging.info("weak_scaling = {}".format(weak_scaling))


weak_scaling = dict()
compute_weak_scaling()

avg_exe_time = dict()
t_serial = dict()
speedup = dict()
strong_scaling = dict()
for thread in threads:  # for each number of threads
    avg_exe_time[thread] = dict()
    speedup[thread] = dict()
    strong_scaling[thread] = dict()


def get_execution_time(filename, regex):
    exe_time = 0
    with open(filename) as f:
        for line in f:
            if regex in line:
                exe_time = float(line.split(':')[1].split(' ')[1])
                logging.info("exe_time = {}".format(exe_time))
    return exe_time


# run speedup / strong
logging.info("################## SPEEDUP & STRONG SCALING ###################")
for thread in threads:
    for side in matrix_sides:
        avg_exe_time[thread][side] = 0
        for n_run in range(1, total_run + 1):
            logging.info("run #{}: L{}, {} thread".format(n_run, side, thread))

            # run variables
            out_file = "/dev/null"
            res_file = "./data/res{}_{}_{}".format(side, thread, n_run)
            cmd = "OMP_NUM_THREADS={} ./{} {} {} > {} 2>{}".format(
                thread, exe_name, steps, side, out_file, res_file)

            # execute run
            os.system(cmd)

            # get time
            exe_time = get_execution_time(res_file, "parallel")
            logging.info("exe_time #{} = {}".format(n_run, exe_time))
            avg_exe_time[thread][side] += exe_time
            logging.info("sum_avg_exe_time #{} = {}".format(
                n_run, avg_exe_time[thread][side]))

        avg_exe_time[thread][side] = round(
            avg_exe_time[thread][side] / total_run, 4)
        logging.info("avg_exe_time = {}".format(avg_exe_time))

        if thread == 1:
            t_serial[side] = avg_exe_time[thread][side]

        # speedup
        speedup[thread][side] = round(
            float(t_serial[side] / avg_exe_time[thread][side]), 4)
        logging.info("speedup = {}".format(speedup))

        # strong scaling
        strong_scaling[thread][side] = round(
            float(speedup[thread][side] / thread), 4)
        logging.info("strong_scaling = {}".format(strong_scaling))

logging.info("####################### SAVING TO FILE ########################")


def save(column_headers, filename, data):
    with open(filename, mode='w') as f:
        headers = ["THREAD"]
        headers += column_headers
        writer = csv.DictWriter(f, headers)
        writer.writeheader()
        for thread in threads:
            row = data[thread]
            row["THREAD"] = thread
            writer.writerow(row)


save(matrix_sides, timings_filename, avg_exe_time)
save(matrix_sides, speedup_filename, speedup)
save(matrix_sides, strong_filename, strong_scaling)
# save(["WEAK"], weak_filename, weak_scaling)

# with open(timings_filename, mode='w') as timings_file:
#     timings_fieldnames = ['THREAD']
#     timings_fieldnames += matrix_sides
#     timings_writer = csv.DictWriter(timings_file, timings_fieldnames)
#     timings_writer.writeheader()
#     for thread in threads:
#         row = avg_exe_time[thread]
#         row["THREAD"] = thread
#         timings_writer.writerow(row)
#
# with open(speedup_filename, mode='w') as speedup_file:
#     speedup_fieldnames = ['THREAD']
#     speedup_fieldnames += matrix_sides
#     speedup_writer = csv.DictWriter(speedup_file, speedup_fieldnames)
#     speedup_writer.writeheader()
#     for thread in threads:
#         row = speedup[thread]
#         row["THREAD"] = thread
#         speedup_writer.writerow(row)
#
# with open(strong_filename, mode='w') as strong_file:
#     strong_fieldnames = ['THREAD']
#     strong_fieldnames += matrix_sides
#     strong_writer = csv.DictWriter(strong_file, strong_fieldnames)
#     strong_writer.writeheader()
#     for thread in threads:
#         row = strong_scaling[thread]
#         row["THREAD"] = thread
#         strong_writer.writerow(row)

with open(weak_filename, mode='w') as weak_file:
    weak_fieldnames = ['p', 'WEAK']
    weak_writer = csv.DictWriter(weak_file, weak_fieldnames)
    weak_writer.writeheader()
    row = dict()
    for thread in range(1, threads[len(threads) - 1] + 1):
        row["p"] = thread
        row["WEAK"] = weak_scaling[thread]
        weak_writer.writerow(row)
