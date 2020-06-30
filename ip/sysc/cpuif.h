
#ifndef _CPUIF_H
#define _CPUIF_H

#include "systemc.h"
#include "port_axis.h" // axi_tc_in, axi_tc_out

#define MAX_PORTS 2

extern axi_tc_in  *s_gctl[MAX_PORTS];
extern axi_tc_out *m_gctl[MAX_PORTS];

#endif // _CPUIF_H
