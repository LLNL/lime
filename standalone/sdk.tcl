setws sdk

# hw_platform_0
createhw -name hw_platform_0 -hwspec [lindex $argv 0]

# A53 BSP
set pA53 [hsi get_cells *cortexa53_0 -filter {IP_TYPE==PROCESSOR}]
if {$pA53 ne ""} {
	# patch psu_init.*
	exec sed -i.bak -f sar.sed sdk/hw_platform_0/psu_init.c
	exec sed -i.bak -f sar.sed sdk/hw_platform_0/psu_init_gpl.c
	exec sed -i.bak -f sar.sed sdk/hw_platform_0/psu_init.tcl
	createbsp -name standalone_bsp_a53 -proc $pA53 -hwproject hw_platform_0 -arch 64
	bsp setlib xilffs
	# PARAMETER READ_ONLY = false
	# PARAMETER USE_MKFS = false
	updatemss -mss sdk/standalone_bsp_a53/system.mss
	platform generate
	# patch translation table
	exec cp -p translation_table_a53.S sdk/standalone_bsp_a53/$pA53/libsrc/standalone_v6_7/src/translation_table.S
}

# A9 BSP
set pA9 [hsi get_cells *cortexa9_0 -filter {IP_TYPE==PROCESSOR}]
if {$pA9 ne ""} {
	createbsp -name standalone_bsp_a9 -proc $pA9 -hwproject hw_platform_0
	setlib -bsp standalone_bsp_a9 -lib xilffs
	# PARAMETER READ_ONLY = false
	# PARAMETER USE_MKFS = false
	updatemss -mss sdk/standalone_bsp_a9/system.mss
	regenbsp -bsp standalone_bsp_a9
	# patch translation table
	exec cp -p translation_table_a9.S sdk/standalone_bsp_a9/$pA9/libsrc/standalone_v6_7/src/translation_table.S
}

# MB BSP
set pMB [hsi get_cells *microblaze_0 -filter {IP_TYPE==PROCESSOR}]
if {$pMB ne ""} {
	createbsp -name standalone_bsp_mb -proc $pMB -hwproject hw_platform_0
	updatemss -mss sdk/standalone_bsp_mb/system.mss
	regenbsp -bsp standalone_bsp_mb
}

# hsi report_property [hsi current_hw_design]
# hsi get_property BOARD [hsi current_hw_design]

# build & close
projects -build
closehw hw_platform_0
