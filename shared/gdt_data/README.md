#  Delay Tables
## Pre-generated tables

This directory contains a collection of delay tables that have been previously generated. The tables in this location are used by lime/shared/standalone/clocks.c and lime/shared/linux/clocks.c. The tables hold clock delay values corresponding to a Gaussian Distribution.


## File naming

clocks.c in lime/shared/standalone and lime/shared/linux loads eight GDT files at run-time (one for each of the eight VLD instantiations). For example, the following code (in lime/shared/standalone/clocks.c) loads the eight GDTs: 

&nbsp;&nbsp;&nbsp;&nbsp; int gdt_0_0_b[1024] = {  
&nbsp;&nbsp;&nbsp;&nbsp; &nbsp;&nbsp;&nbsp;&nbsp; #include "gdt_data_g216.txt";  
&nbsp;&nbsp;&nbsp;&nbsp; &nbsp;&nbsp;&nbsp;&nbsp; };

&nbsp;&nbsp;&nbsp;&nbsp; int gdt_0_0_r[1024] = {  
&nbsp;&nbsp;&nbsp;&nbsp; &nbsp;&nbsp;&nbsp;&nbsp; #include "gdt_data_g216.txt";  
&nbsp;&nbsp;&nbsp;&nbsp; &nbsp;&nbsp;&nbsp;&nbsp; };

&nbsp;&nbsp;&nbsp;&nbsp; int gdt_0_1_b[1024] = {  
&nbsp;&nbsp;&nbsp;&nbsp; &nbsp;&nbsp;&nbsp;&nbsp; #include "gdt_data_g636.txt";  
&nbsp;&nbsp;&nbsp;&nbsp; &nbsp;&nbsp;&nbsp;&nbsp; };

&nbsp;&nbsp;&nbsp;&nbsp; int gdt_0_1_r[1024] = {  
&nbsp;&nbsp;&nbsp;&nbsp; &nbsp;&nbsp;&nbsp;&nbsp; #include "gdt_data_g510.txt";  
&nbsp;&nbsp;&nbsp;&nbsp; &nbsp;&nbsp;&nbsp;&nbsp; };

&nbsp;&nbsp;&nbsp;&nbsp; int gdt_1_0_b[1024] = {  
&nbsp;&nbsp;&nbsp;&nbsp; &nbsp;&nbsp;&nbsp;&nbsp; #include "gdt_data_g72.txt";  
&nbsp;&nbsp;&nbsp;&nbsp; &nbsp;&nbsp;&nbsp;&nbsp; };

&nbsp;&nbsp;&nbsp;&nbsp; int gdt_1_0_r[1024] = {  
&nbsp;&nbsp;&nbsp;&nbsp; &nbsp;&nbsp;&nbsp;&nbsp; #include "gdt_data_g72.txt";  
&nbsp;&nbsp;&nbsp;&nbsp; &nbsp;&nbsp;&nbsp;&nbsp; };

&nbsp;&nbsp;&nbsp;&nbsp; int gdt_1_1_b[1024] = {  
&nbsp;&nbsp;&nbsp;&nbsp; &nbsp;&nbsp;&nbsp;&nbsp; #include "gdt_data_g492.txt";  
&nbsp;&nbsp;&nbsp;&nbsp; &nbsp;&nbsp;&nbsp;&nbsp; };

&nbsp;&nbsp;&nbsp;&nbsp; int gdt_1_1_r[1024] = {  
&nbsp;&nbsp;&nbsp;&nbsp; &nbsp;&nbsp;&nbsp;&nbsp; #include "gdt_data_g366.txt";  
&nbsp;&nbsp;&nbsp;&nbsp; &nbsp;&nbsp;&nbsp;&nbsp; };

In the above example, "gxxx" indicates that the file contains a Gaussian with a Mean Delay of xxx; the file named gdt_data_g216.txt therefore contains a Gaussian with a Mean Delay of 216 clocks.
These file names have been manually edited to conform to this naming convention, and all corresponding files are saved in the repository. When generating new GDT files for loading at run-time, the basename of the 
generated files must be coordinated with the names expected by clocks.c.

## Generating Gaussian Delay Table (GDT) Files

The VLD's Gaussian Delay Tables (GDT) can be customized and updated using a python 2.7.x script located here:

&nbsp;&nbsp;&nbsp;&nbsp; lime/ip/2018.2/llnl.gov_user_axi_delayv_1.0.0/hdl/gaussian_delay/gaussian_delay.py

The purpose of this script is to create files that can be used to initialize a Xilinx BRAM within the VLD that is used as the delay look-up table. The address to the 
lookup table is randomized such that the values will be read out with the programmed gaussian distribution.

When the script is run, table files in several formats are created, some of which are not used in the current development environment. 
The generated files are listed below. All files will be generated with the base filename of gdt_data_gxxx_mu_divyyy.zzz, where xxx is the Mean Delay and yyy is the divider (see below for a detailed description), and zzz is the appropirate extension.

-	mem_filename   = .mem file format, to be loaded into the FPGA during the FPGA build process. Since this file is used at FPGA build time, the values are persistent (i.e. non-volatile); however, the GDT can be updated at run-time via software 
		(see lime/shared/standalong/clocks.c). This .mem file is saved in lime/ip/2018.2/llnl.gov_user_axi_delayv_1.0.0/hdl/
-	txt_filename   = .txt (ASCII text) file used by clocks.c to update the GDT at run time. This file is saved in lime/shared/gdt_data
-	outputfilename = .csv (ASCII text) file for checking output. This file contains the index (address), value (float), and value (hex). This file is saved in the gaussian_delay directory.
-	mif_filename   = .mif (memory initialization) file containing the address and data, both in hex. This is saved in the gaussian_delay directory, but is not currently used.
-	bin_filename   = .init (ASCII binary) file for Vivado initialization. NOTE: this is NOT the same format as used in UpdateMem program. This is saved in the gaussian_delay directory, but is not currently used.
-	coe_filename   = .coe (co-efficient) file format . This is saved in the gaussian_delay directory, but is not currently used.

### Using the Script

To run gaussian_delay.py, two options are required:

&nbsp;&nbsp;&nbsp;&nbsp; python gaussian_delay.py \<delay\> \<divider\>
	
delay:    Mean Delay (mu). This is the desired mean delay, in clock cycles, for the targeted AXI channel. Each channel has an inherent latency due to logic and propagation delays; this inherent
latency has been calibrated in hardware and adjusted for in the C code such that Mean Delay is the total (calibrated) delay through the channel.

divider:  Determines the standard deviation (sigma), where 

&nbsp;&nbsp;&nbsp;&nbsp; sigma = mu/divider

The latest version of gaussian_delay.py, will automatically generate all files with the naming convention:  gdt_data_gxxx_mu_divyyy.zzz, where xxx is the Mean Delay and yyy is the divider.
To maintain filename coordination between newly generated GDT files and clocks.c, the user must either edit clocks.c to reference the new filenames, or manually change the filenames to match clocks.c.
