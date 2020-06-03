
if {[info exists _engine_tcl]} {return}
set _engine_tcl 1

source "[file dirname [info script]]/mcu.tcl"
source "[file dirname [info script]]/host.tcl"


# Hierarchical cell: engine
proc create_hier_cell_engine {parentCell nameHier addr_width data_width} {

	puts "########## create $nameHier begin ##########"

	if {$parentCell eq "" || $nameHier eq ""} {
		catch {common::send_msg_id "BD_TCL-102" "ERROR" "create_hier_cell_engine() - Empty argument(s)!"}
		return
	}

	# Get object for parentCell
	set parentObj [get_bd_cells $parentCell]
	if {$parentObj == ""} {
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

	# Create cell and set as current instance
	set hier_obj [create_bd_cell -type hier $nameHier]
	current_bd_instance $hier_obj

	# Create interface pins
	create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI
	create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI

	# Create pins
	create_bd_pin -dir I -type clk S_ACLK
	create_bd_pin -dir I -type rst S_D0_ARESETN
	create_bd_pin -dir I -type clk ACLK
	create_bd_pin -dir I -type rst ARESETN
	create_bd_pin -dir I -type clk M_ACLK
	create_bd_pin -dir I -type rst M_ARESETN

	# Create instance: axi_data_0, and set properties
	set axi_data_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_data_0]
	set_property -dict [list \
		CONFIG.ENABLE_ADVANCED_OPTIONS {1} \
		CONFIG.NUM_MI {1} \
		CONFIG.NUM_SI {2} \
		CONFIG.SYNCHRONIZATION_STAGES {2} \
		CONFIG.XBAR_DATA_WIDTH $data_width \
	] $axi_data_0

	# Create instance: axi_lsu_0, and set properties
	set axi_lsu_0 [create_bd_cell -type ip -vlnv llnl.gov:user:axi_lsu:2.3 axi_lsu_0]
	set_property -dict [list \
		CONFIG.C_AXI_MAP_ADDR_WIDTH $addr_width \
	] $axi_lsu_0

	# Create instance: axis_ctl_0, and set properties
	# HAS_TLAST must be set to 1 before setting ARB_ON_TLAST to 1
	# ARB_ON_TLAST must be set to 1 before setting ARB_ON_MAX_XFERS & ARB_ON_NUM_CYCLES to 0
	set axis_ctl_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_ctl_0]
	set_property -dict [list \
		CONFIG.HAS_TLAST {1} \
		CONFIG.ARB_ON_TLAST {1} \
		CONFIG.ARB_ON_MAX_XFERS {0} \
		CONFIG.ARB_ON_NUM_CYCLES {0} \
		CONFIG.M00_AXIS_BASETDEST {0x00000000} \
		CONFIG.M00_AXIS_HIGHTDEST {0x00000001} \
		CONFIG.M01_AXIS_BASETDEST {0x00000002} \
		CONFIG.M01_AXIS_HIGHTDEST {0x00000003} \
		CONFIG.M02_AXIS_BASETDEST {0x00000004} \
		CONFIG.M02_AXIS_HIGHTDEST {0x00000005} \
		CONFIG.NUM_MI {3} \
		CONFIG.NUM_SI {3} \
	] $axis_ctl_0

	# Create instance: host_0
	create_hier_cell_host $hier_obj host_0

	# Create instance: mcu_0
	create_hier_cell_mcu $hier_obj mcu_0

	# Create instance: mdm_0, and set properties
	set mdm_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:mdm:3.2 mdm_0]

	# Create instance: proc_sys_reset_eng
	set proc_sys_reset_eng [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_eng]

	# Create interface connections

	# Host connection
	connect_bd_intf_net [get_bd_intf_pins S_AXI] \
		[get_bd_intf_pins host_0/S_AXI]

	# DRE connections
	connect_bd_intf_net [get_bd_intf_pins mdm_0/MBDEBUG_0] \
		[get_bd_intf_pins mcu_0/DEBUG]
	connect_bd_intf_net [get_bd_intf_pins axi_lsu_0/m_axis_dat] \
		[get_bd_intf_pins axi_lsu_0/s_axis_dat]

	# Control switch master ports
	connect_bd_intf_net [get_bd_intf_pins axis_ctl_0/M00_AXIS] \
		[get_bd_intf_pins host_0/S_AXIS]
	connect_bd_intf_net [get_bd_intf_pins axis_ctl_0/M01_AXIS] \
		[get_bd_intf_pins mcu_0/S0_AXIS]
	connect_bd_intf_net [get_bd_intf_pins axis_ctl_0/M02_AXIS] \
		[get_bd_intf_pins axi_lsu_0/s_axis_ctl]

	# Control switch slave ports
	connect_bd_intf_net [get_bd_intf_pins host_0/M_AXIS] \
		[get_bd_intf_pins axis_ctl_0/S00_AXIS]
	connect_bd_intf_net [get_bd_intf_pins mcu_0/M0_AXIS] \
		[get_bd_intf_pins axis_ctl_0/S01_AXIS]
	connect_bd_intf_net [get_bd_intf_pins axi_lsu_0/m_axis_ctl] \
		[get_bd_intf_pins axis_ctl_0/S02_AXIS]

	# AXI interconnect
	connect_bd_intf_net [get_bd_intf_pins axi_lsu_0/m_axi] \
		[get_bd_intf_pins axi_data_0/S00_AXI]
	connect_bd_intf_net [get_bd_intf_pins mcu_0/M0_AXI] \
		[get_bd_intf_pins axi_data_0/S01_AXI]
	connect_bd_intf_net [get_bd_intf_pins axi_data_0/M00_AXI] \
		[get_bd_intf_pins M_AXI]

	# Create port connections

	# AXI data interconnect core clock and reset
	connect_bd_net [get_bd_pins ACLK] \
		[get_bd_pins axi_data_0/ACLK]
	connect_bd_net [get_bd_pins ARESETN] \
		[get_bd_pins axi_data_0/ARESETN]

	# AXI master clock and reset
	connect_bd_net [get_bd_pins M_ACLK] \
		[get_bd_pins axi_data_0/M00_ACLK]
	connect_bd_net [get_bd_pins M_ARESETN] \
		[get_bd_pins axi_data_0/M00_ARESETN]

	# AXI slave clock
	connect_bd_net [get_bd_pins S_ACLK] \
		[get_bd_pins proc_sys_reset_eng/slowest_sync_clk] \
		[get_bd_pins host_0/aclk] \
		[get_bd_pins mcu_0/aclk] \
		[get_bd_pins axi_data_0/S00_ACLK] \
		[get_bd_pins axi_data_0/S01_ACLK] \
		[get_bd_pins axi_lsu_0/ctl_aclk] \
		[get_bd_pins axi_lsu_0/data_aclk] \
		[get_bd_pins axis_ctl_0/aclk]

	# AXI slave resets
	connect_bd_net -net S_D0_ARESETN_1 \
		[get_bd_pins S_D0_ARESETN] \
		[get_bd_pins proc_sys_reset_eng/ext_reset_in]
	connect_bd_net -net S_D1_ARESETN_1 \
		[get_bd_pins proc_sys_reset_eng/interconnect_aresetn] \
		[get_bd_pins host_0/d1_aresetn] \
		[get_bd_pins mcu_0/d1_aresetn] \
		[get_bd_pins axis_ctl_0/aresetn]
	connect_bd_net -net S_D2_ARESETN_1 \
		[get_bd_pins proc_sys_reset_eng/peripheral_aresetn] \
		[get_bd_pins host_0/d2_aresetn] \
		[get_bd_pins mcu_0/d2_aresetn] \
		[get_bd_pins axi_data_0/S00_ARESETN] \
		[get_bd_pins axi_data_0/S01_ARESETN] \
		[get_bd_pins axi_lsu_0/ctl_aresetn] \
		[get_bd_pins axi_lsu_0/data_aresetn]

	# MicroBlaze resets
	connect_bd_net -net mdm_0_Debug_SYS_Rst \
		[get_bd_pins mdm_0/Debug_SYS_Rst] \
		[get_bd_pins proc_sys_reset_eng/mb_debug_sys_rst]
	connect_bd_net -net d1_reset_1 \
		[get_bd_pins proc_sys_reset_eng/bus_struct_reset] \
		[get_bd_pins mcu_0/d1_reset]
	connect_bd_net -net d2_reset_1 \
		[get_bd_pins proc_sys_reset_eng/peripheral_reset] \
		[get_bd_pins mcu_0/d2_reset]
	connect_bd_net -net d3_reset_1 \
		[get_bd_pins proc_sys_reset_eng/mb_reset] \
		[get_bd_pins mcu_0/d3_reset]

	puts "########## create $nameHier end ##########"

	# Restore current instance
	current_bd_instance $oldCurInst
}
