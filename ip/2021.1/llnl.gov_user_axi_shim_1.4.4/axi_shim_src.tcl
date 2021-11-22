# From open project, type:
# source [get_property DIRECTORY [current_project]]/axi_shim_src.tcl

set repo_base C:/Xilinx/Vivado/2018.2/data/ip/xilinx
set proj_base [get_property DIRECTORY [current_project]]
# Option: [add_files -norecurse ...]
# To determine the files in a library, look in component.xml
# see xilinx_anylanguagebehavioralsimulation_view_fileset
# see xilinx_vhdlsynthesis_view_fileset
# Ignore library specification warnings for Verilog files
# VHDL source files need the library specification for mixed-lang. simulation

set_property target_language VHDL [current_project]

# axi_shim
set axi_shim axi_shim_lib
set_property -dict [ list LIBRARY $axi_shim USED_IN {synthesis simulation} ] [add_files $proj_base/hdl/axi_shim_pkg.vhd $proj_base/hdl/axi_shim.vhd]
set_property top axi_shim [current_fileset]
add_files -fileset constrs_1 $proj_base/hdl/axi_shim_ooc.xdc
set_property USED_IN {synthesis implementation out_of_context} [get_files $proj_base/hdl/axi_shim_ooc.xdc]

# test bench
# set_property -dict [ list LIBRARY work USED_IN {simulation} ] [add_files -fileset sim_1 $proj_base/tb/axi_blk_mem.vhd $proj_base/tb/axi_shim_tb.vhd]
# set_property top axi_shim_tb [get_filesets sim_1]
