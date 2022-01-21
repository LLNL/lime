
delete_bd_objs [get_bd_intf_nets apm_0_M_AXIS]

set_property -dict [list CONFIG.C_S_AXIS_TDATA_WIDTH {128}] [get_bd_cells trace_0/axi_tcd_0]

set_property -dict [list CONFIG.PSU__ENET3__FIFO__ENABLE {1}] [get_bd_cells zynq_ps_0]

# Create compressor, connect to APM
create_bd_cell -type ip -vlnv llnl.gov:user:compress:1.0 compress_0
connect_bd_net [get_bd_pins zynq_ps_0/pl_clk1] [get_bd_pins compress_0/ap_clk]
connect_bd_net [get_bd_pins rst_pl_clk1/interconnect_aresetn] [get_bd_pins compress_0/ap_rst_n]
connect_bd_intf_net [get_bd_intf_pins apm_0/M_AXIS] [get_bd_intf_pins compress_0/in_V_V]

# Create broadcaster, connect to compressor and trace capture
create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_0
connect_bd_net [get_bd_pins zynq_ps_0/pl_clk1] [get_bd_pins axis_broadcaster_0/aclk]
connect_bd_net [get_bd_pins rst_pl_clk1/interconnect_aresetn] [get_bd_pins axis_broadcaster_0/aresetn]
connect_bd_intf_net [get_bd_intf_pins compress_0/out_V_V] [get_bd_intf_pins axis_broadcaster_0/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins axis_broadcaster_0/M00_AXIS] [get_bd_intf_pins trace_0/S_AXIS]

# TODO: fix to use library component instead of single file
import_files -norecurse "[file dirname [info script]]/../overflow_detector.v"
update_compile_order -fileset sources_1

# Create overflow detector, connect to broadcaster
create_bd_cell -type module -reference overflow_detector overflow_detector_0
connect_bd_net [get_bd_pins zynq_ps_0/pl_clk1] [get_bd_pins overflow_detector_0/aclk]
connect_bd_net [get_bd_pins rst_pl_clk1/interconnect_aresetn] [get_bd_pins overflow_detector_0/aresetn]
connect_bd_intf_net [get_bd_intf_pins axis_broadcaster_0/M01_AXIS] [get_bd_intf_pins overflow_detector_0/input_axis]

# Create stream FIFO
create_bd_cell -type ip -vlnv xilinx.com:ip:fifo_generator:13.2 fifo_generator_0
set_property -dict [list \
	CONFIG.INTERFACE_TYPE {AXI_STREAM} \
	CONFIG.Reset_Type {Asynchronous_Reset} \
	CONFIG.Clock_Type_AXI {Independent_Clock} \
	CONFIG.TDATA_NUM_BYTES {16} \
	CONFIG.TUSER_WIDTH {0} \
	CONFIG.TSTRB_WIDTH {16} \
	CONFIG.TKEEP_WIDTH {16} \
	CONFIG.FIFO_Implementation_axis {Independent_Clocks_Block_RAM} \
	CONFIG.Input_Depth_axis {16384} \
	CONFIG.Full_Threshold_Assert_Value_axis {16383} \
	CONFIG.Empty_Threshold_Assert_Value_axis {16381} \
] [get_bd_cells fifo_generator_0]

# Connect stream FIFO to overflow detector
connect_bd_net [get_bd_pins zynq_ps_0/pl_clk1] [get_bd_pins fifo_generator_0/s_aclk]
connect_bd_net [get_bd_pins zynq_ps_0/fmio_gem3_fifo_tx_clk_to_pl_bufg] [get_bd_pins fifo_generator_0/m_aclk]
connect_bd_net [get_bd_pins rst_pl_clk1/interconnect_aresetn] [get_bd_pins fifo_generator_0/s_aresetn]
connect_bd_intf_net [get_bd_intf_pins overflow_detector_0/output_axis] [get_bd_intf_pins fifo_generator_0/S_AXIS]

# Create reset for Ethernet FIFO
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0
connect_bd_net [get_bd_pins zynq_ps_0/fmio_gem3_fifo_tx_clk_to_pl_bufg] [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
connect_bd_net [get_bd_pins zynq_ps_0/pl_resetn1] [get_bd_pins proc_sys_reset_0/ext_reset_in]

# Create Ethernet FIFO, connect to stream FIFO
create_bd_cell -type ip -vlnv llnl.gov:user:eth_fifo_interface:1.0 eth_fifo_interface_0
connect_bd_net [get_bd_pins proc_sys_reset_0/interconnect_aresetn] [get_bd_pins eth_fifo_interface_0/ap_rst_n]
connect_bd_net [get_bd_pins zynq_ps_0/fmio_gem3_fifo_tx_clk_to_pl_bufg] [get_bd_pins eth_fifo_interface_0/ap_clk]
connect_bd_net [get_bd_pins zynq_ps_0/emio_enet3_tx_r_status] [get_bd_pins eth_fifo_interface_0/tx_r_status_V]
connect_bd_net [get_bd_pins eth_fifo_interface_0/dma_tx_end_tog_V] [get_bd_pins zynq_ps_0/emio_enet3_dma_tx_end_tog]
connect_bd_net [get_bd_pins eth_fifo_interface_0/tx_r_fixed_lat_V] [get_bd_pins zynq_ps_0/emio_enet3_tx_r_fixed_lat]
connect_bd_net [get_bd_pins eth_fifo_interface_0/tx_r_rd_V] [get_bd_pins zynq_ps_0/emio_enet3_tx_r_rd]
connect_bd_net [get_bd_pins eth_fifo_interface_0/dma_tx_status_tog_V] [get_bd_pins zynq_ps_0/emio_enet3_dma_tx_status_tog]
connect_bd_net [get_bd_pins eth_fifo_interface_0/tx_r_control_V] [get_bd_pins zynq_ps_0/emio_enet3_tx_r_control]
connect_bd_net [get_bd_pins eth_fifo_interface_0/tx_r_data_V] [get_bd_pins zynq_ps_0/emio_enet3_tx_r_data]
connect_bd_net [get_bd_pins eth_fifo_interface_0/tx_r_data_rdy_V] [get_bd_pins zynq_ps_0/emio_enet3_tx_r_data_rdy]
connect_bd_net [get_bd_pins eth_fifo_interface_0/tx_r_eop_V] [get_bd_pins zynq_ps_0/emio_enet3_tx_r_eop]
connect_bd_net [get_bd_pins eth_fifo_interface_0/tx_r_err_V] [get_bd_pins zynq_ps_0/emio_enet3_tx_r_err]
connect_bd_net [get_bd_pins eth_fifo_interface_0/tx_r_flushed_V] [get_bd_pins zynq_ps_0/emio_enet3_tx_r_flushed]
connect_bd_net [get_bd_pins eth_fifo_interface_0/tx_r_sop_V] [get_bd_pins zynq_ps_0/emio_enet3_tx_r_sop]
connect_bd_net [get_bd_pins eth_fifo_interface_0/tx_r_underflow_V] [get_bd_pins zynq_ps_0/emio_enet3_tx_r_underflow]
connect_bd_net [get_bd_pins eth_fifo_interface_0/tx_r_valid_V] [get_bd_pins zynq_ps_0/emio_enet3_tx_r_valid]

connect_bd_intf_net [get_bd_intf_pins fifo_generator_0/M_AXIS] [get_bd_intf_pins eth_fifo_interface_0/data_in_V_V]
