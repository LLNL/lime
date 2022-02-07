set PDIR ../standalone
setws sdk
# hw_platform_0
platform create -name hw_platform_0 -hw [lindex $argv 0]
# patch psu_init.*
exec sed -i.bak -f $PDIR/sar.sed sdk/hw_platform_0/hw/psu_init.c
exec sed -i.bak -f $PDIR/sar.sed sdk/hw_platform_0/hw/psu_init_gpl.c
exec sed -i.bak -f $PDIR/sar.sed sdk/hw_platform_0/hw/psu_init.tcl
# FSBL & BSP
app create -name fsbl -template {Zynq MP FSBL} -proc psu_cortexa53_0 -platform hw_platform_0 -os standalone -lang C -arch 64
app config -name fsbl build-config release
# patch translation table
exec cp -p $PDIR/translation_table_a53.S sdk/fsbl_bsp/psu_cortexa53_0/libsrc/standalone_v6_7/src/translation_table.S
exec cp -p $PDIR/translation_table_a53.S sdk/fsbl/src/xfsbl_translation_table.S
# PMUFW
app create -name pmufw -template {ZynqMP PMU Firmware} -proc psu_pmu_0 -platform hw_platform_0 -os standalone -lang C
app config -name pmufw build-config release
# build & close
projects -build
closehw hw_platform_0
