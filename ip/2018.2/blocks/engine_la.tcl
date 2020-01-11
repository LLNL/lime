
if {[info exists _engine_tcl]} {return}
set _engine_tcl 1

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

	# Create instance: axi_lsu_1, and set properties
	set axi_lsu_1 [create_bd_cell -type ip -vlnv llnl.gov:user:axi_lsu:2.3 axi_lsu_1]
	set_property -dict [list \
		CONFIG.C_AXI_MAP_ADDR_WIDTH $addr_width \
	] $axi_lsu_1

	# Create instance: axi_lsu_2, and set properties
	set axi_lsu_2 [create_bd_cell -type ip -vlnv llnl.gov:user:axi_lsu:2.3 axi_lsu_2]
	set_property -dict [list \
		CONFIG.C_AXI_MAP_ADDR_WIDTH $addr_width \
	] $axi_lsu_2

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
		CONFIG.M03_AXIS_BASETDEST {0x00000006} \
		CONFIG.M03_AXIS_HIGHTDEST {0x00000007} \
		CONFIG.M04_AXIS_BASETDEST {0x00000008} \
		CONFIG.M04_AXIS_HIGHTDEST {0x00000009} \
		CONFIG.M05_AXIS_BASETDEST {0x0000000A} \
		CONFIG.M05_AXIS_HIGHTDEST {0x0000000B} \
		CONFIG.M06_AXIS_BASETDEST {0x0000000C} \
		CONFIG.M06_AXIS_HIGHTDEST {0x0000000D} \
		CONFIG.NUM_MI {7} \
		CONFIG.NUM_SI {7} \
	] $axis_ctl_0

	# Create instance: axis_flow_0, and set properties
	set axis_flow_0 [create_bd_cell -type ip -vlnv llnl.gov:user:axis_flow:1.0 axis_flow_0]

	# Create instance: axis_hash_0, and set properties
	set axis_hash_0 [create_bd_cell -type ip -vlnv llnl.gov:user:axis_hash:1.0 axis_hash_0]

	# Create instance: axis_probe_0, and set properties
	set axis_probe_0 [create_bd_cell -type ip -vlnv llnl.gov:user:axis_probe:1.1 axis_probe_0]

	# Create instance: fifo_generator_0, and set properties
	# Currently, TDEST, TID, TKEEP, TSTRB, TLAST are not used by downstream module (axis_probe_0)
	set fifo_generator_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:fifo_generator:13.2 fifo_generator_0]
	set_property -dict [list \
		CONFIG.INTERFACE_TYPE {AXI_STREAM} \
		CONFIG.Input_Depth_axis {512} \
		CONFIG.TDATA_NUM_BYTES {8} \
		CONFIG.TDEST_WIDTH {4} \
		CONFIG.TID_WIDTH {4} \
		CONFIG.TKEEP_WIDTH {8} \
		CONFIG.TSTRB_WIDTH {8} \
		CONFIG.TUSER_WIDTH {0} \
	] $fifo_generator_0

	# Create instance: host_0
	create_hier_cell_host $hier_obj host_0

	# Create instance: proc_sys_reset_eng
	set proc_sys_reset_eng [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_eng]

	# Create interface connections

	# Host connection
	connect_bd_intf_net [get_bd_intf_pins S_AXI] \
		[get_bd_intf_pins host_0/S_AXI]

	# LA connections
	connect_bd_intf_net [get_bd_intf_pins axi_lsu_1/m_axis_dat] \
		[get_bd_intf_pins axis_flow_0/s_axis_dat1]
	connect_bd_intf_net [get_bd_intf_pins axis_hash_0/m_axis_dat] \
		[get_bd_intf_pins axi_lsu_1/s_axis_dat]
	connect_bd_intf_net [get_bd_intf_pins axi_lsu_2/m_axis_dat] \
		[get_bd_intf_pins axis_probe_0/s_axis_dat2]
	connect_bd_intf_net [get_bd_intf_pins axis_probe_0/m_axis_dat1] \
		[get_bd_intf_pins axi_lsu_2/s_axis_dat]
	connect_bd_intf_net [get_bd_intf_pins axis_flow_0/m_axis_dat1] \
		[get_bd_intf_pins axis_hash_0/s_axis_dat]
	connect_bd_intf_net [get_bd_intf_pins axis_flow_0/m_axis_dat2] \
		[get_bd_intf_pins fifo_generator_0/S_AXIS]
	connect_bd_intf_net [get_bd_intf_pins fifo_generator_0/M_AXIS] \
		[get_bd_intf_pins axis_probe_0/s_axis_dat1]

	# Control switch master ports
	connect_bd_intf_net [get_bd_intf_pins axis_ctl_0/M00_AXIS] \
		[get_bd_intf_pins host_0/S_AXIS]
	connect_bd_intf_net [get_bd_intf_pins axis_ctl_0/M03_AXIS] \
		[get_bd_intf_pins axi_lsu_1/s_axis_ctl]
	connect_bd_intf_net [get_bd_intf_pins axis_ctl_0/M04_AXIS] \
		[get_bd_intf_pins axis_hash_0/s_axis_ctl]
	connect_bd_intf_net [get_bd_intf_pins axis_ctl_0/M05_AXIS] \
		[get_bd_intf_pins axi_lsu_2/s_axis_ctl]
	connect_bd_intf_net [get_bd_intf_pins axis_ctl_0/M06_AXIS] \
		[get_bd_intf_pins axis_probe_0/s_axis_ctl]

	# Control switch slave ports
	connect_bd_intf_net [get_bd_intf_pins host_0/M_AXIS] \
		[get_bd_intf_pins axis_ctl_0/S00_AXIS]
	connect_bd_intf_net [get_bd_intf_pins axi_lsu_1/m_axis_ctl] \
		[get_bd_intf_pins axis_ctl_0/S03_AXIS]
	connect_bd_intf_net [get_bd_intf_pins axis_hash_0/m_axis_ctl] \
		[get_bd_intf_pins axis_ctl_0/S04_AXIS]
	connect_bd_intf_net [get_bd_intf_pins axi_lsu_2/m_axis_ctl] \
		[get_bd_intf_pins axis_ctl_0/S05_AXIS]
	connect_bd_intf_net [get_bd_intf_pins axis_probe_0/m_axis_ctl] \
		[get_bd_intf_pins axis_ctl_0/S06_AXIS]

	# AXI interconnect
	connect_bd_intf_net [get_bd_intf_pins axi_lsu_1/m_axi] \
		[get_bd_intf_pins axi_data_0/S00_AXI]
	connect_bd_intf_net [get_bd_intf_pins axi_lsu_2/m_axi] \
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
		[get_bd_pins fifo_generator_0/s_aclk] \
		[get_bd_pins axi_data_0/S00_ACLK] \
		[get_bd_pins axi_data_0/S01_ACLK] \
		[get_bd_pins axi_lsu_1/ctl_aclk] \
		[get_bd_pins axi_lsu_1/data_aclk] \
		[get_bd_pins axi_lsu_2/ctl_aclk] \
		[get_bd_pins axi_lsu_2/data_aclk] \
		[get_bd_pins axis_ctl_0/aclk] \
		[get_bd_pins axis_flow_0/ctl_aclk] \
		[get_bd_pins axis_flow_0/data_aclk] \
		[get_bd_pins axis_hash_0/ctl_aclk] \
		[get_bd_pins axis_hash_0/data_aclk] \
		[get_bd_pins axis_probe_0/ctl_aclk] \
		[get_bd_pins axis_probe_0/data_aclk]

	# AXI slave resets
	connect_bd_net -net S_D0_ARESETN_1 \
		[get_bd_pins S_D0_ARESETN] \
		[get_bd_pins proc_sys_reset_eng/ext_reset_in]
	connect_bd_net -net S_D1_ARESETN_1 \
		[get_bd_pins proc_sys_reset_eng/interconnect_aresetn] \
		[get_bd_pins host_0/d1_aresetn] \
		[get_bd_pins axis_ctl_0/aresetn]
	connect_bd_net -net S_D2_ARESETN_1 \
		[get_bd_pins proc_sys_reset_eng/peripheral_aresetn] \
		[get_bd_pins host_0/d2_aresetn] \
		[get_bd_pins fifo_generator_0/s_aresetn] \
		[get_bd_pins axi_data_0/S00_ARESETN] \
		[get_bd_pins axi_data_0/S01_ARESETN] \
		[get_bd_pins axi_lsu_1/ctl_aresetn] \
		[get_bd_pins axi_lsu_1/data_aresetn] \
		[get_bd_pins axi_lsu_2/ctl_aresetn] \
		[get_bd_pins axi_lsu_2/data_aresetn] \
		[get_bd_pins axis_flow_0/ctl_aresetn] \
		[get_bd_pins axis_flow_0/data_aresetn] \
		[get_bd_pins axis_hash_0/ctl_aresetn] \
		[get_bd_pins axis_hash_0/data_aresetn] \
		[get_bd_pins axis_probe_0/ctl_aresetn] \
		[get_bd_pins axis_probe_0/data_aresetn]

	puts "########## create $nameHier end ##########"

	# Restore current instance
	current_bd_instance $oldCurInst
}
