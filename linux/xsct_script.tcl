#https://www.xilinx.com/support/answers/71921.html
set verbose 1
proc copy_psu_init_files {src_folder} {
	file mkdir $src_folder
	file copy -force psu_init.h $src_folder
	file copy -force psu_init.c $src_folder
}

proc package_files {app} {
	if {[file isdirectory $app] == 1} {
		file mkdir packaged_files/${app}
		file copy -force ${app}/executable.elf packaged_files/${app}
	}
}

proc boot_files {app} {
	if {[file isdirectory $app] == 1} {
		file mkdir boot_files/${app}
		file copy -force ${app}/executable.elf boot_files/${app}
	}
}

#Generate ZynqMP FSBL
proc generate_zynqmp_fsbl {} {
	set proc [lindex [get_processor] 0]
	set repo [glob -nocomplain -type d repo]
	if {$repo != ""} {
		hsi::set_repo_path ./repo
	}
	set fsbl_design [hsi::create_sw_design fsbl_1 -proc $proc -app zynqmp_fsbl]
	common::set_property APP_COMPILER "aarch64-none-elf-gcc" $fsbl_design
	if {[dev_board] != ""} {
		common::set_property -name APP_COMPILER_FLAGS -value "-DRSA_SUPPORT -DFSBL_DEBUG_INFO -DXPS_BOARD_[dev_board]" -objects $fsbl_design
	} else {
		common::set_property -name APP_COMPILER_FLAGS -value "-DRSA_SUPPORT -DFSBL_DEBUG_INFO" -objects $fsbl_design
	}

	if {[get_project_info FAMILY] == "zynquplusRFSOC"} {
		hsi::add_library libmetal
	}
	copy_psu_init_files zynqmp_fsbl
	hsi::generate_app -dir zynqmp_fsbl -compile
	return "zynqmp_fsbl/executable.elf"
}

proc fsbl {args} {
    set board 0
    for {set i 0} {$i < [llength $args]} {incr i} {
        if {[lindex $args $i] == "-board"} {
            set board [string toupper [lindex $args [expr {$i + 1}]]]
        }
    }
    set xsa [glob -nocomplain -directory [pwd]/../system/ -type f *.xsa]
    puts $xsa
    cd sdk
    exec mkdir -p hw_platform_0
    cd hw_platform_0
    file copy $xsa [pwd]
    set xsa_loc [split $xsa \/]
    catch {set xsa_file_name [lindex $xsa_loc [expr {[llength $xsa_loc] - 1}]]} result
    hsi::open_hw_design $xsa_file_name
    #platform create -name hw_platform_0 -hw ../system/system_wrapper.xsa
    #hsi::open_hw_design $xsa
    set fsbl_design [hsi::create_sw_design fsbl_1 -proc psu_cortexa53_0 -app zynqmp_fsbl]
    if {$board != 0} {
        common::set_property -name APP_COMPILER_FLAGS -value "-DXPS_BOARD_${board}" -objects $fsbl_design
    }
    copy_psu_init_files zynqmp_fsbl
    hsi::generate_app -dir zynqmp_fsbl -compile
    #closehw hw_platform_0
    hsi::close_hw_design [hsi::current_hw_design]
    cd ../../
}

proc pmufw {} {
    cd sdk/hw_platform_0/
    set xsa [glob -nocomplain -directory [pwd] -type f *.xsa]
    puts $xsa
    hsi::open_hw_design $xsa
    hsi::generate_app -app zynqmp_pmufw -proc psu_pmu_0 -dir zynqmp_pmufw -compile
    hsi::close_hw_design [hsi::current_hw_design]
    cd ../..    
}

#Generate Hello World
proc generate_hello_world {} {
	set proc [lindex [get_processor] 0]
	set repo [glob -nocomplain -type d repo]
	if {$repo != ""} {
		hsi::set_repo_path ./repo
	}
	set hello_design [hsi::create_sw_design hello_1 -proc $proc -app hello_world]
	if {[get_project_info FAMILY] == "zynquplusRFSOC"} {
		hsi::add_library libmetal
	}
	hsi::generate_app -dir hello_world -compile
	return "hello_world/executable.elf"
}

#Generate ZynqMP DRAM test
proc generate_zynqmp_dram_test {} {
	if {[ps_ddr_enabled] == 1} {
		set proc [lindex [get_processor] 0]
		set repo [glob -nocomplain -type d repo]
		if {$repo != ""} {
			hsi::set_repo_path ./repo
		}
		set zynqmp_dram_test [hsi::create_sw_design zynqmp_dram_test_1 -proc $proc -app zynqmp_dram_test]
		if {[get_project_info FAMILY] == "zynquplusRFSOC"} {
			hsi::add_library libmetal
		}
		hsi::generate_app -dir zynqmp_dram_test -compile
		return "zynqmp_dram_test/executable.elf"
	} else {
		puts "DDRC is not enabled in the PCW \n"
	}
}

#Generate ZynqMP PMUFW
proc generate_zynqmp_pmufw {} {
	set proc [lindex [get_processor] 1]
	set repo [glob -nocomplain -type d repo]
	if {$repo != ""} {
		hsi::set_repo_path ./repo
	}
	hsi::generate_app -app zynqmp_pmufw -proc $proc -dir zynqmp_pmufw -compile
	return "zynqmp_pmufw/executable.elf"
}

proc dev_board {} {
	set board [split [get_project_info BOARD] ":"]
	if {[llength $board] > 0} {
		return [string toupper [string range [lindex $board 1] 0 5]]
	} 
}

#to do: update supported apps
proc verify_apps {app} {
	set sup_apps ""
	foreach supported_app [supported_apps] {
		lappend sup_apps $supported_app
	}
	for {set i 0} {$i < [llength $sup_apps]} {incr i} {
		if {$app == [lindex $sup_apps $i]} {
			return 1
		}
	}
	return 0
}

proc supported_apps {} {
	set apps ""
	foreach proc [get_processor] {
		foreach temp_app [split [hsi::generate_app -proc $proc -os standalone -sapp] " "] {
			lappend apps $temp_app
		}
	}
	return $apps
}


proc is_app {app} {
	foreach exist_app [glob -nocomplain -types d *] {
		if {$exist_app == $app} {
			return 1
		}
	}
	return 0
}

proc get_project_info {info} {
	return [common::get_property $info [hsi::current_hw_design]]
}

proc ps_ddr_enabled {} {
	if {[get_project_info FAMILY] == "zynquplus" || [get_project_info FAMILY] == "zynquplusRFSOC"} {
		return [common::get_property CONFIG.PSU__DDRC__ENABLE [hsi::get_cells -filter {IP_NAME==zynq_ultra_ps_e}]]
	} else {
		return 0
	}
}

proc get_processor {} {
	set ret_procs ""
	set procs [hsi::get_cells -filter {IP_TYPE==PROCESSOR}]
	if {[get_project_info FAMILY] == "zynquplus" || [get_project_info FAMILY] == "zynquplusRFSOC"} {
		foreach proc $procs {
			if {$proc == "psu_cortexa53_0"} {
				lappend ret_procs $proc
			} elseif {$proc == "psu_pmu_0"} {
				lappend ret_procs $proc
			} 
		}
	}
	return $ret_procs
}

proc is_enabled {app_list app_test} {
	foreach app $app_list {
		if {$app == $app_test} {
			return 1
		}
	}	
	return 0
}

#assumes the target proc is the cortexa53
proc gen_bif {} {
	cd boot_files
	set apps ""
	foreach dir [glob -type d *] {
		if {$dir != "zynqmp_fsbl" || $dir != "zynqmp_pmufw"} {
			lappend apps $dir
		}
	}
	set fsbl [glob -nocomplain -directory zynqmp_fsbl *.elf]
	set bit [glob -nocomplain -directory [pwd] *.bit]
	set pmufw [glob -nocomplain -directory zynqmp_pmufw *.elf]
	if {$fsbl == ""} {
		puts "Error: BIF needs at least the FSBL"
		return 0
	}
	set outputFile [open bootgen.bif w]
	puts $outputFile "the_ROM_image:"
	puts $outputFile "{"
	puts $outputFile "\t\[fsbl_config\] a53_x64"
	puts $outputFile "\t\[bootloader\] $fsbl"
	if {$pmufw != ""} {
	puts $outputFile "\t\[pmufw_image\] $pmufw"
	}
	if {$bit != ""} {
	puts $outputFile "\t\[destination_device = pl\] $bit"
	}
	puts $outputFile "}"
	close $outputFile
	exec bootgen -arch zynqmp -image bootgen.bif -o i BOOT.BIN -w on
	cd ..
	puts "BOOT.BIN file created successfully"
}

#Open HW
proc open_hw {hdf} {
	hsi::open_hw_design $hdf
}

#Close HW
proc close_hw {} {
	hsi::close_hw_design [hsi::current_hw_design]
}

#Close SW
proc close_sw {} {
	hsi::close_sw_design [hsi::current_sw_design]
}

proc build_dts {args} {
    set board 0
    set version 2020.1
    for {set i 0} {$i < [llength $args]} {incr i} {
        if {[lindex $args $i] == "-board"} {
            set board [string tolower [lindex $args [expr {$i + 1}]]]
        }
        if {[lindex $args $i] == "-version"} {
            set version [string toupper [lindex $args [expr {$i + 1}]]]
        }
    }
	set dts_dir ../../dts/
	cd sdk/hw_platform_0/
        set xsa [glob -nocomplain -directory [pwd] -type f *.xsa]
        hsi::open_hw_design $xsa
        hsi::set_repo_path ./repo
        hsi::create_sw_design device-tree -os device_tree -proc psu_cortexa53_0
        hsi::generate_target -dir $dts_dir
	set apm_0 [hsi::get_cells apm_0]
	puts "here is the apm value: $apm_0"
	if {$apm_0 ne ""} {
		puts "Into apm_0 file change"
		set tdata_w [hsi::get_property CONFIG.C_FIFO_AXIS_TDATA_WIDTH $apm_0]
		puts "$tdata_w"
		exec sed -i.bak "/apm_0/ a\\\t\t\txlnx,fifo-axis-tdata-width = <$tdata_w>;" $dts_dir/pl.dtsi
	}
        hsi::close_hw_design [hsi::current_hw_design]
        puts "value of board is: $board"
        if {$board != 0} {
        foreach lib [glob -nocomplain -directory repo/my_dtg/device-tree-xlnx/device_tree/data/kernel_dtsi/${version}/include/dt-bindings -type d *] {
            if {![file exists $dts_dir/include/dt-bindings/[file tail $lib]]} {
                file copy -force $lib $dts_dir/include/dt-bindings
            }
        }
        set dtsi_files [glob -nocomplain -directory repo/my_dtg/device-tree-xlnx/device_tree/data/kernel_dtsi/${version}/BOARD -type f *${board}*]
        if {[llength $dtsi_files] != 0} {
            file copy -force [lindex $dtsi_files end] $dts_dir
            set fileId [open $dts_dir/system-user.dtsi "w"]
            puts $fileId "/include/ \"[file tail [lindex $dtsi_files end]]\""
            puts $fileId "/ {"
            puts $fileId "};"
            close $fileId
        }
    }
}


proc build_script {args} {
	set filename jtag_boot.tcl
	set outputFile [open $filename w]
	set apps ""
	set force 0
	set package 0
	set boot 0
	for {set i 0} {$i < [llength $args]} {incr i} {
		if {[lindex $args $i] == "-hw" } {
			set hdf [lindex $args [expr {$i + 1}]]
		} elseif {[lindex $args $i] == "-apps" } {
			for {set j [expr {$i + 1}]} {$j < [llength $args]} {incr j} {
				if {[string range [lindex $args $j] 0 0] != "-"} {
					lappend apps [lindex $args $j]
				}
			}
		} elseif {[lindex $args $i] == "-force" } {
			set force 1
		} elseif {[lindex $args $i] == "-package" } {
			set package 1
			file mkdir packaged_files
		} elseif {[lindex $args $i] == "-boot" } {
			set boot 1
			file mkdir boot_files
		}
	}
	open_hw $hdf
	foreach app $apps {
		if {[verify_apps $app] == 1} {
			if {[is_app $app] == 1 && $force == 1} {
				file delete -force $app
				generate_${app}
			} elseif {[is_app $app] == 0} {
				generate_${app}
			} else {
				puts "$app already exits, and the -force option not enabled"
			}
		} else {
			puts "$app provided is not supported. No app will be created for this"
			puts "Run the supported_apps proc to get a list of all the supported apps for your HDF"
		}
	}
	puts $outputFile "# Set up connection \n"
	puts $outputFile "#if this is a remote connection. Then use something like:"
	puts $outputFile "#connect -url TCP:XIRSTEPHENM32:3121"
	puts $outputFile "#or, if local, then just use"
	puts $outputFile "connect"
	if {[is_app zynqmp_pmufw] == 1 && [is_enabled $apps zynqmp_pmufw] == 1} {
		if {$package == 1} {
			package_files zynqmp_pmufw
		}
		if {$boot == 1} {
			boot_files zynqmp_pmufw
		}
		puts $outputFile "\n# Add the Microblaze PMU to target"
		puts $outputFile "targets -set -nocase -filter {name =~ \"PSU\"}"
		puts $outputFile "mwr 0xFFCA0038 0x1FF"
		puts $outputFile "# Download PMUFW to PMU"
		puts $outputFile "target -set -filter {name =~ \"MicroBlaze PMU\"}"
		puts $outputFile "dow zynqmp_pmufw/executable.elf"
		puts $outputFile "con"
	}
	set bit [glob -nocomplain -directory [pwd] [file rootname $hdf].bit]
	if {$bit != ""} {
		if {$package == 1} {
			file copy -force $bit packaged_files
		}
		if {$boot == 1} {
			file copy -force $bit boot_files
		}
		puts $outputFile "\n# Programming PL"
		puts $outputFile "fpga -f [file tail $bit]"
	}
	set fsbl 0
	if {[is_app zynqmp_fsbl] == 1 && [is_enabled $apps zynqmp_fsbl] == 1} {
		set fsbl 1
		if {$package == 1} {
			package_files zynqmp_fsbl
		}
		if {$boot == 1} {
			boot_files zynqmp_fsbl
		}
		puts $outputFile "\n# Download ZYNQMP FSBL to A53 #0"
		puts $outputFile "targets -set -nocase -filter {name =~ \"PSU\"}"
		puts $outputFile "# write bootloop and release A53-0 reset"
		puts $outputFile "mwr 0xffff0000 0x14000000"
		puts $outputFile "mwr 0xFD1A0104 0x380E"
		puts $outputFile "targets -set -filter {name =~ \"Cortex-A53 #0\"}"
		puts $outputFile "dow zynqmp_fsbl/executable.elf"
		puts $outputFile "con"
		puts $outputFile "after 500"
		puts $outputFile "stop"
	} else {
		if {$package == 1} {
			file copy -force psu_init.tcl packaged_files
		}
		puts $outputFile "\n# Configuring PSU"
		puts $outputFile "targets -set -nocase -filter {name =~ \"PSU\"}"
		puts $outputFile "source psu_init.tcl"
		puts $outputFile "psu_init"
		puts $outputFile "after 500"
		puts $outputFile "psu_post_config"
		puts $outputFile "after 500"
		puts $outputFile "psu_ps_pl_reset_config"
		puts $outputFile "after 500"
		puts $outputFile "psu_ps_pl_isolation_removal"
		puts $outputFile "after 500"
		
	}
	if {[is_app hello_world] == 1 && [is_enabled $apps hello_world] == 1} {
		if {$fsbl == 0} {
			set fsbl 1
			puts $outputFile "\n# write bootloop and release A53-0 reset"
			puts $outputFile "targets -set -nocase -filter {name =~ \"PSU\"}"
			puts $outputFile "mwr 0xffff0000 0x14000000"
			puts $outputFile "mwr 0xFD1A0104 0x380E"
		}
		if {$package == 1} {
			package_files hello_world
		}
		puts $outputFile "\n# Download Hello World to A53 #0"
		puts $outputFile "targets -set -filter {name =~ \"Cortex-A53 #0\"}"
		puts $outputFile "dow hello_world/executable.elf"
		puts $outputFile "con"
		puts $outputFile "after 500"
		puts $outputFile "stop"
	}
	if {[is_app zynqmp_dram_test] == 1 && [is_enabled $apps zynqmp_dram_test] == 1} {
		if {$fsbl == 0} {
			set fsbl 1
			puts $outputFile "\n# write bootloop and release A53-0 reset"
			puts $outputFile "targets -set -nocase -filter {name =~ \"PSU\"}"
			puts $outputFile "mwr 0xffff0000 0x14000000"
			puts $outputFile "mwr 0xFD1A0104 0x380E"
		}
		if {$package == 1} {
			package_files zynqmp_dram_test
		}
		puts $outputFile "\n# Download ZYNQMP DRAM Test to A53 #0"
		puts $outputFile "targets -set -filter {name =~ \"Cortex-A53 #0\"}"
		puts $outputFile "dow zynqmp_dram_test/executable.elf"
		puts $outputFile "con"
	}
	close $outputFile
	puts "$filename created successfully"
	if {$package == 1} {
		file copy -force $filename packaged_files
	}
	if {$boot == 1} {
		gen_bif
		
	}
	close_hw
}
