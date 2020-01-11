#*******************************************************************************
#
# This file contains Vivado Tcl commands for re-creating the project.
# To re-create the project, source this file in the Vivado Tcl Shell.
#
#*******************************************************************************

set ENABLE_ENGINE 1
set ENGINE_SOURCE engine_dre_la.tcl
set ENABLE_APM 1
set ENABLE_APM_DATA 0
set ENABLE_TRACE 1
set ENABLE_COMP 0

if {!$ENABLE_APM} {set ENABLE_TRACE 0; set ENABLE_APM_DATA 0}
if {!$ENABLE_TRACE} {set ENABLE_COMP 0}

# Set the root directory for source file relative paths
variable lime_dir
set lime_dir "../.."
if {[info exists ::user_lime_dir]} {
	set lime_dir $::user_lime_dir
}

# Set the project name
variable proj_name
set proj_name "proj"
if {[info exists ::user_project_name]} {
	set proj_name $::user_project_name
}

# Set main design name
variable design_name
set design_name "system"
if {[info exists ::user_design_name]} {
	set design_name $::user_design_name
}

variable script_file
set script_file [file tail [info script]]

variable script_folder
set script_folder [file dirname [file normalize [info script]]]

variable current_vivado_version
set current_vivado_version [version \-short]

variable ip_dir
set ip_dir "$lime_dir/ip/$current_vivado_version"

# Help information for this script
proc help {} {
	variable lime_dir
	variable proj_name
	variable script_file
	puts "\nDescription:"
	puts "Recreate a Vivado project from this script."
	puts "Syntax:"
	puts "$script_file"
	puts "$script_file -tclargs \[--lime_dir <path>\]"
	puts "$script_file -tclargs \[--project_name <name>\]"
	puts "$script_file -tclargs \[--design_name <name>\]"
	puts "$script_file -tclargs \[--help\]\n"
	puts "Usage:"
	puts "Name                      Description"
	puts "-------------------------------------------------------------------------"
	puts "\[--lime_dir <path>\]     Determine source file paths wrt this path."
	puts "                        Default path is \"$lime_dir\".\n"
	puts "\[--project_name <name>\] Create project with the specified name."
	puts "                        Default name is \"$proj_name\".\n"
	puts "\[--design_name <name>\]  Create design with the specified name."
	puts "                        Default name is \"$design_name\".\n"
	puts "\[--help\]                Print help information for this script"
	puts "-------------------------------------------------------------------------\n"
	exit 0
}

if {$::argc > 0} {
	for {set i 0} {$i < $::argc} {incr i} {
		set option [string trim [lindex $::argv $i]]
		switch -regexp -- $option {
			"--lime_dir"   {incr i; set lime_dir [lindex $::argv $i]}
			"--project_name" {incr i; set proj_name [lindex $::argv $i]}
			"--help"         {help}
			default {
			if {[regexp {^-} $option]} {
				puts "ERROR: Unknown option '$option' specified, please type '$script_file -tclargs --help' for usage info.\n"
				return 1
			}
			}
		}
	}
}

set_param board.repoPaths [list "$lime_dir/boards"]

# Create project
# BOARD: part
create_project ${proj_name} ./ -part xczu19eg-ffvc1760-2-i
set cproj [current_project]

# Set project properties
# BOARD: board_part
set_property board_part fidus.com:sidewinder100:part0:1.0 $cproj
set_property default_lib xil_defaultlib $cproj
set_property xpm_libraries "XPM_CDC XPM_MEMORY" $cproj
set_property ip_repo_paths  "$ip_dir $lime_dir/ip/hls" $cproj
update_ip_catalog -rebuild

# Set the directory path for the new project
set proj_dir [get_property directory $cproj]

# Suppress warning
# set_msg_config -id {[IP_Flow nn-nnnn]} -suppress

# Proc to create main BD
proc cr_bd_main {parentCell} {
	variable ENABLE_ENGINE
	variable ENGINE_SOURCE
	variable ENABLE_APM
	variable ENABLE_APM_DATA
	variable ENABLE_TRACE
	variable ENABLE_COMP

	variable design_name
	variable ip_dir

	create_bd_design $design_name

	puts "########## create $design_name begin ##########"

	if {$parentCell eq ""} {
		set parentCell [get_bd_cells /]
	}

	# Get object for parentCell
	set parentObj [get_bd_cells $parentCell]
	if {$parentObj eq ""} {
		catch {common::send_msg_id "BD_TCL-100" "ERROR" "Unable to find parent cell <$parentCell>!"}
		return
	}

	# Make sure parentObj is hier blk
	set parentType [get_property TYPE $parentObj]
	if {$parentType ne "hier"} {
		catch {common::send_msg_id "BD_TCL-101" "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
		return
	}

	# Save current instance; Restore later
	set oldCurInst [current_bd_instance .]

	# Set parent object as current
	current_bd_instance $parentObj

	##################################################################
	# Main Block Design - begin
	##################################################################

	# BOARD: memory, shim, and trace parameters

	# PS memory size
	set ps_mem_sz {16G}

	# shim base address: 0x10_0000_0000
	# main memory range: up to 16G
	# scratch pad memory range: 1M
	# actual base address: 0x08_0000_0000
	set map0_in {00010000000000000000}
	set map0_out {00001000000000000000}
	set map0_width {20}
	set map1_in {00010}
	set map1_out {00011}
	set map1_width {5}
	set mem_addr_width {36}

	set trc_tdata_width [expr $ENABLE_APM_DATA ? 1024 : 512]
	# PL memory size = 2^width
	set trc_addr_width {34}
	set trc_data_width {512}
	set trc_ddr_ver "DDR4"
	########## main ##########

	# Create instance: zynq_ps_0
	# BOARD: Zynq configuration
	set zynq_ps_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.2 zynq_ps_0]
	# set_property -dict [list CONFIG.preset {???}] $zynq_ps_0
	apply_bd_automation \
		-rule xilinx.com:bd_rule:zynq_ultra_ps_e \
		-config {apply_board_preset "1"} \
		$zynq_ps_0
	# Needs to be applied after setting board presets
	set_property -dict [list \
		CONFIG.PSU__USE__M_AXI_GP0 {1} \
		CONFIG.PSU__USE__M_AXI_GP1 {1} \
		CONFIG.PSU__USE__S_AXI_GP2 {1} \
		CONFIG.PSU__USE__S_AXI_GP3 {1} \
		CONFIG.PSU__MAXIGP1__DATA_WIDTH {32} \
		CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {250} \
		CONFIG.PSU__FPGA_PL1_ENABLE {1} \
		CONFIG.PSU__CRL_APB__PL1_REF_CTRL__SRCSEL {IOPLL} \
		CONFIG.PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ {300} \
		CONFIG.PSU__NUM_FABRIC_RESETS {2} \
		CONFIG.PSU__HIGH_ADDRESS__ENABLE {1} \
	] $zynq_ps_0

	create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_pl_clk0

	create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_pl_clk1

	# Create instance: delay_0
	set cpu_addr_width [get_property CONFIG.ADDR_WIDTH [get_bd_intf_pins zynq_ps_0/M_AXI_HPM0_FPD]]
	set cpu_data_width [get_property CONFIG.DATA_WIDTH [get_bd_intf_pins zynq_ps_0/M_AXI_HPM0_FPD]]
	set cpu_id_width [get_property CONFIG.ID_WIDTH [get_bd_intf_pins zynq_ps_0/M_AXI_HPM0_FPD]]
	source "$ip_dir/blocks/delay.tcl"
	create_hier_cell_delay [current_bd_instance .] delay_0 \
		$cpu_addr_width $cpu_data_width $cpu_id_width 0 \
		$map0_in $map0_out $map0_width \
		$map1_in $map1_out $map1_width \
		$mem_addr_width

	# Connect Zynq clocks/resets to processor system reset
	connect_bd_net [get_bd_pins zynq_ps_0/pl_clk0] [get_bd_pins rst_pl_clk0/slowest_sync_clk]
	connect_bd_net [get_bd_pins zynq_ps_0/pl_resetn0] [get_bd_pins rst_pl_clk0/ext_reset_in]
	connect_bd_net [get_bd_pins zynq_ps_0/pl_clk1] [get_bd_pins rst_pl_clk1/slowest_sync_clk]
	connect_bd_net [get_bd_pins zynq_ps_0/pl_resetn1] [get_bd_pins rst_pl_clk1/ext_reset_in]

	# Connect Zynq PS AXI clocks
	connect_bd_net [get_bd_pins zynq_ps_0/pl_clk0] [get_bd_pins zynq_ps_0/maxihpm1_fpd_aclk]
	connect_bd_net [get_bd_pins zynq_ps_0/pl_clk1] [get_bd_pins zynq_ps_0/maxihpm0_fpd_aclk]
	connect_bd_net [get_bd_pins zynq_ps_0/pl_clk1] [get_bd_pins zynq_ps_0/saxihp0_fpd_aclk]
	connect_bd_net [get_bd_pins zynq_ps_0/pl_clk1] [get_bd_pins zynq_ps_0/saxihp1_fpd_aclk]

	# Connect delay_0 in loopback
	connect_bd_net [get_bd_pins zynq_ps_0/pl_clk1] [get_bd_pins delay_0/ACLK]
	connect_bd_net [get_bd_pins rst_pl_clk1/interconnect_aresetn] [get_bd_pins delay_0/ARESETN]
	connect_bd_intf_net [get_bd_intf_pins zynq_ps_0/M_AXI_HPM0_FPD] [get_bd_intf_pins delay_0/S_AXI]
	connect_bd_intf_net [get_bd_intf_pins delay_0/M0_AXI] [get_bd_intf_pins zynq_ps_0/S_AXI_HP0_FPD]
	connect_bd_intf_net [get_bd_intf_pins delay_0/M1_AXI] [get_bd_intf_pins zynq_ps_0/S_AXI_HP1_FPD]
	apply_bd_automation \
		-rule xilinx.com:bd_rule:axi4 \
		-config {Master "/zynq_ps_0/M_AXI_HPM1_FPD" Clk "Auto"} \
		[get_bd_intf_pins delay_0/S0_AXI_LITE]
	apply_bd_automation \
		-rule xilinx.com:bd_rule:axi4 \
		-config {Master "/zynq_ps_0/M_AXI_HPM1_FPD" Clk "Auto"} \
		[get_bd_intf_pins delay_0/S1_AXI_LITE]

	########## engine ##########
	if {$ENABLE_ENGINE} {

	# Configure Zynq S_AXI_HP2_FPD & S_AXI_HP3_FPD ports
	# BOARD: Zynq configuration
	set_property -dict [list \
		CONFIG.PSU__USE__S_AXI_GP4 {1} \
		CONFIG.PSU__SAXIGP4__DATA_WIDTH {64} \
		CONFIG.PSU__USE__S_AXI_GP5 {1} \
		CONFIG.PSU__SAXIGP5__DATA_WIDTH {64} \
	] $zynq_ps_0

	# TODO: programmatically set or propagate width params based on master
	set eng_addr_width $cpu_addr_width
	set eng_data_width [get_property CONFIG.DATA_WIDTH [get_bd_intf_pins zynq_ps_0/S_AXI_HP2_FPD]]
	set eng_id_width {3}

	# Connect Zynq PS AXI clocks
	connect_bd_net [get_bd_pins zynq_ps_0/pl_clk1] [get_bd_pins zynq_ps_0/saxihp2_fpd_aclk]
	connect_bd_net [get_bd_pins zynq_ps_0/pl_clk1] [get_bd_pins zynq_ps_0/saxihp3_fpd_aclk]

	# Create instance: engine_0
	source "$ip_dir/blocks/$ENGINE_SOURCE"
	create_hier_cell_engine [current_bd_instance .] engine_0 \
		$eng_addr_width $eng_data_width

	# Create instance: delay_1
	source "$ip_dir/blocks/delay.tcl"
	create_hier_cell_delay [current_bd_instance .] delay_1 \
		$eng_addr_width $eng_data_width $eng_id_width 0 \
		{00000000000000000000} $map0_out $map0_width \
		{00000} $map1_out $map1_width \
		$mem_addr_width

	# Connect delay_1
	connect_bd_net [get_bd_pins zynq_ps_0/pl_clk1] [get_bd_pins delay_1/ACLK]
	connect_bd_net [get_bd_pins rst_pl_clk1/interconnect_aresetn] [get_bd_pins delay_1/ARESETN]
	connect_bd_intf_net [get_bd_intf_pins delay_1/M0_AXI] [get_bd_intf_pins zynq_ps_0/S_AXI_HP2_FPD]
	connect_bd_intf_net [get_bd_intf_pins delay_1/M1_AXI] [get_bd_intf_pins zynq_ps_0/S_AXI_HP3_FPD]
	apply_bd_automation \
		-rule xilinx.com:bd_rule:axi4 \
		-config {Master "/zynq_ps_0/M_AXI_HPM1_FPD" Clk "Auto"} \
		[get_bd_intf_pins delay_1/S0_AXI_LITE]
	apply_bd_automation \
		-rule xilinx.com:bd_rule:axi4 \
		-config {Master "/zynq_ps_0/M_AXI_HPM1_FPD" Clk "Auto"} \
		[get_bd_intf_pins delay_1/S1_AXI_LITE]

	# Connect engine_0
	connect_bd_net [get_bd_pins zynq_ps_0/pl_clk1] [get_bd_pins engine_0/ACLK]
	connect_bd_net [get_bd_pins rst_pl_clk1/interconnect_aresetn] [get_bd_pins engine_0/ARESETN]
	connect_bd_net [get_bd_pins zynq_ps_0/pl_clk1] [get_bd_pins engine_0/M_ACLK]
	connect_bd_net [get_bd_pins rst_pl_clk1/peripheral_aresetn] [get_bd_pins engine_0/M_ARESETN]
	connect_bd_intf_net [get_bd_intf_pins engine_0/M_AXI] [get_bd_intf_pins delay_1/S_AXI]
	connect_bd_net [get_bd_pins zynq_ps_0/pl_resetn0] [get_bd_pins engine_0/S_D0_ARESETN]
	apply_bd_automation \
		-rule xilinx.com:bd_rule:axi4 \
		-config {Master "/zynq_ps_0/M_AXI_HPM1_FPD" Clk "Auto"} \
		[get_bd_intf_pins engine_0/S_AXI]

	}
	########## APM ##########
	if {$ENABLE_APM} {

	# Create instance: apm_0
	set apm_0 [create_bd_cell -type ip -vlnv xilinx.com:user:axi_perf_mon:5.0 apm_0]
	set_property -dict [list \
		CONFIG.C_ENABLE_EVENT_LOG $ENABLE_TRACE \
		CONFIG.C_GLOBAL_COUNT_WIDTH {64} \
		CONFIG.C_NUM_MONITOR_SLOTS [expr $ENABLE_ENGINE ? 2 : 1] \
		CONFIG.C_NUM_OF_COUNTERS {8} \
		CONFIG.C_SHOW_AXI_IDS {1} \
		CONFIG.C_SHOW_AXI_LEN {1} \
	] $apm_0
	if {$ENABLE_APM_DATA} {set_property CONFIG.C_SHOW_AXI_DATA {1} $apm_0}

	# Connect apm_0
	connect_bd_intf_net [get_bd_intf_pins zynq_ps_0/M_AXI_HPM0_FPD] [get_bd_intf_pins apm_0/SLOT_0_AXI]

	connect_bd_net [get_bd_pins zynq_ps_0/pl_clk1] [get_bd_pins apm_0/core_aclk]
	connect_bd_net [get_bd_pins rst_pl_clk1/peripheral_aresetn] [get_bd_pins apm_0/core_aresetn]
	connect_bd_net [get_bd_pins zynq_ps_0/pl_clk1] [get_bd_pins apm_0/slot_0_axi_aclk]
	connect_bd_net [get_bd_pins rst_pl_clk1/peripheral_aresetn] [get_bd_pins apm_0/slot_0_axi_aresetn]

	if {$ENABLE_ENGINE} {
	connect_bd_intf_net [get_bd_intf_pins engine_0/M_AXI] [get_bd_intf_pins apm_0/SLOT_1_AXI]
	connect_bd_net [get_bd_pins zynq_ps_0/pl_clk1] [get_bd_pins apm_0/slot_1_axi_aclk]
	connect_bd_net [get_bd_pins rst_pl_clk1/peripheral_aresetn] [get_bd_pins apm_0/slot_1_axi_aresetn]
	}

	if {$ENABLE_TRACE} {
	connect_bd_net [get_bd_pins zynq_ps_0/pl_clk1] [get_bd_pins apm_0/m_axis_aclk]
	connect_bd_net [get_bd_pins rst_pl_clk1/peripheral_aresetn] [get_bd_pins apm_0/m_axis_aresetn]
	}

	apply_bd_automation \
		-rule xilinx.com:bd_rule:axi4 \
		-config {Master "/zynq_ps_0/M_AXI_HPM1_FPD" Clk "Auto"} \
		[get_bd_intf_pins apm_0/S_AXI]

	}
	########## trace ##########
	if {$ENABLE_TRACE} {

	# Create external ports
	# BOARD: sysclk
	# TODO: set property from board file?
	set sysclk [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 sysclk]
	set_property CONFIG.FREQ_HZ {333330000} $sysclk
	set reset [create_bd_port -dir I -type rst reset]
	set_property CONFIG.POLARITY {ACTIVE_LOW} $reset
	set trace_sdram [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 trace_sdram]
	set calib_complete [create_bd_port -dir O calib_complete]

	# Inverter for reset
	set inv_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 inv_0]
	set_property -dict [list \
		CONFIG.C_SIZE {1} \
		CONFIG.C_OPERATION {not} \
		CONFIG.LOGO_FILE {data/sym_notgate.png} \
	] $inv_0
	connect_bd_net $reset [get_bd_pins inv_0/Op1]

	# Create instance: trace_0
	source "$ip_dir/blocks/trace.tcl"
	create_hier_cell_trace [current_bd_instance .] trace_0 \
		$trc_tdata_width $trc_addr_width $trc_data_width $trc_ddr_ver

	# Connect trace_0
	# BOARD: sysclk
	connect_bd_intf_net $sysclk [get_bd_intf_pins trace_0/sysclk]
	connect_bd_net [get_bd_pins inv_0/Res] [get_bd_pins trace_0/reset]
	connect_bd_intf_net [get_bd_intf_pins trace_0/ddr_sdram] $trace_sdram
	connect_bd_net [get_bd_pins trace_0/calib_complete] $calib_complete
	connect_bd_net [get_bd_pins zynq_ps_0/pl_clk1] [get_bd_pins trace_0/AXIS_ACLK]
	connect_bd_net [get_bd_pins rst_pl_clk1/peripheral_aresetn] [get_bd_pins trace_0/AXIS_ARESETN]
	connect_bd_intf_net [get_bd_intf_pins apm_0/M_AXIS] [get_bd_intf_pins trace_0/S_AXIS]
	apply_bd_automation \
		-rule xilinx.com:bd_rule:axi4 \
		-config {Master "/zynq_ps_0/M_AXI_HPM1_FPD" Clk "Auto"} \
		[get_bd_intf_pins trace_0/S_AXI_LITE]

	# BOARD: sysclk
	set_property -dict [list \
		CONFIG.C0_CLOCK_BOARD_INTERFACE {PL_DDR_CLK} \
		CONFIG.C0_DDR4_BOARD_INTERFACE {ddr4_sdram} \
		CONFIG.RESET_BOARD_INTERFACE {reset} \
	] [get_bd_cells trace_0/ddr_0]

	if {$ENABLE_COMP} {source "$ip_dir/blocks/competh.tcl"}

	}
	########## address begin ##########
	# Example: list address spaces and segments
	# join [get_bd_addr_spaces] \n
	# join [get_bd_addr_segs -of_objects [get_bd_addr_spaces]] \n

	assign_bd_address -offset 0x1000000000 -range $ps_mem_sz [get_bd_addr_segs {delay_0/axi_shim_0/s_axi/mem0}]
	assign_bd_address -offset 0x0000000000 -range 128G [get_bd_addr_segs {delay_0/axi_shim_1/s_axi/mem0}]
	assign_bd_address -offset 0x0800000000 -range   1M [get_bd_addr_segs {delay_0/axi_delay_0/s_axi/mem0}]
	assign_bd_address -offset 0x1800000000 -range  32G [get_bd_addr_segs {delay_0/axi_delay_1/s_axi/mem0}]
	assign_bd_address [get_bd_addr_segs {zynq_ps_0/SAXIGP2/HP0_DDR_HIGH}]
	assign_bd_address [get_bd_addr_segs {zynq_ps_0/SAXIGP2/HP0_DDR_LOW}]
	assign_bd_address [get_bd_addr_segs {zynq_ps_0/SAXIGP3/HP1_DDR_HIGH}]
	assign_bd_address [get_bd_addr_segs {zynq_ps_0/SAXIGP3/HP1_DDR_LOW}]

	if {$ENABLE_ENGINE} {
	# MicroBlaze range must be reduced to 2G to allow for BRAM at 0xD0000000
	# These need to be assigned separately because of the different sized MicroBlaze segment
	assign_bd_address -offset 0x00000000 -range 2G -target_address_space [get_bd_addr_spaces engine_0/mcu_0/microblaze_0/Data] [get_bd_addr_segs delay_1/axi_shim_0/s_axi/mem0]
	assign_bd_address -offset 0x00000000 -range $ps_mem_sz -target_address_space [get_bd_addr_spaces engine_0/axi_lsu_0/m_axi] [get_bd_addr_segs delay_1/axi_shim_0/s_axi/mem0]
	assign_bd_address -offset 0x00000000 -range $ps_mem_sz -target_address_space [get_bd_addr_spaces engine_0/axi_lsu_1/m_axi] [get_bd_addr_segs delay_1/axi_shim_0/s_axi/mem0]
	assign_bd_address -offset 0x00000000 -range $ps_mem_sz -target_address_space [get_bd_addr_spaces engine_0/axi_lsu_2/m_axi] [get_bd_addr_segs delay_1/axi_shim_0/s_axi/mem0]

	# assign_bd_address -offset 0x0000000000 -range   ?G [get_bd_addr_segs {delay_1/axi_shim_0/s_axi/mem0}]
	assign_bd_address -offset 0x0000000000 -range 128G [get_bd_addr_segs {delay_1/axi_shim_1/s_axi/mem0}]
	assign_bd_address -offset 0x0800000000 -range   1M [get_bd_addr_segs {delay_1/axi_delay_0/s_axi/mem0}]
	assign_bd_address -offset 0x1800000000 -range  32G [get_bd_addr_segs {delay_1/axi_delay_1/s_axi/mem0}]
	assign_bd_address [get_bd_addr_segs {zynq_ps_0/SAXIGP4/HP2_DDR_HIGH}]
	assign_bd_address [get_bd_addr_segs {zynq_ps_0/SAXIGP4/HP2_DDR_LOW}]
	assign_bd_address [get_bd_addr_segs {zynq_ps_0/SAXIGP5/HP3_DDR_HIGH}]
	assign_bd_address [get_bd_addr_segs {zynq_ps_0/SAXIGP5/HP3_DDR_LOW}]

	assign_bd_address -offset 0xD0000000 -range 64K [get_bd_addr_segs {engine_0/mcu_0/lmb_0/dlmb_bram_if_cntlr/SLMB/Mem}]
	assign_bd_address -offset 0xD0000000 -range 64K [get_bd_addr_segs {engine_0/mcu_0/lmb_0/ilmb_bram_if_cntlr/SLMB/Mem}]
	}

	if {$ENABLE_TRACE} {
	assign_bd_address [get_bd_addr_segs {trace_0/ddr_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK}]
	}

	########## address end ##########

	##################################################################
	# Main Block Design - end
	##################################################################

	puts "########## create $design_name end ##########"

	# Restore current instance
	current_bd_instance $oldCurInst

	validate_bd_design
	# Save after validate to keep any propagated parameters
	save_bd_design

	close_bd_design $design_name
}
# End of cr_bd_main()

cr_bd_main ""

puts "########## create $design_name wrapper begin ##########"
set wrapper [make_wrapper -files [get_files -of_objects [get_filesets [current_fileset]] $design_name.bd] -top]
# Using the make_wrapper -import option produces an "already been imported" warning
add_files -norecurse $wrapper
puts "########## create $design_name wrapper end ##########"

puts "########## create system.xdc begin ##########"
# Example: get board interface and pin properties
# get_property LOC [get_board_part_pins -of [get_board_part_interfaces led_8bits]]
# Response: AG14 AF13 AE13 AJ14 AJ15 AH13 AH14 AL12
# get_property LOC [get_board_part_pins GPIO_LED_0_LS]
# Response: AG14

set cpath "$proj_dir/$proj_name.srcs/[current_fileset -constrset]/new"
file mkdir "$cpath"
set cfid [open "$cpath/system.xdc" w]

if {$ENABLE_TRACE} {
# BOARD: sysclk, LED_0
puts $cfid {set_clock_groups -asynchronous \
	-group clk_pl_0 \
	-group clk_pl_1 \
	-group [get_clocks -include_generated_clocks sysclk_clk_p]}
puts $cfid "set_property PACKAGE_PIN \
	[get_property LOC [get_board_part_pins GPIO_LED_0_LS]] \
	\[get_ports calib_complete\]"
puts $cfid "set_property IOSTANDARD \
	[get_property IOSTANDARD [get_board_part_pins GPIO_LED_0_LS]] \
	\[get_ports calib_complete\]"
} else {
puts $cfid {set_clock_groups -asynchronous -group clk_pl_0 -group clk_pl_1}
}

close $cfid
add_files -fileset [current_fileset -constrset] "$cpath/system.xdc"
set_property TARGET_CONSTRS_FILE "$cpath/system.xdc" [current_fileset -constrset]
set_property USED_IN_SYNTHESIS 0 [get_files "$cpath/system.xdc"]
puts "########## create system.xdc end ##########"

puts "INFO: Project created: ${proj_name}"
close_project
