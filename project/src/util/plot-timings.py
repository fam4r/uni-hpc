#!/usr/bin/env python3

# Fabrizio Margotta 789072

import numpy as np
import matplotlib.pyplot as plt

in_file = "./data/omp-timings-py.csv"
out_file = "./graphs/omp-timings.png"

# Read in csv. Use names=True to also store column headers
per_data = np.genfromtxt(in_file, delimiter=',', names=True)

# Loop over columns. Here I assume you have the x-data in the first column, so
# skip that one
for name in per_data.dtype.names[1:]:
    # Set the line's label to the column name
    plt.plot(per_data['THREAD'], per_data[name], label=name)

# Add a legend
plt.legend(loc=0, title='Lato dominio')

plt.xlabel('# Threads')
plt.ylabel('Secondi')
plt.title('Tempistiche OpenMP')
plt.grid()

# show origin
plt.xlim(left=0)
plt.ylim(bottom=0)

# axis ticks
plt.xticks(per_data['THREAD'])

# plt.show()

# save to file
plt.savefig(out_file)
