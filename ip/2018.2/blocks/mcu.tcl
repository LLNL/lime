
if {[info exists _mcu_tcl]} {return}
set _mcu_tcl 1


# Hierarchical cell: lmb
proc create_hier_cell_lmb {parentCell nameHier} {

	puts "########## create $nameHier begin ##########"

	if {$parentCell eq "" || $nameHier eq ""} {
		catch {common::send_msg_id "BD_TCL-102" "ERROR" "create_hier_cell_lmb() - Empty argument(s)!"}
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
	create_bd_intf_pin -mode MirroredMaster -vlnv xilinx.com:interface:lmb_rtl:1.0 DLMB
	create_bd_intf_pin -mode MirroredMaster -vlnv xilinx.com:interface:lmb_rtl:1.0 ILMB

	# Create pins
	create_bd_pin -dir I -type clk LMB_CLK
	create_bd_pin -dir I -type rst LMB_RST

	# Create instance: dlmb_bram_if_cntlr, and set properties
	set dlmb_bram_if_cntlr [create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_bram_if_cntlr:4.0 dlmb_bram_if_cntlr]
	set_property -dict [list \
		CONFIG.C_ECC {0} \
	] $dlmb_bram_if_cntlr

	# Create instance: dlmb_v10, and set properties
	set dlmb_v10 [create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_v10:3.0 dlmb_v10]

	# Create instance: ilmb_bram_if_cntlr, and set properties
	set ilmb_bram_if_cntlr [create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_bram_if_cntlr:4.0 ilmb_bram_if_cntlr]
	set_property -dict [list \
		CONFIG.C_ECC {0} \
	] $ilmb_bram_if_cntlr

	# Create instance: ilmb_v10, and set properties
	set ilmb_v10 [create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_v10:3.0 ilmb_v10]

	# Create instance: lmb_bram, and set properties
	set lmb_bram [create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 lmb_bram]
	set_property -dict [list \
		CONFIG.EN_SAFETY_CKT {false} \
		CONFIG.Memory_Type {True_Dual_Port_RAM} \
		CONFIG.use_bram_block {BRAM_Controller} \
	] $lmb_bram

	# Create interface connections
	connect_bd_intf_net -intf_net DLMB_1 \
		[get_bd_intf_pins DLMB] \
		[get_bd_intf_pins dlmb_v10/LMB_M]
	connect_bd_intf_net -intf_net DLMB_BUS \
		[get_bd_intf_pins dlmb_bram_if_cntlr/SLMB] \
		[get_bd_intf_pins dlmb_v10/LMB_Sl_0]
	connect_bd_intf_net -intf_net DLMB_CNTLR \
		[get_bd_intf_pins dlmb_bram_if_cntlr/BRAM_PORT] \
		[get_bd_intf_pins lmb_bram/BRAM_PORTA]
	connect_bd_intf_net -intf_net ILMB_1 \
		[get_bd_intf_pins ILMB] \
		[get_bd_intf_pins ilmb_v10/LMB_M]
	connect_bd_intf_net -intf_net ILMB_BUS \
		[get_bd_intf_pins ilmb_bram_if_cntlr/SLMB] \
		[get_bd_intf_pins ilmb_v10/LMB_Sl_0]
	connect_bd_intf_net -intf_net ILMB_CNTLR \
		[get_bd_intf_pins ilmb_bram_if_cntlr/BRAM_PORT] \
		[get_bd_intf_pins lmb_bram/BRAM_PORTB]

	# Create port connections
	connect_bd_net [get_bd_pins LMB_CLK] \
		[get_bd_pins dlmb_bram_if_cntlr/LMB_CLK] \
		[get_bd_pins dlmb_v10/LMB_CLK] \
		[get_bd_pins ilmb_bram_if_cntlr/LMB_CLK] \
		[get_bd_pins ilmb_v10/LMB_CLK]
	connect_bd_net [get_bd_pins LMB_RST] \
		[get_bd_pins dlmb_bram_if_cntlr/LMB_Rst] \
		[get_bd_pins dlmb_v10/SYS_Rst] \
		[get_bd_pins ilmb_bram_if_cntlr/LMB_Rst] \
		[get_bd_pins ilmb_v10/SYS_Rst]

	puts "########## create $nameHier end ##########"

	# Restore current instance
	current_bd_instance $oldCurInst
}

# Hierarchical cell: mcu
proc create_hier_cell_mcu {parentCell nameHier} {

	variable script_folder

	puts "########## create $nameHier begin ##########"

	if {$parentCell eq "" || $nameHier eq ""} {
		catch {common::send_msg_id "BD_TCL-102" "ERROR" "create_hier_cell_mcu() - Empty argument(s)!"}
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
	create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:mbdebug_rtl:3.0 DEBUG
	create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M0_AXI
	create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 M0_AXIS
	create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S0_AXIS

	# Create pins
	create_bd_pin -dir I -type clk aclk
	create_bd_pin -dir I -type rst -from 0 -to 0 d1_aresetn
	create_bd_pin -dir I -type rst -from 0 -to 0 d1_reset
	create_bd_pin -dir I -type rst -from 0 -to 0 d2_aresetn
	create_bd_pin -dir I -type rst -from 0 -to 0 d2_reset
	create_bd_pin -dir I -type rst d3_reset

	# Create instance: axis_hdr_0, and set properties
	set axis_hdr_0 [create_bd_cell -type ip -vlnv llnl.gov:user:axis_hdr:1.2 axis_hdr_0]

	# Create instance: microblaze_0, and set properties
	set microblaze_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze:10.0 microblaze_0]
	set_property -dict [list \
		CONFIG.C_ADDR_TAG_BITS {0} \
		CONFIG.C_BASE_VECTORS {0xD0000000} \
		CONFIG.C_DCACHE_ADDR_TAG {17} \
		CONFIG.C_DCACHE_ALWAYS_USED {1} \
		CONFIG.C_DCACHE_BASEADDR {0x0000000000000000} \
		CONFIG.C_DCACHE_BYTE_SIZE {16384} \
		CONFIG.C_DCACHE_HIGHADDR {0x000000007FFFFFFF} \
		CONFIG.C_DCACHE_USE_WRITEBACK {1} \
		CONFIG.C_DCACHE_VICTIMS {4} \
		CONFIG.C_DEBUG_ENABLED {1} \
		CONFIG.C_D_AXI {0} \
		CONFIG.C_D_LMB {1} \
		CONFIG.C_I_LMB {1} \
		CONFIG.C_FAULT_TOLERANT {0} \
		CONFIG.C_FSL_LINKS {1} \
		CONFIG.C_USE_BARREL {1} \
		CONFIG.C_USE_DCACHE {1} \
		CONFIG.C_USE_DIV {1} \
		CONFIG.C_USE_HW_MUL {1} \
		CONFIG.C_USE_ICACHE {0} \
		CONFIG.C_USE_INTERRUPT {0} \
		CONFIG.C_USE_REORDER_INSTR {0} \
	] $microblaze_0
	# Used when CONFIG.C_USE_ICACHE is set to {1}
		# CONFIG.C_CACHE_BYTE_SIZE {16384} \
		# CONFIG.C_ICACHE_ALWAYS_USED {0} \
		# CONFIG.C_ICACHE_BASEADDR {0x0000000000000000} \
		# CONFIG.C_ICACHE_HIGHADDR {0x000000007FFFFFFF} \
		# CONFIG.C_ICACHE_STREAMS {0} \

	# Create instance: lmb_0
	create_hier_cell_lmb $hier_obj lmb_0

	# Create interface connections
	connect_bd_intf_net [get_bd_intf_pins DEBUG] \
		[get_bd_intf_pins microblaze_0/DEBUG]
	connect_bd_intf_net [get_bd_intf_pins S0_AXIS] \
		[get_bd_intf_pins axis_hdr_0/s_axis_sig]
	connect_bd_intf_net [get_bd_intf_pins axis_hdr_0/m_axis_sig] \
		[get_bd_intf_pins M0_AXIS]
	connect_bd_intf_net [get_bd_intf_pins axis_hdr_0/m_axis_hdr] \
		[get_bd_intf_pins microblaze_0/S0_AXIS]
	connect_bd_intf_net [get_bd_intf_pins microblaze_0/M0_AXIS] \
		[get_bd_intf_pins axis_hdr_0/s_axis_hdr]
	connect_bd_intf_net [get_bd_intf_pins microblaze_0/M_AXI_DC] \
		[get_bd_intf_pins M0_AXI]
	connect_bd_intf_net [get_bd_intf_pins microblaze_0/DLMB] \
		[get_bd_intf_pins lmb_0/DLMB]
	connect_bd_intf_net [get_bd_intf_pins microblaze_0/ILMB] \
		[get_bd_intf_pins lmb_0/ILMB]

	# Create port connections
	connect_bd_net [get_bd_pins aclk] \
		[get_bd_pins axis_hdr_0/h2s_aclk] \
		[get_bd_pins axis_hdr_0/s2h_aclk] \
		[get_bd_pins microblaze_0/Clk] \
		[get_bd_pins lmb_0/LMB_CLK]
	connect_bd_net [get_bd_pins d1_aresetn] \
		[get_bd_pins axis_hdr_0/h2s_aresetn] \
		[get_bd_pins axis_hdr_0/s2h_aresetn]
	connect_bd_net [get_bd_pins d1_reset] \
		[get_bd_pins lmb_0/LMB_RST]
	connect_bd_net [get_bd_pins d3_reset] \
		[get_bd_pins microblaze_0/Reset]

	puts "########## create $nameHier end ##########"

	# Restore current instance
	current_bd_instance $oldCurInst
}
