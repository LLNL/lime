#ifndef _CPU_H
#define _CPU_H

#include <malloc.h> // memalign
#include "systemc.h"

#include "port_axis.h" // axi_tc_in, axi_tc_out
#include "cpuif.h" // s_gctl, m_gctl

SC_MODULE(cpu)
{
	sc_in<bool> clk;
	sc_in<bool> reset;

	axi_tc_in  s_ctl;
	axi_tc_out m_ctl;

	int exitval;

	void th_main()
	{
		if (reset.read() == RLEVEL) for (int i = 0; i < 2; i++) wait();
#if 0
		printf("&s_ctl: %p\n", &s_ctl);
		printf("s_gctl: %p\n", s_gctl);
		// printf("sbrk(0): %p\n", sbrk(0));
		{int var; printf("var: %p\n", &var);}
		{void *heap = memalign(64,1024); printf("aheap: %p\n", heap);}
		{void *heap = malloc(1UL<<30); printf("heap: %p\n", heap); if (heap!=NULL) free(heap);}
#endif
		// &s_ctl: 0x7ffc632447e0
		// s_gctl: 0x8da410
		// sbrk(0): 0xb58000
		// var: 0x7f5c66946d6c
		// aheap: 0x7fe0dc0008c0
		// heap: 0x7f5c1ffff010
		int _sub_main(int argc, char *argv[]);
		exitval = _sub_main(sc_argc(), (char**)sc_argv());
		// cout << "Info: Application exit value: " << exitval << endl;
		sc_stop();
	}

	SC_CTOR(cpu) :
		exitval(-1)
	{
		// initialize global references to ports
		s_gctl[0] = &s_ctl;
		m_gctl[0] = &m_ctl;
#if 0
		printf("&s_ctl: %p\n", &s_ctl);
		printf("s_gctl: %p\n", s_gctl);
		// printf("sbrk(0): %p\n", sbrk(0));
		{int var; printf("var: %p\n", &var);}
		{void *heap = memalign(64,1024); printf("aheap: %p\n", heap);}
		{void *heap = malloc(1UL<<30); printf("heap: %p\n", heap); /*if (heap!=NULL) free(heap);*/}
#endif
		// &s_ctl: 0x7ffc632447e0
		// s_gctl: 0x8da410
		// sbrk(0): 0xaf5000
		// var: 0x7ffc63242790
		// aheap: 0x10e9180
		// heap: 0x7f5c672ee010

		SC_THREAD(th_main);
			sensitive << clk.pos();
			// sensitive << s_ctl.data_chg() << s_ctl.valid_chg() << m_ctl.ready_chg();
			reset_signal_is(reset, RLEVEL);
	}
};

#endif // _CPU_H
