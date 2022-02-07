setws xsct_ws
hsi open_hw_design hardware/final.xsa

# Generate device tree source from hardware description
hsi set_repo_path device-tree-xlnx

hsi create_sw_design devtree -os device_tree -proc psu_cortexa53_0

hsi generate_target -dir dts

# Add APM parameter that is not included in the dts source
set apm_0 [hsi get_cells apm_0]
if {$apm_0 ne ""} {
	set tdata_w [hsi get_property CONFIG.C_FIFO_AXIS_TDATA_WIDTH $apm_0]
	exec sed -i.bak "/apm_0/ a\\\t\t\txlnx,fifo-axis-tdata-width = <$tdata_w>;" dts/pl.dtsi
}

hsi close_hw_design [hsi current_hw_design]
