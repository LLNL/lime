
if {[info exists _delay_tcl]} {return}
set _delay_tcl 1

# Hierarchical cell: delay
proc create_hier_cell_delay {parentCell nameHier \
	addr_width data_width id_width protocol \
	map0_in map0_out map0_width \
	map1_in map1_out map1_width \
	mem_addr_width} {

        set axi_delay_ip axi_delayv

	puts "########## create $nameHier begin ##########"

	if {$parentCell eq "" || $nameHier eq ""} {
		catch {common::send_msg_id "BD_TCL-102" "ERROR" "create_hier_cell_delay() - Empty argument(s)!"}
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
	create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S0_AXI_LITE
	create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S1_AXI_LITE

	create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI
	create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M0_AXI
	create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M1_AXI

	# Create pins
	create_bd_pin -dir I -type clk AXI_LITE_ACLK
	create_bd_pin -dir I -type rst AXI_LITE_ARESETN

	create_bd_pin -dir I -type clk ACLK
	create_bd_pin -dir I -type rst ARESETN

	# Create instance: axi_shim_0, and set properties
	set axi_shim_0 [create_bd_cell -type ip -vlnv llnl.gov:user:axi_shim:1.4 axi_shim_0]
	set_property -dict [list \
		CONFIG.C_AXI_ADDR_WIDTH $addr_width \
		CONFIG.C_AXI_DATA_WIDTH $data_width \
		CONFIG.C_AXI_ID_WIDTH $id_width \
		CONFIG.C_AXI_PROTOCOL $protocol \
		CONFIG.C_MAP_IN $map0_in \
		CONFIG.C_MAP_OUT $map0_out \
		CONFIG.C_MAP_WIDTH $map0_width \
	] $axi_shim_0

	# Create instance: axi_shim_1, and set properties
	set axi_shim_1 [create_bd_cell -type ip -vlnv llnl.gov:user:axi_shim:1.4 axi_shim_1]
	set_property -dict [list \
		CONFIG.C_AXI_ADDR_WIDTH $addr_width \
		CONFIG.C_AXI_DATA_WIDTH $data_width \
		CONFIG.C_AXI_ID_WIDTH $id_width \
		CONFIG.C_AXI_PROTOCOL $protocol \
		CONFIG.C_MAP_IN $map1_in \
		CONFIG.C_MAP_OUT $map1_out \
		CONFIG.C_MAP_WIDTH $map1_width \
	] $axi_shim_1

	# Create instance: axi_interconnect_0, and set properties
	if {$id_width > 6} {
		set axi_interconnect_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_interconnect_0]
	} else {
		set axi_interconnect_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0]
	}
	set_property -dict [list \
		CONFIG.NUM_MI {2} \
		CONFIG.NUM_SI {1} \
	] $axi_interconnect_0

        if {$axi_delay_ip == "axi_delay"} {
		# Create instance: axi_delay_0, and set properties
		set axi_delay_0 [create_bd_cell -type ip -vlnv llnl.gov:user:axi_delay:1.2 axi_delay_0]
		set_property -dict [list \
			CONFIG.C_AXI_ADDR_WIDTH $addr_width \
			CONFIG.C_AXI_DATA_WIDTH $data_width \
			CONFIG.C_AXI_ID_WIDTH {6} \
			CONFIG.C_AXI_PROTOCOL $protocol \
			CONFIG.C_FIFO_DEPTH_B {32} \
			CONFIG.C_FIFO_DEPTH_R {512} \
			CONFIG.C_MEM_ADDR_WIDTH $mem_addr_width \
		] $axi_delay_0

		# Create instance: axi_delay_1, and set properties
		set axi_delay_1 [create_bd_cell -type ip -vlnv llnl.gov:user:axi_delay:1.2 axi_delay_1]
		set_property -dict [list \
			CONFIG.C_AXI_ADDR_WIDTH $addr_width \
			CONFIG.C_AXI_DATA_WIDTH $data_width \
			CONFIG.C_AXI_ID_WIDTH {6} \
			CONFIG.C_AXI_PROTOCOL $protocol \
			CONFIG.C_FIFO_DEPTH_B {32} \
			CONFIG.C_FIFO_DEPTH_R {512} \
			CONFIG.C_MEM_ADDR_WIDTH $mem_addr_width \
		] $axi_delay_1
        }

        if {$axi_delay_ip == "axi_delayv"} {
		# Create instance: axi_delay_0, and set properties
		set axi_delay_0 [create_bd_cell -type ip -vlnv llnl.gov:user:axi_delayv:1.0 axi_delay_0]
		set_property -dict [list \
			CONFIG.C_AXI_ADDR_WIDTH $addr_width \
			CONFIG.C_AXI_DATA_WIDTH $data_width \
			CONFIG.C_AXI_ID_WIDTH {6} \
			CONFIG.C_AXI_PROTOCOL $protocol \
			CONFIG.C_MEM_ADDR_WIDTH $mem_addr_width \
                        CONFIG.C_PRIORITY_QUEUE_WIDTH {16} \
                        CONFIG.DELAY_WIDTH {24} \
                        CONFIG.CAM_DEPTH {8} \
                        CONFIG.CAM_WIDTH {16} \
                        CONFIG.NUM_MINI_BUFS {64} \
		] $axi_delay_0

		# Create instance: axi_delay_1, and set properties
		set axi_delay_1 [create_bd_cell -type ip -vlnv llnl.gov:user:axi_delayv:1.0 axi_delay_1]
		set_property -dict [list \
			CONFIG.C_AXI_ADDR_WIDTH $addr_width \
			CONFIG.C_AXI_DATA_WIDTH $data_width \
			CONFIG.C_AXI_ID_WIDTH {6} \
			CONFIG.C_AXI_PROTOCOL $protocol \
			CONFIG.C_MEM_ADDR_WIDTH $mem_addr_width \
                        CONFIG.C_PRIORITY_QUEUE_WIDTH {16} \
                        CONFIG.DELAY_WIDTH {24} \
                        CONFIG.CAM_DEPTH {8} \
                        CONFIG.CAM_WIDTH {16} \
                        CONFIG.NUM_MINI_BUFS {64} \
		] $axi_delay_1
        }

	# Create interface connections
	connect_bd_intf_net [get_bd_intf_pins S0_AXI_LITE] \
		[get_bd_intf_pins axi_delay_0/s_axi_lite]
	connect_bd_intf_net [get_bd_intf_pins S1_AXI_LITE] \
		[get_bd_intf_pins axi_delay_1/s_axi_lite]

	connect_bd_intf_net [get_bd_intf_pins S_AXI] \
		[get_bd_intf_pins axi_shim_0/s_axi]
	connect_bd_intf_net [get_bd_intf_pins axi_shim_0/m_axi] \
		[get_bd_intf_pins axi_shim_1/s_axi]
	connect_bd_intf_net [get_bd_intf_pins axi_shim_1/m_axi] \
		[get_bd_intf_pins axi_interconnect_0/S00_AXI]
	connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M00_AXI] \
		[get_bd_intf_pins axi_delay_0/s_axi]
	connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M01_AXI] \
		[get_bd_intf_pins axi_delay_1/s_axi]
	connect_bd_intf_net [get_bd_intf_pins axi_delay_0/m_axi] \
		[get_bd_intf_pins M0_AXI]
	connect_bd_intf_net [get_bd_intf_pins axi_delay_1/m_axi] \
		[get_bd_intf_pins M1_AXI]

	# Create port connections
	connect_bd_net [get_bd_pins AXI_LITE_ACLK] \
		[get_bd_pins axi_delay_0/s_axi_lite_aclk] \
		[get_bd_pins axi_delay_1/s_axi_lite_aclk]
	connect_bd_net [get_bd_pins AXI_LITE_ARESETN] \
		[get_bd_pins axi_delay_0/s_axi_lite_aresetn] \
		[get_bd_pins axi_delay_1/s_axi_lite_aresetn]

	connect_bd_net [get_bd_pins ACLK] \
		[get_bd_pins axi_shim_0/m_axi_aclk] \
		[get_bd_pins axi_shim_0/s_axi_aclk] \
		[get_bd_pins axi_shim_1/m_axi_aclk] \
		[get_bd_pins axi_shim_1/s_axi_aclk] \
		[get_bd_pins axi_delay_0/m_axi_aclk] \
		[get_bd_pins axi_delay_0/s_axi_aclk] \
		[get_bd_pins axi_delay_1/m_axi_aclk] \
		[get_bd_pins axi_delay_1/s_axi_aclk]
	if {$id_width > 6} {
		connect_bd_net [get_bd_pins ACLK] \
			[get_bd_pins axi_interconnect_0/aclk]
	} else {
		connect_bd_net [get_bd_pins ACLK] \
			[get_bd_pins axi_interconnect_0/ACLK] \
			[get_bd_pins axi_interconnect_0/S00_ACLK] \
			[get_bd_pins axi_interconnect_0/M00_ACLK] \
			[get_bd_pins axi_interconnect_0/M01_ACLK]
	}

	connect_bd_net [get_bd_pins ARESETN] \
		[get_bd_pins axi_shim_0/m_axi_aresetn] \
		[get_bd_pins axi_shim_0/s_axi_aresetn] \
		[get_bd_pins axi_shim_1/m_axi_aresetn] \
		[get_bd_pins axi_shim_1/s_axi_aresetn] \
		[get_bd_pins axi_delay_0/m_axi_aresetn] \
		[get_bd_pins axi_delay_0/s_axi_aresetn] \
		[get_bd_pins axi_delay_1/m_axi_aresetn] \
		[get_bd_pins axi_delay_1/s_axi_aresetn]
	if {$id_width > 6} {
		connect_bd_net [get_bd_pins ARESETN] \
			[get_bd_pins axi_interconnect_0/aresetn]
	} else {
		connect_bd_net [get_bd_pins ARESETN] \
			[get_bd_pins axi_interconnect_0/ARESETN] \
			[get_bd_pins axi_interconnect_0/S00_ARESETN] \
			[get_bd_pins axi_interconnect_0/M00_ARESETN] \
			[get_bd_pins axi_interconnect_0/M01_ARESETN]
	}

	puts "########## create $nameHier end ##########"

	# Restore current instance
	current_bd_instance $oldCurInst
}
