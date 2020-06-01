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
delay_clocks = 2000 ## max =(2**dwidth)-1

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


#------------------------------------------------------------------
# Variables for calculation of GDT contents
#------------------------------------------------------------------
total_area_ds = 0
amplitude_ds  = [0] * (delay_clocks + 1)
gdt_ds        = [0] * (n + 1)
mu_new        = delay_clocks/2
sig_new       = mu_new/3
total_area    = 0
amplitude     = [0] * (n + 1)

down_sample = [0] * n
x_ds        = [0] * n # contains downsampled gaussian

if (delay_clocks >= n):
    #******************************************************************
    # Generate GDT Contents for delay_clocks >= n
    #******************************************************************
    
    for event in range (0, delay_clocks):
        amplitude_ds[event] = gaussian(event, mu_new, sig_new)
    
    #------------------------------------------------------------------
    ## Calculate the indexes (x_ds) for the downsampled gaussian
    #------------------------------------------------------------------
    if delay_clocks >= n:
        x_ds = np.linspace (0, delay_clocks, n)
    
    #------------------------------------------------------------------
    ## Create the downsampled gaussian for delay_clocks >= n
    #------------------------------------------------------------------
    
    for event in range (0, n):
        temp = int(round(x_ds[event]))
        x_ds[event] = temp
        total_area_ds = (total_area_ds + amplitude_ds[temp])
    #    print ("amplitude_ds[" + str(temp) + "] = "  + str(amplitude_ds[temp]))
    #    print ("x_ds[" + str(event) + ") = " + str(x_ds[event]))
    
    print("Total Area Downsampled = " + str(total_area_ds))
    
    #------------------------------------------------------------------
    # Populate gdt_final_ds
    #------------------------------------------------------------------
    
    cnt_dly_clks = 0
    cnt_gdtds = 0
    cnt_xds   = 0
    
    while (cnt_dly_clks < delay_clocks + 1) and (cnt_xds < n):
    #    print("cnt_xds = " + str(cnt_xds))
    #    print("cnt_dly_clks = " + str(cnt_dly_clks))
        temp1 = int(round(x_ds[cnt_xds]))
        temp = amplitude_ds[temp1]
        cnt_xds = cnt_xds + 1
    #    print("temp1 = " + str(temp1))
    #    print("amplitude_ds = " + str(amplitude_ds[temp1]))
    
        # Calculate integer value of entry, if non-zero
        amp_temp = round(((temp) / (total_area_ds)) * n)
    #    print("amp_temp = " + str(amp_temp))
    
        if  amp_temp == 0:
            cnt_dly_clks = cnt_dly_clks + 1
            if cnt_dly_clks > delay_clocks:
               exit
        else:
    #        print("cnt_dly_clks = " + str(cnt_dly_clks))
            event_cnt = amp_temp
            while (event_cnt > 0):
                if cnt_gdtds >= n : 
                    event_cnt = event_cnt - 1
                    cnt_gdtds = cnt_gdtds + 1
                    exit
                else:
                    gdt_ds[cnt_gdtds] = x_ds[cnt_dly_clks]
    #                print("gdt_ds[" + str(cnt_gdtds) + "] = " + str(gdt_ds[cnt_gdtds]))
                    event_cnt = event_cnt - 1
                    cnt_gdtds = cnt_gdtds + 1
            cnt_dly_clks = cnt_dly_clks + 1
            if cnt_dly_clks > delay_clocks:
               exit

    gdt_final = gdt_ds       

else:
    #******************************************************************
    # Generate GDT Contents for delay_clocks < n
    #******************************************************************
    
    #------------------------------------------------------------------
    # Calculate how many events of each delay_clock value should be in the table
    # The table will hold n +1 values, where n is the maximum delay value.
    # The table holds n + 1 to accout for zero.
    #
    # amplitude is the "height" of each delay value in the gaussian
    #------------------------------------------------------------------
    
    for event in range (0, delay_clocks):
        amplitude[event] = gaussian(event, mu_new, sig_new)
        total_area       = (total_area + amplitude[event])
        
    print("The total area under the curve = " + str(total_area))
    print("\n")
    
    #------------------------------------------------------------------
    # Calculate weights for each delay; will be used to calculate the number of times
    # each delay will appear in gdt_final
    #------------------------------------------------------------------
    gdt_new     = [0] * (n + 1)  ## defines how many locations each delay_clocks value is stored in
    event_total_check = 0
    
    for event in range (0, delay_clocks+1):
        gdt_new[event] = round((amplitude[event] / total_area) * n)
        event_total_check = event_total_check + gdt_new[event]
        print("gdt_new[" + str(event) + "] = " + str(gdt_new[event]))
    
    print("\n")
    print("Check Total Events = " + str(event_total_check))
    print("\n")
    
    print("PlotTHEEEE gaussian...\n")
    print("\n")
    plt.title('The Number of actual delays vs The Delays')
    plt.plot(gdt_new)
    plt.show()
    
    #------------------------------------------------------------------
    # Calculate gdt_final[], which will be the 2**awdith values stored in the GDT
    # This section works when delay_clocks < n
    #------------------------------------------------------------------
    gdt_final      = [0] * (n + 1)
    count_gdtnew   = 0
    count_gdtfinal = 0
    event_cnt      = 0
    
    while count_gdtnew < n + 1:
        if  gdt_new[count_gdtnew] == 0:
    ##        print("count_gdtnew (zero) = " + str(count_gdtnew))
    ##        print("\n")
            count_gdtnew = count_gdtnew + 1
            if count_gdtnew > delay_clocks:
               exit
        else:
    ##        print("count_gdtnew = " + str(count_gdtnew))
            event_cnt = gdt_new[count_gdtnew]
            print("\n")
            while (event_cnt > 0):
                if count_gdtfinal >= n : 
                    event_cnt = event_cnt - 1
                    exit
                else:
                    gdt_final[count_gdtfinal] = count_gdtnew
                    print("gdt_final[" + str(count_gdtfinal) + "] = " + str(gdt_final[count_gdtfinal]))
                    event_cnt = event_cnt - 1
                    count_gdtfinal = count_gdtfinal + 1
            count_gdtnew = count_gdtnew + 1
            if count_gdtnew > delay_clocks:
               exit
               
    #------------------------------------------------------------------
    ## Cleanup - due to rounding errors, there may be GDT locations which aren't assigned values.
    ##    This will assign them to mu
    #------------------------------------------------------------------
    
    cu_count = 0
    mu_round = round(mu_new)
    mu_plus  = mu_round
    mu_minus = mu_round
    
    if (event_total_check < n):
        cu_count = int(event_total_check)
        
        while cu_count < n:
            gdt_final[cu_count] = mu_plus + 1
            mu_plus = mu_plus + 1
            if cu_count < (n - 1):
                gdt_final[cu_count + 1] = mu_minus - 1
                mu_minus = mu_minus - 1
                cu_count = cu_count + 2
            else:
                cu_count = cu_count + 1
    
    print("Ok, what does this one look like?\n")
    plt.title('Ok, what does this one look like?')
    print("\n")
    print("gdt_final...\n")
    plt.title('gdt_final')
    plt.plot(gdt_final)
    plt.show()
    
#------------------------------------------------------------------
# Scale to delay_clocks, and create table, write to file
# The file will be csv with index, integer value, and hex value
#------------------------------------------------------------------
# need to initialize array sizes due to assignment of [0]
gauss_table = [None] *  n 
x_idx       = [None] *  n

area_under_curve = 0

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
   gauss = round (gaussian(x, mu, sig) * delay_clocks)
   if (gauss == 2**n):
       gauss = (2**n) - 1
       
   gauss_table[x] = gdt_final[x]       
   x_idx[x] = x

#------------------------------------------------------------------

   ##----- write to the check file
   f.write(str(x_idx[x]) + ", " + str(gauss_table[x]) + ", " + hex(int(gauss_table[x])))
   f.write("\n")
   
   ##----- write to the mif file
   file_mif.write(str('%x' % (x)).zfill(int(awidth/4)) + " : " + str('%x' % (int(gauss_table[x]))).zfill(int(dwidth/4)) + ";")
   file_mif.write("\n")
   
   ##----- write to the binary file
   h = ( bin(int(str(hex(int(gauss_table[x]))), 16))[2:] ).zfill(dwidth)
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
       file_h.write("    0x" + str('%x' % (int(gauss_table[x]))).zfill(int(dwidth/4)) + ",\n")
   else:
       file_h.write("    0x" + str('%x' % (int(gauss_table[x]))).zfill(int(dwidth/4)) + "};\n")
       
   ## ----- write to mem file
   file_mem.write(str('%x' % (int(gauss_table[x]))).zfill(int(dwidth/4)) + "\n")  
   
   area_under_curve = area_under_curve + gauss

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

print("The area under the curve is " + str(area_under_curve))

