#------------------------------------------------------------------
# The goal of this code is to create an initialization file (*.init) that can be used
# to initialize a Xilinx BRAM that is acting as a look-up table. The address to the 
# lookup table BRAM will be randomized, so that the value being read out will follow the
# gaussian distribution that is programmed.
#
# The programmed variables are filenames, address width, data width, and the maximum
# value of the gaussian output (which should not exceed (2**dwidth)-1).
#
# Three files are created:
#    outputfilename = check file containint the index (address), value (float), and value (hex)
#    mif_filename   = .mif file format containing the address and data, both in hex
#    bin_filename   = binary file for Vivado initialization, containing value in binary
#                     NOTE: this is NOT the same format as used in UpdateMem program.
#------------------------------------------------------------------

#from matplotlib import pyplot as mp
import matplotlib.pyplot as plt
import numpy as np

#------------------------------------------------------------------
# initialization variables
#------------------------------------------------------------------

## output filename
outputfilename = "bram_del_table.csv"  ## check file
mif_filename   = "bram_del_table.mif"  ## mif file format, not used
bin_filename   = "bram_del_table.init" ## see UG901, p143 - this is the Vivado mem format, not the updatemem format
coe_filename   = "bram_del_table.coe"  ## coe file format
mem_filename   = "../bram_del_table.mem"  ## mem file format

## Width of address bus input to BRAM table
awidth = 16

## Width of output, in bits
dwidth = 24

## Maximum time delay, in clock cycles
delay_clocks = 1024 #15 ##255 ##(2**dwidth)-1

## Create check plot (use 1 or 0)
CHECK_PLOT = 1

#------------------------------------------------------------------
# open files for writing
#------------------------------------------------------------------
f = open(outputfilename, "w")
file_mif = open(mif_filename, "w")
file_bin = open(bin_filename, "w")
file_coe = open(coe_filename, "w")
file_mem = open(mem_filename, "w")

#------------------------------------------------------------------
# calculate gaussian
#------------------------------------------------------------------
# Number of items in BRAM lookup table
n = 2**awidth

## mean
mu = 2**(awidth-1)

## standard deviation
sig = mu/3 

## define gaussian function
def gaussian(x, mu, sig):
    return np.exp(-np.power(x - mu, 2.) / (2 * np.power(sig, 2.)))

#------------------------------------------------------------------
# Check plot
#------------------------------------------------------------------

if (CHECK_PLOT == 1):
    ## np.linspace: return evenly space numbers over a specific interval
    x_values = np.linspace (0, n, n)
    
    print("awidth = " + str(awidth))
    print("n      = " + str(n))
    print("dwidth = " + str(dwidth))
    print("mu     = " + str(mu))
    print("sig    = " + str(sig))
    
    ## plot
    plt.plot(x_values, gaussian(x_values, mu, sig))
    plt.show()

#------------------------------------------------------------------
# Scale to delay_clocks, and create table, write to file
# The file will be csv with index, integer value, and hex value
#------------------------------------------------------------------
# need to initialize or arrays size due to assignment of [0]
gauss_table = [None] *  n 
x_idx       = [None] *  n

#----- Generate the "header" for .mif file
file_mif.write("DEPTH = " + str(n) + ";")
file_mif.write("\n")
file_mif.write("WIDTH = " + str(dwidth) + ";")
file_mif.write("\n")
file_mif.write("ADDRESS_RADIX = HEX;")
file_mif.write("\n")
file_mif.write("DATA_RADIX = HEX;")
file_mif.write("\n")
file_mif.write("CONTENT")
file_mif.write("\n")
file_mif.write("BEGIN")
file_mif.write("\n")

#----- Generate "header" for .coe file
file_coe.write("memory_initialization_radix=2;")
file_coe.write("\n")
file_coe.write("memory_initialization_vector=")

for x in range (0, n):
   gauss = round (gaussian(x, mu, sig) * delay_clocks)
   if (gauss == 2**n):
       gauss = (2**n) - 1
   gauss_table[x] = gauss
   x_idx[x] = x
   
   ##----- write to the check file
   f.write(str(x_idx[x]) + ", " + str(gauss_table[x]) + ", " + hex(int(gauss_table[x])))
   f.write("\n")
   
   ##----- write to the mif file
   file_mif.write(str('%x' % (x)).zfill(int(awidth/4)) + " : " + str('%x' % (int(gauss))).zfill(int(dwidth/4)) + ";")
#   file_mif.write(str('%x' % (x)) + " : " + str('%x' % (int(gauss))) + ";")
   file_mif.write("\n")
   
   ##----- write to the binary file
   h = ( bin(int(str(hex(int(gauss))), 16))[2:] ).zfill(dwidth)
   file_bin.write(str(h))
   file_bin.write("\n")
   
   ##----- write to coe file
   file_coe.write("\n")
   file_coe.write(str(h))
   if (x < n-1):
       file_coe.write(",")
   else:
       file_coe.write(";")
       
   ## ----- write to mem file
   file_mem.write(str('%x' % (int(gauss))).zfill(int(dwidth/4)))
   file_mem.write("\n")
   
      
f.close()
file_bin.close()
file_mem.close()

#----- Generate the footer for .mif file
file_mif.write("--")
file_mif.write("END;")
file_mif.close()

##----- plot the gaussian function
plt.plot(x_idx, gauss_table)
plt.title('Generated Gaussian Distribution')
plt.xlabel('BRAM Address')
plt.ylabel('Delay (clock cycles)')
plt.show()

