#!/usr/bin/env python3

# Fabrizio Margotta 789072

import numpy as np
import matplotlib.pyplot as plt
import csv

in_file = "./data/omp-simulation.dat"
out_file = "./graphs/omp-earthquake.png"

x = []
y1 = []
y2 = []

i = 0

fig, (ax1, ax2) = plt.subplots(2, sharex=True, gridspec_kw={'hspace': 0.4})

with open(in_file, 'r') as csvfile:
    plots = csv.reader(csvfile, delimiter=' ')
    for row in plots:
        x.append(i)
        y1.append(int(row[0]))
        y2.append(float(row[1]))
        i += 1

# 1° sottodiagramma
ax1.set_title('Energia media')
ax1.plot(x, y2)

# 2° sottodiagramma
ax2.set_title('N. celle con energia > EMAX')
ax2.scatter(x, y1, s=8)

plt.xlabel('Timestep')

# show origin
ax1.set_ylim(bottom=0)
ax2.set_ylim(bottom=0)

# axis ticks
plt.xticks(np.arange(0, i + 1, step=(i / 10)))
start, end = ax1.get_ylim()
ax1.yaxis.set_ticks(np.arange(start, end + 1, step=0.5))
start, end = ax2.get_ylim()
ax2.yaxis.set_ticks(np.arange(start, end + 5, step=5))

# plt.show() # DEBUG

# save to file
plt.savefig(out_file)
