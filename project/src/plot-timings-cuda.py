#!/usr/bin/env python3

# Fabrizio Margotta 789072

import numpy as np
import matplotlib.pyplot as plt

cuda_in_file = "./data/cuda-timings-py.csv"
out_file = "./graphs/cuda-timings.png"

# Read in csv. Use names=True to also store column headers
per_data = np.genfromtxt(cuda_in_file, delimiter=',', names=True)

# Loop over columns. Here I assume you have the x-data in the first column, so
# skip that one
for name in per_data.dtype.names[1:]:
    # Set the line's label to the column name
    plt.plot(per_data['LATO'], per_data[name], label=name)


# Add a legend
plt.legend(loc=0, title='Versione')

plt.xlabel('Lato dominio')
plt.ylabel('Secondi')
plt.title('Tempistiche CUDA')
plt.grid()

# axis ticks
plt.xticks(per_data['LATO'])

# show origin
plt.xlim(left=0)
plt.ylim(bottom=0)

# plt.show()

# save to file
plt.savefig(out_file)
