
#ifndef _INDEL_H
#define _INDEL_H

#include <iomanip> // hex, setw
#include "systemc.h"

#include "port_axis.h"
#include "ctlreg.h"

#define SC_TICKS dec << (sc_time_stamp().value()/800)

// FIXME: duplicated in rtb.cpp, merge?
typedef unsigned long long key_type; // kmer_t
typedef unsigned int mapped_type; // sid_t
// FIXME: duplicated in KVstore.hpp, merge?
typedef unsigned int psl_t;
typedef struct {
	key_type key; // 64-bits
	mapped_type value; // 32-bits
	psl_t probes; // 32-bits
} slot_s;

//      indel unit
//      register map
// reg   31 bits  0
//     |------------|
//   0 | status:32  |
//   1 | plen:10    | minus 1
//   2 | ignore:32  |
//   3 | ignore:32  |
//   4 | ignore:32  |
//   5 | ignore:32  |
//   6 | ignore:32  |
//   7 | ignore:32  |
//     |------------|

// The control port is only used for configuration of the probe length.
// The rest of the functionality is hard wired to compare a stream of keys
// from dat1 with a stream of probes from dat2 and output a value when a
// key matches in a probe.


SC_MODULE(indel) // Insert Delete Unit
{
	sc_in<bool> clk;
	sc_in<bool> reset;

	axi_tc_in  s_ctl;
	axi_tc_out m_ctl;

	axi_td_in  s_dat1;
	axi_td_out m_dat1;
	axi_td_in  s_dat2;
	axi_td_out m_dat2;

	sc_stream<ACMD_T> c_acmd, c_arsp;
	sc_signal<sc_uint<CD> > c_vcmd[CR], c_vrsp[CR];
	sc_signal<bool> c_vwe[CR];

	ctlreg u_ctlreg;

#define _status(reg)  reg[0]
#define _plen(reg)    reg[1](9,0)

	void ct_indel_in()
	{
		sc_uint<CD> vcmd[CR];
		AXI_TD dat1;
		AXI_TD dat2;
		key_type key;
		slot_s slot;
		bool found;
		while (true) {
			dat1 = s_dat1.read();
			// cout << "dat1: " << dat1 << endl;
			for (int i = 0; i < CR; i++) vcmd[i] = c_vcmd[i].read();
			// for (int i = 0; i < CR; i++) cout << "reg:" << i << ':' << vcmd[i] << endl;
			key = dat1.tdata.to_uint64();
			// cout << "ts: " << SC_TICKS << hex << ", key: " << key << ", plen: " << _plen(vcmd) << endl;
			found = false;
			for (unsigned i = 0; i <= _plen(vcmd); i++) {
				dat2 = s_dat2.read();
				slot.key = dat2.tdata.to_uint64();
				dat2 = s_dat2.read();
				slot.value = dat2.tdata(31,0).to_uint();
				slot.probes = dat2.tdata(63,32).to_uint();
				// cout << "ts: " << SC_TICKS << hex << ", slot key: " << slot.key << ", value: " << slot.value << ", probes: " << slot.probes << endl;
				if (!found && slot.probes != 0 && slot.key == key) {
					AXI_TD flit;
					found = true;
					flit.tdata = slot.value;
					flit.tid = 0;
					flit.tdest = 0;
					flit.tkeep = 0xF;
					flit.tuser = 0;
					flit.tlast = 1;
					// cout << "ts: " << SC_TICKS << ", indel flit: " << flit << endl;
					m_dat1.write(flit);
				}
			}
			if (!found) {
					AXI_TD flit;
					flit.tdata = 0; // send null
					flit.tid = 0;
					flit.tdest = 0;
					flit.tkeep = 0xF;
					flit.tuser = 0;
					flit.tlast = 1;
					// cout << "ts: " << SC_TICKS << ", indel flit: " << flit << endl;
					m_dat1.write(flit);
			}
		}
	}

#undef _status
#undef _plen

#if 0
	void start_of_simulation()
	{
		extern sc_trace_file *tf;
		sc_trace(tf, s_dat1, (std::string(name())+".s_dat1").c_str());
		sc_trace(tf, s_dat2, (std::string(name())+".s_dat2").c_str());
		sc_trace(tf, m_dat1, (std::string(name())+".m_dat1").c_str());
		sc_trace(tf, m_dat2, (std::string(name())+".m_dat2").c_str());
	}
#endif

	SC_CTOR(indel) :
		c_acmd("c_acmd"),
		c_arsp("c_arsp"),
		u_ctlreg("u_ctlreg")
	{
		u_ctlreg.clk(clk);
		u_ctlreg.reset(reset);
		u_ctlreg.s_ctl(s_ctl);
		u_ctlreg.m_ctl(m_ctl);
		u_ctlreg.s_acmd(c_arsp);
		u_ctlreg.m_acmd(c_acmd);
		for (int i = 0; i < CR; i++) {
			u_ctlreg.m_reg[i](c_vcmd[i]);
			u_ctlreg.s_reg[i](c_vrsp[i]);
			u_ctlreg.s_we[i](c_vwe[i]);
		}

		SC_CTHREAD(ct_indel_in, clk.pos());
			reset_signal_is(reset, RLEVEL);
	}

};

#endif // _INDEL_H
