#!/usr/bin/env python3

import matplotlib.pyplot as plt
import numpy as np

in_file = "./data/omp-weak-py.csv"
out_file = "./graphs/omp-weak.png"

# Read in csv. Use names=True to also store column headers
per_data = np.genfromtxt(in_file, delimiter=',', names=True)

# Loop over columns. Here I assume you have the x-data in the first column, so
# skip that one
for name in per_data.dtype.names[1:]:
    # Set the line's label to the column name
    plt.plot(per_data['p'], per_data[name], label=name)

plt.xlabel('# Threads')
plt.ylabel('Weak scaling')
plt.title('Weak scaling OpenMP')
plt.grid()

# show origin
plt.xlim(left=0)
plt.ylim(bottom=0)

# axis ticks
plt.xticks(per_data['p'])

plt.show()  # DEBUG

# save to file
# plt.savefig(out_file)
