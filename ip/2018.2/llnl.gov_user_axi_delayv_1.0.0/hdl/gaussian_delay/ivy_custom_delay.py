#from matplotlib import pyplot as mp
import numpy as np
import random
import os
import sys

## Width of address bus input to BRAM table. This MUST match the FPGA's BRAM address width.
awidth = 10

#------------------------------------------------------------------
# calculate custom based on number of entries in Delay Table (GDT)
# Note: This number if fixed by the BRAM size.
#------------------------------------------------------------------
# Number of entries in GDT
n = 2**awidth

## Width of output, in bits. This MUST match the FPGA's BRAM data width.
dwidth = 24

csv_filename   = str(sys.argv[1]) + ".csv"
txt_filename   = sys.argv[1] + "_dt_data_custom.txt"   ## text file

# path to lime-apps
txt_filepath   = "../../../../../shared/"  ## use for local test code

txt_file_path_name = txt_filepath + txt_filename
print("txt_file_path_name = " + txt_file_path_name)

file_txt = open(txt_file_path_name , "w")
file_csv = open(csv_filename , "r")

with open(csv_filename) as file_name:
    array = np.loadtxt(file_name, delimiter=",",skiprows=1)

array = np.round( np.array(array, dtype=np.float32) * (20 * 300) / (187.5 * 5.33) )

array = np.array(array, dtype=np.int)
array_resampled = random.choices(list(array), k=n)

for x in range (0, n):
   if (x < n-1):
       file_txt.write("    0x" + str('%x' % ((array_resampled[x]))).zfill(int(dwidth/4)) + ",\n")
   else:
       file_txt.write("    0x" + str('%x' % ((array_resampled[x]))).zfill(int(dwidth/4)) + "\n")


file_csv.close()
file_txt.close()