#!/usr/bin/env python3

# Fabrizio Margotta 789072

import os
import csv
import logging
logging.basicConfig(level=logging.INFO)

# executable variables
exe_folder = "../"
exe_name = exe_folder + "earthquake"
steps = 100000
matrix_sides = [256, 512, 1024]
# matrix_sides = [256]

# run the simulation N times and take the average execution time
total_run = 5

result_dir = "../data"
os.makedirs(result_dir, exist_ok=True)

# csv info
serial_timings_filename = result_dir + "/serial-timings-py.csv"
cuda_timings_filename = result_dir + "/cuda-timings-py.csv"

avg_exe_time = dict()
t_serial = dict()


def get_execution_time(filename, regex):
    exe_time = 0
    with open(filename) as f:
        for line in f:
            if regex in line:
                exe_time = float(line.split(':')[1].split(' ')[4])
                logging.info("exe_time = {}".format(exe_time))
    return exe_time


def save(column_headers, filename, data):
    with open(filename, mode='w') as f:
        headers = column_headers
        writer = csv.DictWriter(f, headers)
        writer.writeheader()
        row = data
        writer.writerow(row)


logging.info("################## SERIAL TIMINGS ###################")
for side in matrix_sides:
    avg_exe_time[side] = 0
    for n_run in range(1, total_run + 1):
        logging.info("run #{}: L{}".format(n_run, side))

        # run variables
        out_file = "/dev/null"
        res_file = result_dir + "/serial_res{}_{}".format(side, n_run)
        cmd = "./{} {} {} > {} 2>{}".format(exe_name, steps, side, out_file,
                                            res_file)
        logging.info(cmd)

        # execute run
        os.system(cmd)

        # get time
        exe_time = get_execution_time(res_file, "seconds")
        logging.info("exe_time #{} = {}".format(n_run, exe_time))
        avg_exe_time[side] += exe_time
        logging.info("sum_avg_exe_time #{} = {}".format(
            n_run, avg_exe_time[side]))

    avg_exe_time[side] = round(avg_exe_time[side] / total_run, 4)
    logging.info("avg_exe_time = {}".format(avg_exe_time))

logging.info("####################### SAVING TO FILE ########################")
save(matrix_sides, serial_timings_filename, avg_exe_time)

exe_name = exe_folder + "cuda-earthquake"
logging.info("################## CUDA TIMINGS ###################")
for side in matrix_sides:
    avg_exe_time[side] = 0
    for n_run in range(1, total_run + 1):
        logging.info("run #{}: L{}".format(n_run, side))

        # run variables
        out_file = "/dev/null"
        res_file = result_dir + "/cuda_res{}_{}".format(side, n_run)
        cmd = "./{} {} {} > {} 2>{}".format(exe_name, steps, side, out_file,
                                            res_file)
        logging.info(cmd)

        # execute run
        os.system(cmd)

        # get time
        exe_time = get_execution_time(res_file, "seconds")
        logging.info("exe_time #{} = {}".format(n_run, exe_time))
        avg_exe_time[side] += exe_time
        logging.info("sum_avg_exe_time #{} = {}".format(
            n_run, avg_exe_time[side]))

    avg_exe_time[side] = round(avg_exe_time[side] / total_run, 4)
    logging.info("avg_exe_time = {}".format(avg_exe_time))

logging.info("####################### SAVING TO FILE ########################")
save(matrix_sides, cuda_timings_filename, avg_exe_time)
