## this is the xsct script to build fsbl and pmu

# set the workspace
setws xsct_ws
#
# create the platform 
platform create -name zcu102_lime_platform -hw hardware/final.xsa -no-boot-bsp
platform active zcu102_lime_platform

# create the FSBL domain
domain create -name "fsbl_domain" -os standalone -proc psu_cortexa53_0
domain active fsbl_domain
#exec ./cp_tt.sh
# copy our tt from soc-course directory to bsp location
exec cp ../standalone/translation_table_a53.S xsct_ws/zcu102_lime_platform/psu_cortexa53_0/fsbl_domain/bsp/psu_cortexa53_0/libsrc/standalone_v7_5/src/translation_table.S


bsp setlib xilffs
bsp setlib xilsecure
bsp setlib xilpm
bsp config zynqmp_fsbl_bsp true

# create the PMU FW domain
domain create -name "pmufw_domain" -os standalone -proc psu_pmu_0
bsp setlib xilfpga
bsp setlib xilsecure
bsp setlib xilskey

# generate the platform
platform generate

#create the applications
app create -name zynqmp_fsbl -platform zcu102_lime_platform -template "Zynq MP FSBL" -domain fsbl_domain -lang c -sysproj \zcu102_lime_custom_system

# fix up ddr_init.c
exec cp ../standalone/xfsbl_ddr_init.c xsct_ws/zynqmp_fsbl/src

app create -name zynqmp_pmufw -platform zcu102_lime_platform -template {ZynqMP PMU Firmware}  -domain pmufw_domain -sysproj \zcu102_lime_custom_system


# check the build configuration for zynqmp_fsbl and zynqmp_pmufw
app config -name zynqmp_fsbl build-config
app config -name zynqmp_pmufw build-config

# if release mode is desired
#app config -name zynqmp_fsbl build-config release
#app config -name zynqmp_pmufw build-config release

app build -name zynqmp_fsbl
app build -name zynqmp_pmufw
