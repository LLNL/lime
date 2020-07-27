# From open project, type:
# source [get_property DIRECTORY [current_project]]/axi_delay_src.tcl

set repo_base C:/Xilinx/Vivado/2018.2/data/ip/xilinx
set proj_base [get_property DIRECTORY [current_project]]
# Option: [add_files -norecurse ...]
# To determine the files in a library, look in component.xml
# see xilinx_anylanguagebehavioralsimulation_view_fileset
# see xilinx_vhdlsynthesis_view_fileset
# Ignore library specification warnings for Verilog files
# VHDL source files need the library specification for mixed-lang. simulation

set_property target_language VHDL [current_project]

# axi_delay
set axi_delay axi_delay_lib
set_property -dict [ list LIBRARY $axi_delay USED_IN {synthesis simulation} ] [add_files $proj_base/hdl/axi_delay_pkg.vhd $proj_base/hdl/fifo_ccw.vhd $proj_base/hdl/chan_delay.vhd $proj_base/hdl/axi_delay.vhd]
set_property top axi_delay [current_fileset]

# blk_mem_gen
set blk_mem_gen blk_mem_gen_v8_4
set bmg_rev _1
# set_property -dict [ list LIBRARY $blk_mem_gen$bmg_rev USED_IN {synthesis} ] [add_files -fileset sources_1 $repo_base/$blk_mem_gen/hdl]
set_property -dict [ list LIBRARY $blk_mem_gen$bmg_rev USED_IN {simulation} ] [add_files -fileset sim_1 $repo_base/$blk_mem_gen/simulation/$blk_mem_gen.v]

# test bench
set_property -dict [ list LIBRARY work USED_IN {simulation} ] [add_files -fileset sim_1 $proj_base/tb/axi_blk_mem.vhd $proj_base/tb/axi_delay_tb.vhd]
set_property top axi_delay_tb [get_filesets sim_1]
