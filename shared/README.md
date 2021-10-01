# Generating Gaussian Delay Table (GDT) Files

The VLD's Gaussian Delay Tables (GDT) can be customized and updated using a python 2.7.x script located here:

&nbsp;&nbsp;&nbsp;&nbsp; lime/ip/2018.2/llnl.gov_user_axi_delayv_1.0.0/hdl/gaussian_delay/gaussian_delay.py

The purpose of this script is to create files that can be used to initialize a Xilinx BRAM within the VLD that is used as the delay look-up table. The address to the 
lookup table is randomized such that the values will be read out with the programmed gaussian distribution.

When the script is run, table files in several formats are created, some of which are not used in the current development environment. The generated files are listed below. The default base name for all files is "bram_del_table"; to change the base file name, guassian_delay.py must be edited.

-	mem_filename   = .mem file format, to be loaded into the FPGA during the FPGA build process. Since this file is used at FPGA build time, the values are persistent (i.e. non-volatile); however, the GDT can be updated at run-time via software 
		(see lime/shared/standalong/clocks.c). This .mem file is saved in lime/ip/2018.2/llnl.gov_user_axi_delayv_1.0.0/hdl/
-	txt_filename   = .txt (ASCII text) file used by clocks.c to update the GDT at run time. This file is saved in lime/shared
-	outputfilename = .csv (ASCII text) file for checking output. This file contains the index (address), value (float), and value (hex). This file is saved in the gaussian_delay directory.
-	mif_filename   = .mif (memory initialization) file containing the address and data, both in hex. This is saved in the gaussian_delay directory, but is not currently used.
-	bin_filename   = .init (ASCII binary) file for Vivado initialization. NOTE: this is NOT the same format as used in UpdateMem program. This is saved in the gaussian_delay directory, but is not currently used.
-	coe_filename   = .coe (co-efficient) file format . This is saved in the gaussian_delay directory, but is not currently used.

## Using the Script

To run gaussian_delay.py, two options are required:

&nbsp;&nbsp;&nbsp;&nbsp; python gaussian_delay.py \<delay\> \<divider\>
	
delay:    Mean Delay (mu)

divider:  Determines the standard deviation (sigma), where 

&nbsp;&nbsp;&nbsp;&nbsp; sigma = mu/divider

## File naming

clocks.c loads eight GDT files at run-time (one for each of the eight VLD instantiations). When generating new GDT files for loading at run-time, the basename of the generated files must be coordinated with the names expected by clocks.c. For example, the following snippet from clocks.c loads the eight GDTs: 

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

The generated filenames must either match the filenames loaded by clocks.c shown above, or clocks.c must be modified.