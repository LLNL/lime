
if {[info exists _host_tcl]} {return}
set _host_tcl 1


# Hierarchical cell: host
proc create_hier_cell_host {parentCell nameHier} {

	puts "########## create $nameHier begin ##########"

	if {$parentCell eq "" || $nameHier eq ""} {
		catch {common::send_msg_id "BD_TCL-102" "ERROR" "create_hier_cell_host() - Empty argument(s)!"}
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
	create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS
	create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 M_AXIS

	# Create pins
	create_bd_pin -dir I -type clk aclk
	create_bd_pin -dir I -type rst -from 0 -to 0 d1_aresetn
	create_bd_pin -dir I -type rst -from 0 -to 0 d2_aresetn

	# Create instance: axi_fifo_mm_s_0, and set properties
	#set axi_fifo_mm_s_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_fifo_mm_s:4.1 axi_fifo_mm_s_0]
	set axi_fifo_mm_s_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_fifo_mm_s:4.2 axi_fifo_mm_s_0]
	set_property -dict [list \
		CONFIG.C_USE_RX_CUT_THROUGH {true} \
		CONFIG.C_USE_TX_CTRL {0} \
		CONFIG.C_USE_TX_CUT_THROUGH {1} \
	] $axi_fifo_mm_s_0

	# Create instance: axis_hdr_0, and set properties
	set axis_hdr_0 [create_bd_cell -type ip -vlnv llnl.gov:user:axis_hdr:1.2 axis_hdr_0]

	# Create interface connections
	connect_bd_intf_net [get_bd_intf_pins S_AXIS] \
		[get_bd_intf_pins axis_hdr_0/s_axis_sig]
	connect_bd_intf_net [get_bd_intf_pins axis_hdr_0/m_axis_sig] \
		[get_bd_intf_pins M_AXIS]
	connect_bd_intf_net [get_bd_intf_pins S_AXI] \
		[get_bd_intf_pins axi_fifo_mm_s_0/S_AXI]
	connect_bd_intf_net [get_bd_intf_pins axi_fifo_mm_s_0/AXI_STR_TXD] \
		[get_bd_intf_pins axis_hdr_0/s_axis_hdr]
	connect_bd_intf_net [get_bd_intf_pins axis_hdr_0/m_axis_hdr] \
		[get_bd_intf_pins axi_fifo_mm_s_0/AXI_STR_RXD]

	# Create port connections
	connect_bd_net [get_bd_pins aclk] \
		[get_bd_pins axi_fifo_mm_s_0/s_axi_aclk] \
		[get_bd_pins axis_hdr_0/h2s_aclk] \
		[get_bd_pins axis_hdr_0/s2h_aclk]
	connect_bd_net [get_bd_pins d1_aresetn] \
		[get_bd_pins axis_hdr_0/h2s_aresetn] \
		[get_bd_pins axis_hdr_0/s2h_aresetn]
	connect_bd_net [get_bd_pins d2_aresetn] \
		[get_bd_pins axi_fifo_mm_s_0/s_axi_aresetn]

	puts "########## create $nameHier end ##########"

	# Restore current instance
	current_bd_instance $oldCurInst
}
