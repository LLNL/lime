setws sdk
openhw hw_platform_0
# Generate device tree source from hardware description
repo -set device-tree-xlnx
hsi create_sw_design devtree -os device_tree -proc psu_cortexa53_0
hsi generate_target -dir dts
# Add APM parameter not included in dts source
set apm_0 [hsi get_cells apm_0]
if {$apm_0 ne ""} {
	set tdata_w [hsi get_property CONFIG.C_FIFO_AXIS_TDATA_WIDTH $apm_0]
	exec sed -i.bak "/apm_0/ a\\\t\t\txlnx,fifo-axis-tdata-width = <$tdata_w>;" dts/pl.dtsi
}
closehw hw_platform_0
