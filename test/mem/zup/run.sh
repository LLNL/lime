#make D=STATS,CLIENT,CLOCKS build=zup clean
#make D=STATS,CLIENT,CLOCKS build=zup
#make D=STATS,CLIENT,CLOCKS build=zup fpga
#make D=STATS,CLIENT,CLOCKS build=zup run

make D=STATS,CLOCKS,CLIENT,VAR_DELAY=_GDT_ build=zup clean
make D=STATS,CLOCKS,CLIENT,VAR_DELAY=_GDT_ build=zup
make D=STATS,CLOCKS,CLIENT,VAR_DELAY=_GDT_ build=zup fpga
make D=STATS,CLOCKS,CLIENT,VAR_DELAY=_GDT_ build=zup run

