# The TIMESTAMP field width is a constant defined in an APM module.
#   (See Time_Diff in axi_perf_mon_v5_0_nn_strm_fifo_wr_logic)
#   Original width is 16. The modified width is 30.
# The EXT_EVENT field width is a constant in several APM modules.
#   (See Ext_Event_Flags in axi_perf_mon_v5_0_nn_flags_gen)
#   Field width is the same (3) in both the original and modified source.
# The FLAGS field width is a constant in several APM modules.
#   (See Flag_Enable_Reg in axi_perf_mon_v5_0_nn_flags_gen)
#   Two new flags (MIDxx) were added to the modified source for a total of 9.
# The APM C_SLOT_n_AXI_AWLEN parameter is the field width minus 1.
# The APM C_SHOW_AXI_DATA parameter was added to the modified source.
# For documentation on hsi commands:
#   $ xsct(.bat) -interactive; % help hsi
#   UG1208: Xilinx Software Command-Line Tool
#   UG1138: Generating Basic Software Platforms

hsi open_hw_design [lindex $argv 0]

set apm_0 [hsi get_cells apm_0]
#puts [hsi report_property $apm_0]

# check configuration
if {[hsi get_property CONFIG.C_ENABLE_ADVANCED $apm_0] == 0} {
	puts " -- error: only APM advanced mode is supported."
	exit 1
}
if {[hsi get_property CONFIG.C_ENABLE_EVENT_LOG $apm_0] == 0} {
	puts " -- error: APM event log (trace output) not enabled."
	exit 1
}
if {[hsi get_property CONFIG.C_SHOW_AXI_IDS $apm_0] == 0} {
	puts " -- error: APM C_SHOW_AXI_IDS not enabled."
	exit 1
}
if {[hsi get_property CONFIG.C_SHOW_AXI_LEN $apm_0] == 0} {
	puts " -- error: APM C_SHOW_AXI_LEN not enabled."
	exit 1
}
# TODO: check that individual field widths add up to FIFO_AXIS_TDATA_WIDTH

# generate config header file
proc put_def {fid prop obj} {
	set val [hsi get_property CONFIG.C_${prop} $obj]
	puts $fid "#define $prop $val"
	return $val
}

set hfid [open "config.h" w]

puts $hfid "#ifndef CONFIG_H_"
puts $hfid "#define CONFIG_H_"
puts $hfid ""
puts $hfid "/* slave interface configuration */"
put_def $hfid S_AXI_ADDR_WIDTH $apm_0
put_def $hfid S_AXI_DATA_WIDTH $apm_0
put_def $hfid S_AXI_ID_WIDTH $apm_0
puts $hfid ""
puts $hfid "/* system configuration */"
put_def $hfid SHOW_AXI_DATA $apm_0
put_def $hfid SHOW_AXI_IDS  $apm_0
put_def $hfid SHOW_AXI_LEN  $apm_0
put_def $hfid FIFO_AXIS_TDATA_WIDTH $apm_0
set slots [put_def $hfid NUM_MONITOR_SLOTS $apm_0]
puts $hfid ""
puts $hfid "/* event bit-field widths */"
puts $hfid "#define LOGID 1"
puts $hfid "#define TIMESTAMP 30"
puts $hfid "#define LOOP 1"
puts $hfid "#define SW_PACKET 32"
puts $hfid ""
puts $hfid "/* slot bit-field widths */"
puts $hfid "typedef struct {"
puts $hfid "	unsigned EXT_EVENT;"
puts $hfid "	unsigned FLAGS;"
puts $hfid "	unsigned xxID;"
puts $hfid "	unsigned AxLEN;"
puts $hfid "	unsigned AxADDR;"
puts $hfid "	unsigned xDATA;"
puts $hfid "} sparam_t;"
puts $hfid ""
puts $hfid "extern sparam_t slot_param\[\];"
puts $hfid ""
puts $hfid "#endif /* CONFIG_H_ */"

close $hfid

# generate config c source file
proc slot_param {n obj} {
	set EXT_EVENT 3
	set FLAGS 9
	set xxID [hsi get_property CONFIG.C_SLOT_${n}_AXI_ID_WIDTH $obj]
	set AxLEN [expr [hsi get_property CONFIG.C_SLOT_${n}_AXI_AWLEN $obj] + 1]
	set AxADDR [hsi get_property CONFIG.C_SLOT_${n}_AXI_ADDR_WIDTH $obj]
	set xDATA [hsi get_property CONFIG.C_SLOT_${n}_AXI_DATA_WIDTH $obj]
	return "{$EXT_EVENT, $FLAGS, $xxID, $AxLEN, $AxADDR, $xDATA}"
}

set cfid [open "config.c" w]

puts $cfid "#include \"config.h\""
puts $cfid ""
puts $cfid "/* slot bit-field widths */"
puts $cfid "sparam_t slot_param\[\] = {"
for {set i 0} {$i < $slots} {incr i} {
	set sep [if {$i+1 < $slots} {lindex ,}]
	puts $cfid "\t[slot_param $i $apm_0]$sep"
}
puts $cfid "};"

close $cfid

hsi close_hw_design [hsi current_hw_design]
