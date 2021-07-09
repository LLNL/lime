make build=zup clean
make build=zup
make build=zup fpga
#sed -i.bak -f ../../../standalone/sar.sed ../../../vitis_example2/final/hw/psu_init.c
#sed -i.bak -f ../../../standalone/sar.sed ../../../vitis_example2/final/hw/psu_init_gpl.c
#sed -i.bak -f ../../../standalone/sar.sed ../../../vitis_example2/final/hw/psu_init.tcl
make build=zup run

