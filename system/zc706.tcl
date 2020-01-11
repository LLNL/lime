#*******************************************************************************
#
# This file contains Vivado Tcl commands for re-creating the project.
# To re-create the project, source this file in the Vivado Tcl Shell.
#
#*******************************************************************************

set ENABLE_ENGINE 1
set ENGINE_SOURCE engine_dre_la.tcl
set ENABLE_APM 1
set ENABLE_APM_DATA 0
set ENABLE_TRACE 1
set ENABLE_COMP 0

if {!$ENABLE_APM} {set ENABLE_TRACE 0; set ENABLE_APM_DATA 0}
if {!$ENABLE_TRACE} {set ENABLE_COMP 0}

# Set the root directory for source file relative paths
variable lime_dir
set lime_dir "../.."
if {[info exists ::user_lime_dir]} {
	set lime_dir $::user_lime_dir
}

# Set the project name
variable proj_name
set proj_name "proj"
if {[info exists ::user_project_name]} {
	set proj_name $::user_project_name
}

# Set main design name
variable design_name
set design_name "system"
if {[info exists ::user_design_name]} {
	set design_name $::user_design_name
}

variable script_file
set script_file [file tail [info script]]

variable script_folder
set script_folder [file dirname [file normalize [info script]]]

variable current_vivado_version
set current_vivado_version [version \-short]

variable ip_dir
set ip_dir "$lime_dir/ip/$current_vivado_version"

# Help information for this script
proc help {} {
	variable lime_dir
	variable proj_name
	variable script_file
	puts "\nDescription:"
	puts "Recreate a Vivado project from this script."
	puts "Syntax:"
	puts "$script_file"
	puts "$script_file -tclargs \[--lime_dir <path>\]"
	puts "$script_file -tclargs \[--project_name <name>\]"
	puts "$script_file -tclargs \[--design_name <name>\]"
	puts "$script_file -tclargs \[--help\]\n"
	puts "Usage:"
	puts "Name                      Description"
	puts "-------------------------------------------------------------------------"
	puts "\[--lime_dir <path>\]     Determine source file paths wrt this path."
	puts "                        Default path is \"$lime_dir\".\n"
	puts "\[--project_name <name>\] Create project with the specified name."
	puts "                        Default name is \"$proj_name\".\n"
	puts "\[--design_name <name>\]  Create design with the specified name."
	puts "                        Default name is \"$design_name\".\n"
	puts "\[--help\]                Print help information for this script"
	puts "-------------------------------------------------------------------------\n"
	exit 0
}

if {$::argc > 0} {
	for {set i 0} {$i < $::argc} {incr i} {
		set option [string trim [lindex $::argv $i]]
		switch -regexp -- $option {
			"--lime_dir"   {incr i; set lime_dir [lindex $::argv $i]}
			"--project_name" {incr i; set proj_name [lindex $::argv $i]}
			"--help"         {help}
			default {
			if {[regexp {^-} $option]} {
				puts "ERROR: Unknown option '$option' specified, please type '$script_file -tclargs --help' for usage info.\n"
				return 1
			}
			}
		}
	}
}

# Create project
# BOARD: part
create_project ${proj_name} ./ -part xc7z045ffg900-2
set cproj [current_project]

# Set project properties
# BOARD: board_part
set_property board_part xilinx.com:zc706:part0:1.0 $cproj
set_property default_lib xil_defaultlib $cproj
set_property xpm_libraries "XPM_CDC XPM_MEMORY" $cproj
set_property ip_repo_paths  "$ip_dir $lime_dir/ip/hls" $cproj
update_ip_catalog -rebuild

# Set the directory path for the new project
set proj_dir [get_property directory $cproj]

# Suppress warning
# set_msg_config -id {[IP_Flow nn-nnnn]} -suppress

proc write_mig_prj {mig_prj} {
	file mkdir [file dirname "$mig_prj"]
	set mig_prj_file [open $mig_prj  w+]

	puts $mig_prj_file {<?xml version='1.0' encoding='UTF-8'?>}
	puts $mig_prj_file {<Project NoOfControllers="1" >}
	puts $mig_prj_file {    <ModuleName>system_mig_7series_0_0</ModuleName>}
	puts $mig_prj_file {    <dci_inouts_inputs>1</dci_inouts_inputs>}
	puts $mig_prj_file {    <dci_inputs>1</dci_inputs>}
	puts $mig_prj_file {    <Debug_En>OFF</Debug_En>}
	puts $mig_prj_file {    <DataDepth_En>1024</DataDepth_En>}
	puts $mig_prj_file {    <LowPower_En>ON</LowPower_En>}
	puts $mig_prj_file {    <XADC_En>Enabled</XADC_En>}
	puts $mig_prj_file {    <TargetFPGA>xc7z045-ffg900/-2</TargetFPGA>}
	puts $mig_prj_file {    <Version>2.0</Version>}
	puts $mig_prj_file {    <SystemClock>Differential</SystemClock>}
	puts $mig_prj_file {    <ReferenceClock>Use System Clock</ReferenceClock>}
	puts $mig_prj_file {    <SysResetPolarity>ACTIVE HIGH</SysResetPolarity>}
	puts $mig_prj_file {    <BankSelectionFlag>FALSE</BankSelectionFlag>}
	puts $mig_prj_file {    <InternalVref>0</InternalVref>}
	puts $mig_prj_file {    <dci_hr_inouts_inputs>50 Ohms</dci_hr_inouts_inputs>}
	puts $mig_prj_file {    <dci_cascade>1</dci_cascade>}
	puts $mig_prj_file {    <Controller number="0" >}
	puts $mig_prj_file {        <MemoryDevice>DDR3_SDRAM/SODIMMs/MT8JTF12864HZ-1G6</MemoryDevice>}
	puts $mig_prj_file {        <TimePeriod>2500</TimePeriod>}
	puts $mig_prj_file {        <VccAuxIO>1.8V</VccAuxIO>}
	puts $mig_prj_file {        <PHYRatio>2:1</PHYRatio>}
	puts $mig_prj_file {        <InputClkFreq>200</InputClkFreq>}
	puts $mig_prj_file {        <UIExtraClocks>0</UIExtraClocks>}
	puts $mig_prj_file {        <MMCMClkOut0> 1.000</MMCMClkOut0>}
	puts $mig_prj_file {        <MMCMClkOut1>1</MMCMClkOut1>}
	puts $mig_prj_file {        <MMCMClkOut2>1</MMCMClkOut2>}
	puts $mig_prj_file {        <MMCMClkOut3>1</MMCMClkOut3>}
	puts $mig_prj_file {        <MMCMClkOut4>1</MMCMClkOut4>}
	puts $mig_prj_file {        <DataWidth>64</DataWidth>}
	puts $mig_prj_file {        <DeepMemory>1</DeepMemory>}
	puts $mig_prj_file {        <DataMask>1</DataMask>}
	puts $mig_prj_file {        <ECC>Disabled</ECC>}
	puts $mig_prj_file {        <Ordering>Normal</Ordering>}
	puts $mig_prj_file {        <CustomPart>FALSE</CustomPart>}
	puts $mig_prj_file {        <NewPartName></NewPartName>}
	puts $mig_prj_file {        <RowAddress>14</RowAddress>}
	puts $mig_prj_file {        <ColAddress>10</ColAddress>}
	puts $mig_prj_file {        <BankAddress>3</BankAddress>}
	puts $mig_prj_file {        <MemoryVoltage>1.5V</MemoryVoltage>}
	puts $mig_prj_file {        <C0_MEM_SIZE>1073741824</C0_MEM_SIZE>}
	puts $mig_prj_file {        <UserMemoryAddressMap>BANK_ROW_COLUMN</UserMemoryAddressMap>}
	puts $mig_prj_file {        <PinSelection>}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="E10" SLEW="" name="ddr3_addr[0]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="D6" SLEW="" name="ddr3_addr[10]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="B7" SLEW="" name="ddr3_addr[11]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="H12" SLEW="" name="ddr3_addr[12]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="A10" SLEW="" name="ddr3_addr[13]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="B9" SLEW="" name="ddr3_addr[1]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="E11" SLEW="" name="ddr3_addr[2]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="A9" SLEW="" name="ddr3_addr[3]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="D11" SLEW="" name="ddr3_addr[4]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="B6" SLEW="" name="ddr3_addr[5]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="F9" SLEW="" name="ddr3_addr[6]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="E8" SLEW="" name="ddr3_addr[7]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="B10" SLEW="" name="ddr3_addr[8]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="J8" SLEW="" name="ddr3_addr[9]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="F8" SLEW="" name="ddr3_ba[0]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="H7" SLEW="" name="ddr3_ba[1]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="A7" SLEW="" name="ddr3_ba[2]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="E7" SLEW="" name="ddr3_cas_n" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="DIFF_SSTL15" PADName="F10" SLEW="" name="ddr3_ck_n[0]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="DIFF_SSTL15" PADName="G10" SLEW="" name="ddr3_ck_p[0]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="D10" SLEW="" name="ddr3_cke[0]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="J11" SLEW="" name="ddr3_cs_n[0]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="J3" SLEW="" name="ddr3_dm[0]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="F2" SLEW="" name="ddr3_dm[1]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="E1" SLEW="" name="ddr3_dm[2]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="C2" SLEW="" name="ddr3_dm[3]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="L12" SLEW="" name="ddr3_dm[4]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="G14" SLEW="" name="ddr3_dm[5]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="C16" SLEW="" name="ddr3_dm[6]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="C11" SLEW="" name="ddr3_dm[7]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="L1" SLEW="" name="ddr3_dq[0]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="H6" SLEW="" name="ddr3_dq[10]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="H3" SLEW="" name="ddr3_dq[11]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="G1" SLEW="" name="ddr3_dq[12]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="H2" SLEW="" name="ddr3_dq[13]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="G5" SLEW="" name="ddr3_dq[14]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="G4" SLEW="" name="ddr3_dq[15]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="E2" SLEW="" name="ddr3_dq[16]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="E3" SLEW="" name="ddr3_dq[17]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="D4" SLEW="" name="ddr3_dq[18]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="E5" SLEW="" name="ddr3_dq[19]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="L2" SLEW="" name="ddr3_dq[1]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="F4" SLEW="" name="ddr3_dq[20]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="F3" SLEW="" name="ddr3_dq[21]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="D1" SLEW="" name="ddr3_dq[22]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="D3" SLEW="" name="ddr3_dq[23]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="A2" SLEW="" name="ddr3_dq[24]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="B2" SLEW="" name="ddr3_dq[25]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="B4" SLEW="" name="ddr3_dq[26]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="B5" SLEW="" name="ddr3_dq[27]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="A3" SLEW="" name="ddr3_dq[28]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="B1" SLEW="" name="ddr3_dq[29]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="K5" SLEW="" name="ddr3_dq[2]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="C1" SLEW="" name="ddr3_dq[30]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="C4" SLEW="" name="ddr3_dq[31]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="K10" SLEW="" name="ddr3_dq[32]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="L9" SLEW="" name="ddr3_dq[33]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="K12" SLEW="" name="ddr3_dq[34]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="J9" SLEW="" name="ddr3_dq[35]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="K11" SLEW="" name="ddr3_dq[36]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="L10" SLEW="" name="ddr3_dq[37]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="J10" SLEW="" name="ddr3_dq[38]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="L7" SLEW="" name="ddr3_dq[39]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="J4" SLEW="" name="ddr3_dq[3]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="F14" SLEW="" name="ddr3_dq[40]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="F15" SLEW="" name="ddr3_dq[41]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="F13" SLEW="" name="ddr3_dq[42]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="G16" SLEW="" name="ddr3_dq[43]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="G15" SLEW="" name="ddr3_dq[44]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="E12" SLEW="" name="ddr3_dq[45]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="D13" SLEW="" name="ddr3_dq[46]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="E13" SLEW="" name="ddr3_dq[47]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="D15" SLEW="" name="ddr3_dq[48]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="E15" SLEW="" name="ddr3_dq[49]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="K1" SLEW="" name="ddr3_dq[4]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="D16" SLEW="" name="ddr3_dq[50]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="E16" SLEW="" name="ddr3_dq[51]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="C17" SLEW="" name="ddr3_dq[52]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="B16" SLEW="" name="ddr3_dq[53]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="D14" SLEW="" name="ddr3_dq[54]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="B17" SLEW="" name="ddr3_dq[55]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="B12" SLEW="" name="ddr3_dq[56]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="C12" SLEW="" name="ddr3_dq[57]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="A12" SLEW="" name="ddr3_dq[58]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="A14" SLEW="" name="ddr3_dq[59]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="L3" SLEW="" name="ddr3_dq[5]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="A13" SLEW="" name="ddr3_dq[60]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="B11" SLEW="" name="ddr3_dq[61]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="C14" SLEW="" name="ddr3_dq[62]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="B14" SLEW="" name="ddr3_dq[63]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="J5" SLEW="" name="ddr3_dq[6]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="K6" SLEW="" name="ddr3_dq[7]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="G6" SLEW="" name="ddr3_dq[8]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15_T_DCI" PADName="H4" SLEW="" name="ddr3_dq[9]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="K2" SLEW="" name="ddr3_dqs_n[0]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="H1" SLEW="" name="ddr3_dqs_n[1]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="D5" SLEW="" name="ddr3_dqs_n[2]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="A4" SLEW="" name="ddr3_dqs_n[3]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="K8" SLEW="" name="ddr3_dqs_n[4]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="F12" SLEW="" name="ddr3_dqs_n[5]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="E17" SLEW="" name="ddr3_dqs_n[6]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="A15" SLEW="" name="ddr3_dqs_n[7]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="K3" SLEW="" name="ddr3_dqs_p[0]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="J1" SLEW="" name="ddr3_dqs_p[1]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="E6" SLEW="" name="ddr3_dqs_p[2]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="A5" SLEW="" name="ddr3_dqs_p[3]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="L8" SLEW="" name="ddr3_dqs_p[4]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="G12" SLEW="" name="ddr3_dqs_p[5]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="F17" SLEW="" name="ddr3_dqs_p[6]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="DIFF_SSTL15_T_DCI" PADName="B15" SLEW="" name="ddr3_dqs_p[7]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="G7" SLEW="" name="ddr3_odt[0]" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="H11" SLEW="" name="ddr3_ras_n" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="LVCMOS15" PADName="G17" SLEW="" name="ddr3_reset_n" IN_TERM="" />}
	puts $mig_prj_file {            <Pin VCCAUX_IO="NORMAL" IOSTANDARD="SSTL15" PADName="F7" SLEW="" name="ddr3_we_n" IN_TERM="" />}
	puts $mig_prj_file {        </PinSelection>}
	puts $mig_prj_file {        <System_Clock>}
	puts $mig_prj_file {            <Pin PADName="H9/G9(CC_P/N)" Bank="34" name="sys_clk_p/n" />}
	puts $mig_prj_file {        </System_Clock>}
	puts $mig_prj_file {        <System_Control>}
	puts $mig_prj_file {            <Pin PADName="No connect" Bank="Select Bank" name="sys_rst" />}
	puts $mig_prj_file {            <Pin PADName="No connect" Bank="Select Bank" name="init_calib_complete" />}
	puts $mig_prj_file {            <Pin PADName="No connect" Bank="Select Bank" name="tg_compare_error" />}
	puts $mig_prj_file {        </System_Control>}
	puts $mig_prj_file {        <TimingParameters>}
	puts $mig_prj_file {            <Parameters twtr="7.5" trrd="6" trefi="7.8" tfaw="30" trtp="7.5" tcke="5" trfc="110" trp="13.125" tras="35" trcd="13.125" />}
	puts $mig_prj_file {        </TimingParameters>}
	puts $mig_prj_file {        <mrBurstLength name="Burst Length" >8 - Fixed</mrBurstLength>}
	puts $mig_prj_file {        <mrBurstType name="Read Burst Type and Length" >Sequential</mrBurstType>}
	puts $mig_prj_file {        <mrCasLatency name="CAS Latency" >6</mrCasLatency>}
	puts $mig_prj_file {        <mrMode name="Mode" >Normal</mrMode>}
	puts $mig_prj_file {        <mrDllReset name="DLL Reset" >No</mrDllReset>}
	puts $mig_prj_file {        <mrPdMode name="DLL control for precharge PD" >Slow Exit</mrPdMode>}
	puts $mig_prj_file {        <emrDllEnable name="DLL Enable" >Enable</emrDllEnable>}
	puts $mig_prj_file {        <emrOutputDriveStrength name="Output Driver Impedance Control" >RZQ/7</emrOutputDriveStrength>}
	puts $mig_prj_file {        <emrMirrorSelection name="Address Mirroring" >Disable</emrMirrorSelection>}
	puts $mig_prj_file {        <emrCSSelection name="Controller Chip Select Pin" >Enable</emrCSSelection>}
	puts $mig_prj_file {        <emrRTT name="RTT (nominal) - On Die Termination (ODT)" >RZQ/6</emrRTT>}
	puts $mig_prj_file {        <emrPosted name="Additive Latency (AL)" >0</emrPosted>}
	puts $mig_prj_file {        <emrOCD name="Write Leveling Enable" >Disabled</emrOCD>}
	puts $mig_prj_file {        <emrDQS name="TDQS enable" >Enabled</emrDQS>}
	puts $mig_prj_file {        <emrRDQS name="Qoff" >Output Buffer Enabled</emrRDQS>}
	puts $mig_prj_file {        <mr2PartialArraySelfRefresh name="Partial-Array Self Refresh" >Full Array</mr2PartialArraySelfRefresh>}
	puts $mig_prj_file {        <mr2CasWriteLatency name="CAS write latency" >5</mr2CasWriteLatency>}
	puts $mig_prj_file {        <mr2AutoSelfRefresh name="Auto Self Refresh" >Enabled</mr2AutoSelfRefresh>}
	puts $mig_prj_file {        <mr2SelfRefreshTempRange name="High Temparature Self Refresh Rate" >Normal</mr2SelfRefreshTempRange>}
	puts $mig_prj_file {        <mr2RTTWR name="RTT_WR - Dynamic On Die Termination (ODT)" >Dynamic ODT off</mr2RTTWR>}
	puts $mig_prj_file {        <PortInterface>AXI</PortInterface>}
	puts $mig_prj_file {        <AXIParameters>}
	puts $mig_prj_file {            <C0_C_RD_WR_ARB_ALGORITHM>RD_PRI_REG</C0_C_RD_WR_ARB_ALGORITHM>}
	puts $mig_prj_file {            <C0_S_AXI_ADDR_WIDTH>30</C0_S_AXI_ADDR_WIDTH>}
	puts $mig_prj_file {            <C0_S_AXI_DATA_WIDTH>256</C0_S_AXI_DATA_WIDTH>}
	puts $mig_prj_file {            <C0_S_AXI_ID_WIDTH>2</C0_S_AXI_ID_WIDTH>}
	puts $mig_prj_file {            <C0_S_AXI_SUPPORTS_NARROW_BURST>1</C0_S_AXI_SUPPORTS_NARROW_BURST>}
	puts $mig_prj_file {        </AXIParameters>}
	puts $mig_prj_file {    </Controller>}
	puts $mig_prj_file {</Project>}

	close $mig_prj_file
}
# End of write_mig_prj()

# Proc to create main BD
proc cr_bd_main {parentCell} {
	variable ENABLE_ENGINE
	variable ENGINE_SOURCE
	variable ENABLE_APM
	variable ENABLE_APM_DATA
	variable ENABLE_TRACE
	variable ENABLE_COMP

	variable design_name
	variable ip_dir

	create_bd_design $design_name

	puts "########## create $design_name begin ##########"

	if {$parentCell eq ""} {
		set parentCell [get_bd_cells /]
	}

	# Get object for parentCell
	set parentObj [get_bd_cells $parentCell]
	if {$parentObj eq ""} {
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

	# Set parent object as current
	current_bd_instance $parentObj

	##################################################################
	# Main Block Design - begin
	##################################################################

	# BOARD: memory, shim, and trace parameters

	# PS memory size
	set ps_mem_sz {1G}

	# shim base address: 0x4000_0000
	# main memory range: up to 1G
	# scratch pad memory range: 1M
	# actual base address: 0x8000_0000
	set map0_in {010000000000}
	set map0_out {100000000000}
	set map0_width {12}
	set map1_in {01}
	set map1_out {01}
	set map1_width {2}
	set mem_addr_width {30}

	set trc_tdata_width [expr $ENABLE_APM_DATA ? 512 : 256]
	# PL memory size = 2^width
	set trc_addr_width {30}
	set trc_data_width {256}
	set trc_ddr_ver "DDR3"

	########## main ##########

	# Create instance: zynq_ps_0
	# BOARD: Zynq configuration
	set zynq_ps_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 zynq_ps_0]
	set_property CONFIG.preset {ZC706} $zynq_ps_0
	# apply_bd_automation \
		# -rule xilinx.com:bd_rule:??? \
		# -config {apply_board_preset "1"} \
		# $zynq_ps_0
	# Needs to be applied after setting board presets
	set_property -dict [list \
		CONFIG.PCW_APU_CLK_RATIO_ENABLE {4:2:1} \
		CONFIG.PCW_EN_CLK0_PORT {1} \
		CONFIG.PCW_EN_CLK1_PORT {1} \
		CONFIG.PCW_EN_RST0_PORT {1} \
		CONFIG.PCW_EN_RST1_PORT {1} \
		CONFIG.PCW_FPGA_FCLK0_ENABLE {1} \
		CONFIG.PCW_FPGA_FCLK1_ENABLE {1} \
		CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {166} \
		CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ {200} \
		CONFIG.PCW_USE_M_AXI_GP0 {1} \
		CONFIG.PCW_USE_M_AXI_GP1 {1} \
		CONFIG.PCW_M_AXI_GP0_ENABLE_STATIC_REMAP {1} \
		CONFIG.PCW_M_AXI_GP0_ID_WIDTH {12} \
		CONFIG.PCW_M_AXI_GP0_SUPPORT_NARROW_BURST {0} \
		CONFIG.PCW_M_AXI_GP0_THREAD_ID_WIDTH {6} \
		CONFIG.PCW_USE_S_AXI_HP0 {1} \
		CONFIG.PCW_USE_S_AXI_HP1 {1} \
		CONFIG.PCW_S_AXI_HP0_DATA_WIDTH {32} \
		CONFIG.PCW_S_AXI_HP0_ID_WIDTH {6} \
		CONFIG.PCW_S_AXI_HP1_DATA_WIDTH {32} \
		CONFIG.PCW_S_AXI_HP1_ID_WIDTH {6} \
		CONFIG.PCW_TTC0_PERIPHERAL_ENABLE {0} \
		CONFIG.PCW_USB0_PERIPHERAL_ENABLE {0} \
	] $zynq_ps_0

	create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_pl_clk0

	create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_pl_clk1

	# Create instance: delay_0
	set cpu_addr_width [get_property CONFIG.ADDR_WIDTH [get_bd_intf_pins zynq_ps_0/M_AXI_GP0]]
	set cpu_data_width [get_property CONFIG.DATA_WIDTH [get_bd_intf_pins zynq_ps_0/M_AXI_GP0]]
	set cpu_id_width [get_property CONFIG.ID_WIDTH [get_bd_intf_pins zynq_ps_0/M_AXI_GP0]]
	source "$ip_dir/blocks/delay.tcl"
	create_hier_cell_delay [current_bd_instance .] delay_0 \
		$cpu_addr_width $cpu_data_width $cpu_id_width 1 \
		$map0_in $map0_out $map0_width \
		$map1_in $map1_out $map1_width \
		$mem_addr_width
	# FIXME: MAX_BURST_LENGTH should be propagating, read only on s_axi
	# set_property CONFIG.MAX_BURST_LENGTH {16} [get_bd_intf_pins delay_0/axi_shim_0/m_axi]
	# set_property CONFIG.MAX_BURST_LENGTH {16} [get_bd_intf_pins delay_0/axi_shim_1/m_axi]

	# Connect Zynq clocks/resets to processor system reset
	connect_bd_net [get_bd_pins zynq_ps_0/FCLK_CLK0] [get_bd_pins rst_pl_clk0/slowest_sync_clk]
	connect_bd_net [get_bd_pins zynq_ps_0/FCLK_RESET0_N] [get_bd_pins rst_pl_clk0/ext_reset_in]
	connect_bd_net [get_bd_pins zynq_ps_0/FCLK_CLK1] [get_bd_pins rst_pl_clk1/slowest_sync_clk]
	connect_bd_net [get_bd_pins zynq_ps_0/FCLK_RESET1_N] [get_bd_pins rst_pl_clk1/ext_reset_in]

	# Connect Zynq PS AXI clocks
	connect_bd_net [get_bd_pins zynq_ps_0/FCLK_CLK0] [get_bd_pins zynq_ps_0/M_AXI_GP1_ACLK]
	connect_bd_net [get_bd_pins zynq_ps_0/FCLK_CLK1] [get_bd_pins zynq_ps_0/M_AXI_GP0_ACLK]
	connect_bd_net [get_bd_pins zynq_ps_0/FCLK_CLK1] [get_bd_pins zynq_ps_0/S_AXI_HP0_ACLK]
	connect_bd_net [get_bd_pins zynq_ps_0/FCLK_CLK1] [get_bd_pins zynq_ps_0/S_AXI_HP1_ACLK]

	# Connect delay_0 in loopback
	connect_bd_net [get_bd_pins zynq_ps_0/FCLK_CLK1] [get_bd_pins delay_0/ACLK]
	connect_bd_net [get_bd_pins rst_pl_clk1/interconnect_aresetn] [get_bd_pins delay_0/ARESETN]
	connect_bd_intf_net [get_bd_intf_pins zynq_ps_0/M_AXI_GP0] [get_bd_intf_pins delay_0/S_AXI]
	connect_bd_intf_net [get_bd_intf_pins delay_0/M0_AXI] [get_bd_intf_pins zynq_ps_0/S_AXI_HP0]
	connect_bd_intf_net [get_bd_intf_pins delay_0/M1_AXI] [get_bd_intf_pins zynq_ps_0/S_AXI_HP1]
	apply_bd_automation \
		-rule xilinx.com:bd_rule:axi4 \
		-config {Master "/zynq_ps_0/M_AXI_GP1" Clk "Auto"} \
		[get_bd_intf_pins delay_0/S0_AXI_LITE]
	apply_bd_automation \
		-rule xilinx.com:bd_rule:axi4 \
		-config {Master "/zynq_ps_0/M_AXI_GP1" Clk "Auto"} \
		[get_bd_intf_pins delay_0/S1_AXI_LITE]

	########## engine ##########
	if {$ENABLE_ENGINE} {

	# Configure Zynq S_AXI_HP2 & S_AXI_HP3 ports
	# BOARD: Zynq configuration
	set_property -dict [list \
		CONFIG.PCW_USE_S_AXI_HP2 {1} \
		CONFIG.PCW_USE_S_AXI_HP3 {1} \
		CONFIG.PCW_S_AXI_HP2_DATA_WIDTH {64} \
		CONFIG.PCW_S_AXI_HP3_DATA_WIDTH {64} \
	] $zynq_ps_0

	# TODO: programmatically set or propagate width params based on master
	set eng_addr_width $cpu_addr_width
	set eng_data_width [get_property CONFIG.DATA_WIDTH [get_bd_intf_pins zynq_ps_0/S_AXI_HP2]]
	set eng_id_width {3}

	# Connect Zynq PS AXI clocks
	connect_bd_net [get_bd_pins zynq_ps_0/FCLK_CLK1] [get_bd_pins zynq_ps_0/S_AXI_HP2_ACLK]
	connect_bd_net [get_bd_pins zynq_ps_0/FCLK_CLK1] [get_bd_pins zynq_ps_0/S_AXI_HP3_ACLK]

	# Create instance: engine_0
	source "$ip_dir/blocks/$ENGINE_SOURCE"
	create_hier_cell_engine [current_bd_instance .] engine_0 \
		$eng_addr_width $eng_data_width

	# Create instance: delay_1
	source "$ip_dir/blocks/delay.tcl"
	create_hier_cell_delay [current_bd_instance .] delay_1 \
		$eng_addr_width $eng_data_width $eng_id_width 1 \
		$map0_in $map0_out $map0_width \
		$map1_in $map1_out $map1_width \
		$mem_addr_width
	# FIXME: MAX_BURST_LENGTH should be propagating, read only on s_axi
	# set_property CONFIG.MAX_BURST_LENGTH {16} [get_bd_intf_pins delay_1/axi_shim_0/m_axi]
	# set_property CONFIG.MAX_BURST_LENGTH {16} [get_bd_intf_pins delay_1/axi_shim_1/m_axi]

	# Connect delay_1
	connect_bd_net [get_bd_pins zynq_ps_0/FCLK_CLK1] [get_bd_pins delay_1/ACLK]
	connect_bd_net [get_bd_pins rst_pl_clk1/interconnect_aresetn] [get_bd_pins delay_1/ARESETN]
	connect_bd_intf_net [get_bd_intf_pins delay_1/M0_AXI] [get_bd_intf_pins zynq_ps_0/S_AXI_HP2]
	connect_bd_intf_net [get_bd_intf_pins delay_1/M1_AXI] [get_bd_intf_pins zynq_ps_0/S_AXI_HP3]
	apply_bd_automation \
		-rule xilinx.com:bd_rule:axi4 \
		-config {Master "/zynq_ps_0/M_AXI_GP1" Clk "Auto"} \
		[get_bd_intf_pins delay_1/S0_AXI_LITE]
	apply_bd_automation \
		-rule xilinx.com:bd_rule:axi4 \
		-config {Master "/zynq_ps_0/M_AXI_GP1" Clk "Auto"} \
		[get_bd_intf_pins delay_1/S1_AXI_LITE]

	# Connect engine_0
	connect_bd_net [get_bd_pins zynq_ps_0/FCLK_CLK1] [get_bd_pins engine_0/ACLK]
	connect_bd_net [get_bd_pins rst_pl_clk1/interconnect_aresetn] [get_bd_pins engine_0/ARESETN]
	connect_bd_net [get_bd_pins zynq_ps_0/FCLK_CLK1] [get_bd_pins engine_0/M_ACLK]
	connect_bd_net [get_bd_pins rst_pl_clk1/peripheral_aresetn] [get_bd_pins engine_0/M_ARESETN]
	connect_bd_intf_net [get_bd_intf_pins engine_0/M_AXI] [get_bd_intf_pins delay_1/S_AXI]
	connect_bd_net [get_bd_pins zynq_ps_0/FCLK_RESET0_N] [get_bd_pins engine_0/S_D0_ARESETN]
	apply_bd_automation \
		-rule xilinx.com:bd_rule:axi4 \
		-config {Master "/zynq_ps_0/M_AXI_GP1" Clk "Auto"} \
		[get_bd_intf_pins engine_0/S_AXI]

	}
	########## APM ##########
	if {$ENABLE_APM} {

	# Create instance: apm_0
	set apm_0 [create_bd_cell -type ip -vlnv xilinx.com:user:axi_perf_mon:5.0 apm_0]
	set_property -dict [list \
		CONFIG.C_ENABLE_EVENT_LOG $ENABLE_TRACE \
		CONFIG.C_GLOBAL_COUNT_WIDTH {64} \
		CONFIG.C_NUM_MONITOR_SLOTS [expr $ENABLE_ENGINE ? 2 : 1] \
		CONFIG.C_NUM_OF_COUNTERS {8} \
		CONFIG.C_SHOW_AXI_IDS {1} \
		CONFIG.C_SHOW_AXI_LEN {1} \
		CONFIG.C_SLOT_0_AXI_PROTOCOL {AXI3} \
		CONFIG.C_SLOT_1_AXI_PROTOCOL {AXI3} \
	] $apm_0
	if {$ENABLE_APM_DATA} {set_property CONFIG.C_SHOW_AXI_DATA {1} $apm_0}

	# Connect apm_0
	connect_bd_intf_net [get_bd_intf_pins zynq_ps_0/M_AXI_GP0] [get_bd_intf_pins apm_0/SLOT_0_AXI]

	connect_bd_net [get_bd_pins zynq_ps_0/FCLK_CLK1] [get_bd_pins apm_0/core_aclk]
	connect_bd_net [get_bd_pins rst_pl_clk1/peripheral_aresetn] [get_bd_pins apm_0/core_aresetn]
	connect_bd_net [get_bd_pins zynq_ps_0/FCLK_CLK1] [get_bd_pins apm_0/slot_0_axi_aclk]
	connect_bd_net [get_bd_pins rst_pl_clk1/peripheral_aresetn] [get_bd_pins apm_0/slot_0_axi_aresetn]

	if {$ENABLE_ENGINE} {
	connect_bd_intf_net [get_bd_intf_pins engine_0/M_AXI] [get_bd_intf_pins apm_0/SLOT_1_AXI]
	connect_bd_net [get_bd_pins zynq_ps_0/FCLK_CLK1] [get_bd_pins apm_0/slot_1_axi_aclk]
	connect_bd_net [get_bd_pins rst_pl_clk1/peripheral_aresetn] [get_bd_pins apm_0/slot_1_axi_aresetn]
	}

	if {$ENABLE_TRACE} {
	connect_bd_net [get_bd_pins zynq_ps_0/FCLK_CLK1] [get_bd_pins apm_0/m_axis_aclk]
	connect_bd_net [get_bd_pins rst_pl_clk1/peripheral_aresetn] [get_bd_pins apm_0/m_axis_aresetn]
	}

	apply_bd_automation \
		-rule xilinx.com:bd_rule:axi4 \
		-config {Master "/zynq_ps_0/M_AXI_GP1" Clk "Auto"} \
		[get_bd_intf_pins apm_0/S_AXI]

	}
	########## trace ##########
	if {$ENABLE_TRACE} {

	# Create external ports
	# BOARD: sysclk
	# TODO: set property from board file?
	set sysclk [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 sysclk]
	set_property CONFIG.FREQ_HZ {100000000} $sysclk
	set reset [create_bd_port -dir I -type rst reset]
	set_property CONFIG.POLARITY {ACTIVE_HIGH} $reset
	set trace_sdram [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 trace_sdram]
	set calib_complete [create_bd_port -dir O calib_complete]

	# Create instance: trace_0
	source "$ip_dir/blocks/trace.tcl"
	create_hier_cell_trace [current_bd_instance .] trace_0 \
		$trc_tdata_width $trc_addr_width $trc_data_width $trc_ddr_ver

	# Connect trace_0
	# BOARD: sysclk
	connect_bd_intf_net $sysclk [get_bd_intf_pins trace_0/sysclk]
	connect_bd_net $reset [get_bd_pins trace_0/reset]
	connect_bd_intf_net [get_bd_intf_pins trace_0/ddr_sdram] $trace_sdram
	connect_bd_net [get_bd_pins trace_0/calib_complete] $calib_complete
	connect_bd_net [get_bd_pins zynq_ps_0/FCLK_CLK1] [get_bd_pins trace_0/AXIS_ACLK]
	connect_bd_net [get_bd_pins rst_pl_clk1/peripheral_aresetn] [get_bd_pins trace_0/AXIS_ARESETN]
	connect_bd_intf_net [get_bd_intf_pins apm_0/M_AXIS] [get_bd_intf_pins trace_0/S_AXIS]
	apply_bd_automation \
		-rule xilinx.com:bd_rule:axi4 \
		-config {Master "/zynq_ps_0/M_AXI_GP1" Clk "Auto"} \
		[get_bd_intf_pins trace_0/S_AXI_LITE]

	# BOARD: mig configuration
	set mig_dir [get_property IP_DIR [get_ips [get_property CONFIG.Component_Name [get_bd_cells trace_0/ddr_0]]]]
	# puts "mig_dir: $mig_dir"
	# TODO: instead of creating mig_a.prj all from constant text,
	# copy board.prj to mig_a.prj and replace only:
	# <C0_S_AXI_ADDR_WIDTH>30</C0_S_AXI_ADDR_WIDTH>
	# <C0_S_AXI_DATA_WIDTH>256</C0_S_AXI_DATA_WIDTH>
	write_mig_prj "$mig_dir/mig_a.prj"
	set_property CONFIG.XML_INPUT_FILE {mig_a.prj} [get_bd_cells trace_0/ddr_0]

	if {$ENABLE_COMP} {source "$ip_dir/blocks/competh.tcl"}

	}
	########## address begin ##########
	# Example: list address spaces and segments
	# join [get_bd_addr_spaces] \n
	# join [get_bd_addr_segs -of_objects [get_bd_addr_spaces]] \n

	assign_bd_address -offset 0x40000000 -range $ps_mem_sz [get_bd_addr_segs {delay_0/axi_shim_0/s_axi/mem0}]
	assign_bd_address -offset 0x00000000 -range 4G [get_bd_addr_segs {delay_0/axi_shim_1/s_axi/mem0}]
	assign_bd_address -offset 0x80000000 -range 1M [get_bd_addr_segs {delay_0/axi_delay_0/s_axi/mem0}]
	assign_bd_address -offset 0x40000000 -range 1G [get_bd_addr_segs {delay_0/axi_delay_1/s_axi/mem0}]
	assign_bd_address [get_bd_addr_segs {zynq_ps_0/SAXIGP2/HP0_DDR_HIGH}]
	assign_bd_address [get_bd_addr_segs {zynq_ps_0/SAXIGP2/HP0_DDR_LOW}]
	assign_bd_address [get_bd_addr_segs {zynq_ps_0/SAXIGP3/HP1_DDR_HIGH}]
	assign_bd_address [get_bd_addr_segs {zynq_ps_0/SAXIGP3/HP1_DDR_LOW}]

	if {$ENABLE_ENGINE} {
	assign_bd_address -offset 0x40000000 -range $ps_mem_sz [get_bd_addr_segs {delay_1/axi_shim_0/s_axi/mem0}]
	assign_bd_address -offset 0x00000000 -range 4G [get_bd_addr_segs {delay_1/axi_shim_1/s_axi/mem0}]
	assign_bd_address -offset 0x80000000 -range 1M [get_bd_addr_segs {delay_1/axi_delay_0/s_axi/mem0}]
	assign_bd_address -offset 0x40000000 -range 1G [get_bd_addr_segs {delay_1/axi_delay_1/s_axi/mem0}]
	assign_bd_address [get_bd_addr_segs {zynq_ps_0/SAXIGP4/HP2_DDR_HIGH}]
	assign_bd_address [get_bd_addr_segs {zynq_ps_0/SAXIGP4/HP2_DDR_LOW}]
	assign_bd_address [get_bd_addr_segs {zynq_ps_0/SAXIGP5/HP3_DDR_HIGH}]
	assign_bd_address [get_bd_addr_segs {zynq_ps_0/SAXIGP5/HP3_DDR_LOW}]

	assign_bd_address -offset 0xD0000000 -range 64K [get_bd_addr_segs {engine_0/mcu_0/lmb_0/dlmb_bram_if_cntlr/SLMB/Mem}]
	assign_bd_address -offset 0xD0000000 -range 64K [get_bd_addr_segs {engine_0/mcu_0/lmb_0/ilmb_bram_if_cntlr/SLMB/Mem}]
	}

	if {$ENABLE_TRACE} {
	assign_bd_address [get_bd_addr_segs {trace_0/ddr_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK}]
	}

	########## address end ##########

	##################################################################
	# Main Block Design - end
	##################################################################

	puts "########## create $design_name end ##########"

	# Restore current instance
	current_bd_instance $oldCurInst

	validate_bd_design
	# Save after validate to keep any propagated parameters
	save_bd_design

	close_bd_design $design_name
}
# End of cr_bd_main()

cr_bd_main ""

puts "########## create $design_name wrapper begin ##########"
set wrapper [make_wrapper -files [get_files -of_objects [get_filesets [current_fileset]] $design_name.bd] -top]
# Using the make_wrapper -import option produces an "already been imported" warning
add_files -norecurse $wrapper
puts "########## create $design_name wrapper end ##########"

puts "########## create system.xdc begin ##########"
# Example: get board interface and pin properties
# get_property LOC [get_board_part_pins -of [get_board_part_interfaces led_8bits]]
# Response: AG14 AF13 AE13 AJ14 AJ15 AH13 AH14 AL12
# get_property LOC [get_board_part_pins GPIO_LED_0_LS]
# Response: AG14

set cpath "$proj_dir/$proj_name.srcs/[current_fileset -constrset]/new"
file mkdir "$cpath"
set cfid [open "$cpath/system.xdc" w]

if {$ENABLE_TRACE} {
# BOARD: sysclk, LED_0
puts $cfid {set_clock_groups -asynchronous \
	-group clk_fpga_0 \
	-group clk_fpga_1 \
	-group [get_clocks -include_generated_clocks sysclk_clk_p]}
puts $cfid "set_property PACKAGE_PIN \
	[get_property LOC [get_board_part_pins led_4bits_tri_o[0]]] \
	\[get_ports calib_complete\]"
puts $cfid "set_property IOSTANDARD \
	[get_property IOSTANDARD [get_board_part_pins led_4bits_tri_o[0]]] \
	\[get_ports calib_complete\]"
} else {
puts $cfid {set_clock_groups -asynchronous -group clk_fpga_0 -group clk_fpga_1}
}

close $cfid
add_files -fileset [current_fileset -constrset] "$cpath/system.xdc"
set_property TARGET_CONSTRS_FILE "$cpath/system.xdc" [current_fileset -constrset]
set_property USED_IN_SYNTHESIS 0 [get_files "$cpath/system.xdc"]
puts "########## create system.xdc end ##########"

puts "INFO: Project created:${proj_name}"
close_project
