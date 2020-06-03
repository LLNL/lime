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
h_filename     = "../../../../../test/shared/gdt.h" ## c header file
mif_filename   = "bram_del_table.mif"  ## mif file format, not used
bin_filename   = "bram_del_table.init" ## see UG901, p143 - this is the Vivado mem format, not the updatemem format
coe_filename   = "bram_del_table.coe"  ## coe file format
mem_filename   = "../bram_del_table.mem"  ## mem file format

## Width of address bus input to BRAM table
awidth = 10

## Width of output, in bits
dwidth = 24

## Maximum time delay, in clock cycles
delay_clocks = 5000 ## max =(2**dwidth)-1

## address offset for "B" channel GDT
bchan_offset = 0x00010000

## address offset for "R" channel GDT
rchan_offset = 0x00020000

## Create check plot (use 1 or 0)
CHECK_PLOT = 1

#------------------------------------------------------------------
# open files for writing
#------------------------------------------------------------------
f        = open(outputfilename, "w")
file_h   = open(h_filename  , "w")
file_mif = open(mif_filename, "w")
file_bin = open(bin_filename, "w")
file_coe = open(coe_filename, "w")
file_mem = open(mem_filename, "w")

#------------------------------------------------------------------
# calculate gaussian based on number of entries in Gaussian Delay Table (GDT)
# Note: This number if fixed by the BRAM size.
#------------------------------------------------------------------
# Number of entries in GDT
n = 2**awidth

## mean
mu = 2**(awidth-1)

## standard deviation
sig = mu/3 

## define gaussian function based on GDT
def gaussian(x, mu, sig):
    return np.exp(-np.power(x - mu, 2.) / (2 * np.power(sig, 2.)))

#------------------------------------------------------------------
# Check plot for GDT
#------------------------------------------------------------------

gdt_base = [None] * (n)

for i in range (0, n):
    gdt_base[i] = gaussian(i, mu, sig)
    
## np.linspace: return evenly space numbers over a specific interval
x_values = np.linspace (0, n, n)

print("awidth = " + str(awidth))
print("n      = " + str(n))
print("dwidth = " + str(dwidth))
print("mu     = " + str(mu))
print("sig    = " + str(sig))

## plot
print("\n")
print("Plotting the test curve...")
print("\n")
plt.title('Test Plot - Normal Gaussian, prior to adjustments')
plt.plot(x_values, gaussian(x_values, mu, sig))
plt.show()

#******************************************************************
# Generate GDT Contents for delay_clocks < n
#******************************************************************

mu_new        = delay_clocks/2
sig_new       = mu_new/3
gauss_table_fp= [0] *  n 
gauss_table   = [0] *  n 
x_idx         = [0] *  n

gauss_table_fp = np.random.normal(mu_new, sig_new, n)

#------------------------------------------------------------------
# Scale to delay_clocks, and create table, write to file
# The file will be csv with index, integer value, and hex value
#------------------------------------------------------------------
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

#----- Generate "header" for .mem file
file_mem.write("@0000\n")

#----- Generate "header" for .h file
file_h.write("#define B_OFFSET 0x" + str('%x' % (int(bchan_offset))).zfill(8) + "\n")
file_h.write("#define R_OFFSET 0x" + str('%x' % (int(rchan_offset))).zfill(8) + "\n")
file_h.write("\n")
#file_h.write("extern void config_gdt(int, int);\n")
#file_h.write("\n")
file_h.write("int gdt_data[" + str(n) + "] = {\n")

#------------------------------------------------------------------

for x in range (0, n):
   if (gauss_table_fp[x] < 0):
       gauss_table_fp[x] = -gauss_table_fp[x]
       
   gauss_table[x] = int(gauss_table_fp[x])   
   x_idx[x] = x

   ##----- write to the check file
   f.write(str(x_idx[x]) + ", " + str(gauss_table[x]) + ", " + hex((gauss_table[x])))
   f.write("\n")
   
   ##----- write to the mif file
   file_mif.write(str('%x' % (x)).zfill(int(awidth/4)) + " : " + str('%x' % ((gauss_table[x]))).zfill(int(dwidth/4)) + ";")
   file_mif.write("\n")
   
   ##----- write to the binary file
   h = ( bin(int(str(hex((gauss_table[x]))), 16))[2:] ).zfill(dwidth)
   file_bin.write(str(h))
   file_bin.write("\n")
   
   ##----- write to coe file
   file_coe.write("\n")
   file_coe.write(str(h))
   if (x < n-1):
       file_coe.write(",")
   else:
       file_coe.write(";")

   ## ----- write to h_file
   if (x < n-1):
       file_h.write("    0x" + str('%x' % ((gauss_table[x]))).zfill(int(dwidth/4)) + ",\n")
   else:
       file_h.write("    0x" + str('%x' % ((gauss_table[x]))).zfill(int(dwidth/4)) + "};\n")
       
   ## ----- write to mem file
   file_mem.write(str('%x' % ((gauss_table[x]))).zfill(int(dwidth/4)) + "\n")  
   
#------------------------------------------------------------------

f.close()
file_bin.close()
file_mem.close()
file_h.close()

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