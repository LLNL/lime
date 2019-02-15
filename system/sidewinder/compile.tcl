open_project psu_lime.xpr
make_wrapper -files [get_files ./psu_lime.srcs/sources_1/bd/system/system.bd] -top
add_files -norecurse ./psu_lime.srcs/sources_1/bd/system/hdl/system_wrapper.v
launch_runs synth_1 -jobs 6
wait_on_run synth_1
open_run synth_1 -name synth_1
set_clock_groups -asynchronous -group clk_pl_0 -group clk_pl_1 -group [get_clocks -include_generated_clocks PL_DDR_CLK_clk_p]
set_property PACKAGE_PIN A4 [get_ports c0_init_calib_complete_0]
set_property IOSTANDARD LVCMOS33 [get_ports c0_init_calib_complete_0]
set_property PROHIBIT true [get_bels IOB_X0Y100/PAD]
set_property PROHIBIT true [get_bels IOB_X0Y103/PAD]
set_property PROHIBIT true [get_sites AL23]
set_property PROHIBIT true [get_sites AM25]
file mkdir ./psu_lime.srcs/constrs_1/new
close [ open ./psu_lime.srcs/constrs_1/new/constrs_1.xdc w ]
add_files -fileset constrs_1 ./psu_lime.srcs/constrs_1/new/constrs_1.xdc
set_property target_constrs_file ./psu_lime.srcs/constrs_1/new/constrs_1.xdc [current_fileset -constrset]
save_constraints -force
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run impl_1
