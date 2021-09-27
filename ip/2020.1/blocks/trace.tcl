
if {[info exists _trace_tcl]} {return}
set _trace_tcl 1


# Hierarchical cell: trace
proc create_hier_cell_trace {parentCell nameHier tdata_width addr_width data_width ddr_ver} {

	puts "########## create $nameHier begin ##########"

	if {$parentCell eq "" || $nameHier eq ""} {
		catch {common::send_msg_id "BD_TCL-102" "ERROR" "create_hier_cell_trace() - Empty argument(s)!"}
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
	create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_LITE
	create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS

	create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 sysclk
	if {$ddr_ver eq "DDR3"} {
		create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 ddr_sdram
	} else {
		create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 ddr_sdram
	}

	# Create pins
	create_bd_pin -dir I -type clk AXI_LITE_ACLK
	create_bd_pin -dir I -type rst AXI_LITE_ARESETN
	create_bd_pin -dir I -type clk AXIS_ACLK
	create_bd_pin -dir I -type rst AXIS_ARESETN

	create_bd_pin -dir O calib_complete
	create_bd_pin -dir I -type rst reset

	# Create instance: axi_tcd_0, and set properties
	set axi_tcd_0 [create_bd_cell -type ip -vlnv llnl.gov:user:axi_tcd:1.1 axi_tcd_0]
	set_property -dict [list \
		CONFIG.C_MEM_ADDR_WIDTH $addr_width \
		CONFIG.C_M_AXI_ADDR_WIDTH $addr_width \
		CONFIG.C_M_AXI_DATA_WIDTH $data_width \
		CONFIG.C_S_AXIS_TDATA_WIDTH $tdata_width \
	] $axi_tcd_0

	# Create instance: ddr_0, and set properties
	if {$ddr_ver eq "DDR3"} {
		set ddr_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:mig_7series:4.1 ddr_0]
		set_property -dict [list \
			CONFIG.BOARD_MIG_PARAM {ddr3_sdram} \
			CONFIG.RESET_BOARD_INTERFACE {reset} \
		] $ddr_0
		set S_AXI S_AXI
		set SYS_CLK SYS_CLK
		set DDRX DDR3
		set ui_clk ui_clk
		set ui_clk_sync_rst ui_clk_sync_rst
		set aresetn aresetn
		set sys_rst sys_rst
		set init_calib_complete init_calib_complete
	} else {
		set ddr_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4:2.2 ddr_0]
		set_property CONFIG.C0.DDR4_AxiIDWidth {1} $ddr_0
		set S_AXI C0_DDR4_S_AXI
		set SYS_CLK C0_SYS_CLK
		set DDRX C0_DDR4
		set ui_clk c0_ddr4_ui_clk
		set ui_clk_sync_rst c0_ddr4_ui_clk_sync_rst
		set aresetn c0_ddr4_aresetn
		set sys_rst sys_rst
		set init_calib_complete c0_init_calib_complete
	}

	# Create instance: proc_sys_reset_ddr, and set properties
	# TODO: Is proc_sys_reset_ddr really needed?
	set proc_sys_reset_ddr [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_ddr]

	# Create interface connections
	connect_bd_intf_net [get_bd_intf_pins S_AXI_LITE] \
		[get_bd_intf_pins axi_tcd_0/s_axi]
	connect_bd_intf_net [get_bd_intf_pins S_AXIS] \
		[get_bd_intf_pins axi_tcd_0/s_axis]
	connect_bd_intf_net [get_bd_intf_pins axi_tcd_0/m_axi] \
		[get_bd_intf_pins ddr_0/$S_AXI]

	connect_bd_intf_net [get_bd_intf_pins sysclk] \
		[get_bd_intf_pins ddr_0/$SYS_CLK]
	connect_bd_intf_net [get_bd_intf_pins ddr_0/$DDRX] \
		[get_bd_intf_pins ddr_sdram]

	# Create port connections
	connect_bd_net [get_bd_pins AXI_LITE_ACLK] \
		[get_bd_pins axi_tcd_0/s_axi_aclk]
	connect_bd_net [get_bd_pins AXI_LITE_ARESETN] \
		[get_bd_pins axi_tcd_0/s_axi_aresetn]
	connect_bd_net [get_bd_pins AXIS_ACLK] \
		[get_bd_pins axi_tcd_0/s_axis_aclk]
	connect_bd_net [get_bd_pins AXIS_ARESETN] \
		[get_bd_pins axi_tcd_0/s_axis_aresetn]

	connect_bd_net -net M_AXI_ACLK_1 \
		[get_bd_pins ddr_0/$ui_clk] \
		[get_bd_pins axi_tcd_0/m_axi_aclk] \
		[get_bd_pins proc_sys_reset_ddr/slowest_sync_clk]
	connect_bd_net -net ddr4_sync_rst \
		[get_bd_pins ddr_0/$ui_clk_sync_rst] \
		[get_bd_pins proc_sys_reset_ddr/ext_reset_in]
	connect_bd_net -net M_AXI_ARESETN_1 \
		[get_bd_pins proc_sys_reset_ddr/peripheral_aresetn] \
		[get_bd_pins axi_tcd_0/m_axi_aresetn] \
		[get_bd_pins ddr_0/$aresetn]

	connect_bd_net [get_bd_pins reset] \
		[get_bd_pins ddr_0/$sys_rst]
	connect_bd_net [get_bd_pins ddr_0/$init_calib_complete] \
		[get_bd_pins calib_complete]

	puts "########## create $nameHier end ##########"

	# Restore current instance
	current_bd_instance $oldCurInst
}
