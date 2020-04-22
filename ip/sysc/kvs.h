 
#ifndef _KVS_H
#define _KVS_H

// #include <initializer_list>
// #include <algorithm> // for_each

#include "systemc.h"

#include "port_axis.h"
#include "cswitch.h"
#include "lsu.h"
#include "hsu.h"
#include "spsel.h"
#include "indel.h"

// #define ARM0_PN 0 /* ARM 0 port number */
// #define MCU0_PN 1 /* MCU 0 port number */
// #define LSU0_PN 2 /* LSU 0 port number */
// #define LSU1_PN 3 /* LSU 1 port number */
// #define HSU0_PN 4 /* HSU 0 port number */
// #define LSU2_PN 5 /* LSU 2 port number */
// #define PRU0_PN 6 /* PRU 0 port number */

SC_MODULE(kvs)
{
	// ports
	sc_in<bool> clk;
	sc_in<bool> reset;

	axi_tc_in  s_ctl0;
	axi_tc_out m_ctl0;

//	axi_tc_in  s_ctl1; // MCU0 not used for kvs
//	axi_tc_out m_ctl1;

//	tlm_utils::simple_initiator_socket<kvs> m_mem0_w; // LSU0 not used for kvs
//	tlm_utils::simple_initiator_socket<kvs> m_mem0_r;

	tlm::tlm_initiator_socket<> m_mem1_w;
	tlm::tlm_initiator_socket<> m_mem1_r;

	tlm::tlm_initiator_socket<> m_mem2_w;
	tlm::tlm_initiator_socket<> m_mem2_r;

	// channels - named in context of master
	axi_tc csw1_c; // MCU0 not used for kvs
	axi_tc csw2_c; // LSU0 not used for kvs
	axi_tc csw3_c;
	axi_tc csw4_c;
	axi_tc csw5_c;
	axi_tc csw6_c;
	axi_tc csw7_c;
//	axi_tc lsu0_c; // LSU0 not used for kvs
//	axi_td lsu0_d;
	axi_tc lsu1_c;
	axi_td lsu1_d;
	axi_tc lsu2_c;
	axi_td lsu2_d;
	axi_tc ssu0_c;
	axi_td ssu0_d1;
	axi_td ssu0_d2;
	axi_tc hsu0_c;
	axi_td hsu0_d1;
	axi_td hsu0_d2;
	axi_tc idu0_c;
	axi_td idu0_d1;
	axi_td idu0_d2;
	axi_td stub_d1;
	axi_td stub_d2;
	axi_td que0_d;

	// modules
	cswitch<8>     u_csw0; // control switch 0
//	lsu            u_lsu0; // load store unit 0 not used for kvs
	lsu            u_lsu1; // load store unit 1
	lsu            u_lsu2; // load store unit 2
	spsel          u_ssu0; // split select unit 0
	hsu            u_hsu0; // hash unit 0
	indel          u_idu0; // insert delete unit 0
	axi_td_fifo<8> u_que0; // stream FIFO 0

#if 0 && defined(VCD)
	void start_of_simulation()
	{
		extern sc_trace_file *tf;
		sc_trace(tf, lsu1_d, (std::string(name())+".lsu1_d").c_str());
		sc_trace(tf, idu0_d1, (std::string(name())+".idu0_d1").c_str());
		sc_trace(tf, ssu0_d1, (std::string(name())+".ssu0_d1").c_str());
		sc_trace(tf, ssu0_d2, (std::string(name())+".ssu0_d2").c_str());
	}
#endif

	SC_CTOR(kvs) :
		// ports

		// channels - named in context of master
		csw1_c ("csw1_c"), // MCU0 not used for kvs
		csw2_c ("csw2_c"), // LSU0 not used for kvs
		csw3_c ("csw3_c"),
		csw4_c ("csw4_c"),
		csw5_c ("csw5_c"),
		csw6_c ("csw6_c"),
		csw7_c ("csw7_c"),
//		lsu0_c ("lsu0_c"), // LSU0 not used for kvs
//		lsu0_d ("lsu0_d"),
		lsu1_c ("lsu1_c"),
		lsu1_d ("lsu1_d"),
		lsu2_c ("lsu2_c"),
		lsu2_d ("lsu2_d"),
		ssu0_c ("ssu0_c"),
		ssu0_d1("ssu0_d1"),
		ssu0_d2("ssu0_d2"),
		hsu0_c ("hsu0_c" ),
		hsu0_d1("hsu0_d1"),
		hsu0_d2("hsu0_d2"),
		idu0_c ("idu0_c" ),
		idu0_d1("idu0_d1"),
		idu0_d2("idu0_d2"),

		stub_d1("stub_d1"),
		stub_d2("stub_d2"),

		// modules
		u_csw0("u_csw0"),
//		u_lsu0("u_lsu0"), // LSU0 not used for kvs
		u_lsu1("u_lsu1"),
		u_lsu2("u_lsu2"),
		u_ssu0("u_ssu0"),
		u_hsu0("u_hsu0"),
		u_idu0("u_idu0"),
		u_que0("u_que0", 256)
	{
		u_csw0.clk(clk);
		u_csw0.reset(reset);
		u_csw0.s_port[0](s_ctl0);
		u_csw0.m_port[0](m_ctl0);
		u_csw0.s_port[1](csw1_c); // MCU0 not used for kvs
		u_csw0.m_port[1](csw1_c);
		u_csw0.s_port[2](csw2_c); // LSU0 not used for kvs
		u_csw0.m_port[2](csw2_c);
		u_csw0.s_port[3](lsu1_c);
		u_csw0.m_port[3](csw3_c);
		u_csw0.s_port[4](hsu0_c);
		u_csw0.m_port[4](csw4_c);
		u_csw0.s_port[5](lsu2_c);
		u_csw0.m_port[5](csw5_c);
		u_csw0.s_port[6](idu0_c);
		u_csw0.m_port[6](csw6_c);
		u_csw0.s_port[7](csw7_c); // not used for kvs
		u_csw0.m_port[7](csw7_c);

		u_lsu1.clk(clk);
		u_lsu1.reset(reset);
		u_lsu1.s_ctl(csw3_c);
		u_lsu1.m_ctl(lsu1_c);
		u_lsu1.s_dat(stub_d1);
		u_lsu1.m_dat(lsu1_d);
		u_lsu1.m_mem_w(m_mem1_w);
		u_lsu1.m_mem_r(m_mem1_r);

		u_lsu2.clk(clk);
		u_lsu2.reset(reset);
		u_lsu2.s_ctl(csw5_c);
		u_lsu2.m_ctl(lsu2_c);
		u_lsu2.s_dat(idu0_d1);
		u_lsu2.m_dat(lsu2_d);
		u_lsu2.m_mem_w(m_mem2_w);
		u_lsu2.m_mem_r(m_mem2_r);

		u_ssu0.clk(clk);
		u_ssu0.reset(reset);
		u_ssu0.s_ctl(ssu0_c);
		u_ssu0.m_ctl(ssu0_c);
		u_ssu0.s_dat1(lsu1_d);
		u_ssu0.m_dat1(ssu0_d1);
		u_ssu0.s_dat2(stub_d2);
		u_ssu0.m_dat2(ssu0_d2);

		u_hsu0.clk(clk);
		u_hsu0.reset(reset);
		u_hsu0.s_ctl(csw4_c);
		u_hsu0.m_ctl(hsu0_c);
		u_hsu0.s_dat1(ssu0_d2);
		u_hsu0.m_dat1(hsu0_d1);
		u_hsu0.s_dat2(hsu0_d2);
		u_hsu0.m_dat2(hsu0_d2);

		u_idu0.clk(clk);
		u_idu0.reset(reset);
		u_idu0.s_ctl(csw6_c);
		u_idu0.m_ctl(idu0_c);
		u_idu0.s_dat1(que0_d);
		u_idu0.m_dat1(idu0_d1);
		u_idu0.s_dat2(lsu2_d);
		u_idu0.m_dat2(idu0_d2);

		u_que0.clk(clk);
		u_que0.reset(reset);
		u_que0.s_port(ssu0_d1);
		u_que0.m_port(que0_d);
	}

};

#endif // _KVS_H
