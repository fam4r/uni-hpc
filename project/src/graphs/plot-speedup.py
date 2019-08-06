#!/usr/bin/env python3

import matplotlib.pyplot as plt
import numpy as np

# Read in csv. Use names=True to also store column headers
per_data=np.genfromtxt('data/omp-speedup.dat',delimiter='\t',names=True)

# Loop over columns. Here I assume you have the x-data in the first column, so skip that one
for name in per_data.dtype.names[1:]:
    # Set the line's label to the column name
    plt.plot(per_data['THREAD'],per_data[name],label=name)

# Add a legend
plt.legend(loc=0, title='Lato dominio')

plt.xlabel('# Threads')
plt.ylabel('Speedup')
plt.title('Speedup OpenMP')
plt.grid()

# show origin
plt.xlim(left=0)
plt.ylim(bottom=0)

plt.show() # DEBUG

## save to file
##plt.savefig('omp-speedup.png')
