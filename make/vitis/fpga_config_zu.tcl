set PLAT_DIR [lindex $argv 0]
connect -url tcp:127.0.0.1:3121
#source /opt/XilinxVitis/Vitis/2020.2/scripts/vitis/util/zynqmp_utils.tcl
source /home/bhardwaj2/Xilinx2020_1/Vitis/2020.1/scripts/vitis/util/zynqmp_utils.tcl
targets -set -nocase -filter {name =~"APU*"}
rst -system
after 3000
#targets -set -filter {jtag_cable_name =~ "Digilent JTAG-SMT2NC 210308AE62D6" && level==0 && jtag_device_ctx=="jsn-JTAG-SMT2NC-210308AE62D6-24738093-0"}
fpga -file $PLAT_DIR/final.bit
targets -set -nocase -filter {name =~"APU*"}
loadhw -hw $PLAT_DIR/final.xsa -mem-ranges [list {0x80000000 0xbfffffff} {0x400000000 0x5ffffffff} {0x1000000000 0x7fffffffff}] -regs
configparams force-mem-access 1
#exec sed -i.bak -f $PLAT_DIR/../../../sar.sed $PLAT_DIR/psu_init.c
#exec sed -i.bak -f $PLAT_DIR/../../../sar.sed $PLAT_DIR/psu_init_gpl.c
#exec sed -i.bak -f $PLAT_DIR/../../../sar.sed $PLAT_DIR/psu_init.tcl
targets -set -nocase -filter {name =~"APU*"}
set mode [expr [mrd -value 0xFF5E0200] & 0xf]
targets -set -nocase -filter {name =~ "*A53*#0"}
rst -processor
dow $PLAT_DIR/../export/final/sw/final/boot/fsbl.elf
set bp_2_50_fsbl_bp [bpadd -addr &XFsbl_Exit]
con -block -timeout 60
bpremove $bp_2_50_fsbl_bp
configparams mdm-detect-bscan-mask 2
puts "disconnect"
puts [catch { disconnect };list]
puts [exit]
