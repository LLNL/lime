setws vitis

platform create -name {final}\
-hw [lindex $argv 0]\
-arch {64-bit} -fsbl-target {psu_cortexa53_0} -out {vitis}

platform write
domain create -name {standalone_psu_cortexa53_0} -display-name {standalone_psu_cortexa53_0} -os {standalone} -proc {psu_cortexa53_0} -runtime {cpp} -arch {64-bit} -support-app {empty_application}
platform generate -domains 
platform active {final}
domain active {standalone_psu_cortexa53_0}
exec cp translation_table_a53.S vitis/final/psu_cortexa53_0/standalone_psu_cortexa53_0/bsp/psu_cortexa53_0/libsrc/standalone_v7_3/src/translation_table.S 
bsp setlib -name xilffs -ver 4.4
bsp config use_chmod "true"
app create -name lime -domain standalone_psu_cortexa53_0 -template "Empty Application (C++)" -lang C++

domain create -name {fsbl_domain} -os {standalone} -proc {psu_cortexa53_0}
domain active {fsbl_domain}
exec ./cp_tt.sh
bsp setlib xilffs
bsp setlib xilsecure
bsp setlib xilpm
bsp config zynqmp_fsbl_bsp true


platform generate
exec ./cp_tt.sh
domain create -name {standalone_bsp_mb} -os {standalone} -proc {engine_0_mcu_0_microblaze_0} -arch {32-bit} -display-name {standalone_bsp_mb} -desc {} -runtime {cpp}
platform generate -domains 
platform write
domain -report -json
platform generate

app create -name fsbl -template {Zynq MP FSBL} -platform final -domain fsbl_domain
exec cp xfsbl_ddr_init.c vitis/fsbl/src/
app config -name fsbl build-config release

app config -name lime build-config release
app build -name lime
app build -name fsbl

exec cp vitis/fsbl/Release/fsbl.elf vitis/final/export/final/sw/final/boot/

