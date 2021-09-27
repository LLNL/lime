setws vitis
platform create -name final -hw [lindex $argv 0] -no-boot-bsp
domain create -name standalone_psu_cortexa53_0 -os standalone -proc psu_cortexa53_0
domain active standalone_psu_cortexa53_0
exec cp translation_table_a53.S vitis/final/psu_cortexa53_0/standalone_psu_cortexa53_0/bsp/psu_cortexa53_0/libsrc/standalone_v7_2/src/translation_table.S 
bsp setlib -name xilffs -ver 4.3
bsp config use_chmod "true"
platform generate

domain create -name fsbl_domain -os standalone -proc psu_cortexa53_0
domain active fsbl_domain
exec ./cp_tt.sh
bsp setlib xilffs
bsp setlib xilsecure
bsp setlib xilpm
bsp config zynqmp_fsbl_bsp true


platform generate -domains standalone_psu_cortexa53_0,fsbl_domain

exec ./cp_tt.sh
domain create -name standalone_bsp_mb -os standalone -proc engine_0_mcu_0_microblaze_0 -arch 32-bit
platform generate -domains standalone_psu_cortexa53_0,fsbl_domain,standalone_bsp_mb

app create -name lime -platform final -template "Empty Application (C++)" -domain standalone_psu_cortexa53_0 -lang C++
app create -name fsbl -platform final -template "Zynq MP FSBL" -domain fsbl_domain -lang c
exec cp xfsbl_ddr_init.c vitis/fsbl/src/
app config -name fsbl build-config release
app config -name lime build-config release
app build -name lime
app build -name fsbl
exec cp vitis/fsbl/Release/fsbl.elf vitis/final/export/final/sw/final/boot/
