#------------------------------------------------------------------
# The goal of this code is to create files that can be used
# to initialize a Xilinx BRAM that is being used as a look-up table. The address to the 
# lookup table BRAM will be randomized, so that the value being read out will follow the
# gaussian distribution that is programmed.
#
# The programmed variables are filenames, address width, data width, and the maximum
# value of the gaussian output (which should not exceed (2**dwidth)-1).
#
# Several files are created:
#    outputfilename = check file containint the index (address), value (float), and value (hex)
#    h_filename     = header file for c code. This is loaded into the BRAM when a test (mem, strm, randa, etc) is run.
#                     It is copied to lime/test/shared and (if it exists) lime-apps/shared. No longer supported - see .txt file
#    txt_filename   = After mods to support gdt.c/h in cpp, the .h file is no longer generated; the table will be stored
#                     in a .txt file
#    mif_filename   = .mif file format containing the address and data, both in hex
#    bin_filename   = binary file for Vivado initialization, containing value in binary
#                     NOTE: this is NOT the same format as used in UpdateMem program.
#    coe_filename   = co-efficient file format
#    mem_filename   = .mem file format, to be loaded into the FPGA during the FPGA build process. These values are
#                     persistent, and are only changed via CPU commands (such as when you run mem, strm, randa, etc.)
#------------------------------------------------------------------

#from matplotlib import pyplot as mp
import matplotlib.pyplot as plt
import numpy as np
import os

#------------------------------------------------------------------
# initialization variables
#------------------------------------------------------------------

## output filename
outputfilename = "bram_del_table.csv"  ## check file
txt_filename   = "gdt_data_g636_mu_div128.txt"   ## text file
mif_filename   = "bram_del_table.mif"  ## mif file format, not used
bin_filename   = "bram_del_table.init" ## see UG901, p143 - this is the Vivado mem format, not the updatemem format
coe_filename   = "bram_del_table.coe"  ## coe file format
mem_filename   = "../bram_del_table.mem"  ## mem file format

# path to lime-apps
txt_filepath   = "../../../../../shared/"  ## use for local test code
#txt_filepath   = "../../../../../../lime-apps/shared/" ## use for lime-apps test code (change path as needed)

## Width of address bus input to BRAM table. This MUST match the FPGA's BRAM address width.
awidth = 10

## Width of output, in bits. This MUST match the FPGA's BRAM data width.
dwidth = 24

## Maximum time delay, in clock cycles
delay_clocks = 636*2 ## max =(2**dwidth)-1

## address offset for "B" channel GDT
bchan_offset = 0x00010000

## address offset for "R" channel GDT
rchan_offset = 0x00020000

## Create check plot (use 1 or 0)
CHECK_PLOT = 1

## Fill GDT with constant
FILL_WITH_CONSTANT = 0 ## When 1, the entire GDT is filed with GDT_CONSTANT
GDT_CONSTANT       = 0

#------------------------------------------------------------------
# open files for writing
#------------------------------------------------------------------
txt_file_path_name = txt_filepath + txt_filename
print("txt_file_path_name = " + txt_file_path_name)

f        = open(outputfilename, "w")
file_txt = open(txt_file_path_name , "w")
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
mu = delay_clocks/2    ##2**(awidth-1)

## standard deviation
sig = mu/128 ###mu/3  ### mu/3 = normal

## define gaussian function based on GDT
def gaussian(x, mu, sig):
    return np.exp(-np.power(x - mu, 2.) / (2 * np.power(sig, 2.)))

#------------------------------------------------------------------
# Check plot
#------------------------------------------------------------------

if (CHECK_PLOT == 1):
    gdt_base = [None] * (delay_clocks)
    
    for i in range (0, delay_clocks):
        gdt_base[i] = gaussian(i, mu, sig)
        
    ## np.linspace: return evenly space numbers over a specific interval
    x_values = np.linspace (0, delay_clocks, delay_clocks)
    
    print("awidth = " + str(awidth))
    print("n      = " + str(n))
    print("dwidth = " + str(dwidth))
    print("mu     = " + str(mu))
    print("sig    = " + str(sig))
    
    ## plot
    print("\n")
    print("Plotting the test curve...")
    print("\n")
    plt.title('Test Plot - Gaussian, prior to adjustments')
    plt.plot(x_values, gaussian(x_values, mu, sig))
    plt.show()

#******************************************************************
# Generate GDT Contents for delay_clocks < n
#******************************************************************

mu_new        = mu  ####  delay_clocks/2
sig_new       = sig ####mu_new/3
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
#file_h.write("#define B_OFFSET 0x" + str('%x' % (int(bchan_offset))).zfill(8) + "\n")
#file_h.write("#define R_OFFSET 0x" + str('%x' % (int(rchan_offset))).zfill(8) + "\n")
#file_h.write("\n")
#file_h.write("int gdt_data[" + str(n) + "] = {\n")

#------------------------------------------------------------------

for x in range (0, n):
   if (gauss_table_fp[x] < 0):
       gauss_table_fp[x] = -gauss_table_fp[x]
   
   if (FILL_WITH_CONSTANT == 1):
       gauss_table[x] = GDT_CONSTANT
   else:
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

   ## ----- write to txt_file
   if (x < n-1):
       file_txt.write("    0x" + str('%x' % ((gauss_table[x]))).zfill(int(dwidth/4)) + ",\n")
   else:
       file_txt.write("    0x" + str('%x' % ((gauss_table[x]))).zfill(int(dwidth/4)) + "\n")
       
   ## ----- write to mem file
   file_mem.write(str('%x' % ((gauss_table[x]))).zfill(int(dwidth/4)) + "\n")  
   
#------------------------------------------------------------------

f.close()
file_bin.close()
file_mem.close()
file_txt.close()

#----- Generate the footer for .mif file
file_mif.write("--")
file_mif.write("END;")
file_mif.close()

##----- plot the gaussian function
if (CHECK_PLOT == 1):
    plt.plot(x_idx, gauss_table)
    plt.title('Randomized Delays In BRAM (clock cycles)')
    plt.xlabel('BRAM Address')
    plt.ylabel('Delay (clock cycles)')
    plt.show()

##----- Messages
print("")
print("")
print("Gaussian Delay Table (GDT) file generation is complete.")
print("")
print("The .mem file, which will be used as the default GDT contents when the FPGA is built, ")
print("   is stored here: " + mem_filename)
print("")
print("The .txt file, which will be loaded into the GDT at runtime for mem, strm, and randa, ")
print("   is stored here: " + txt_file_path_name + txt_filename)
