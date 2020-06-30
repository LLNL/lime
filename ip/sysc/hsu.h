
#ifndef _HSU_H
#define _HSU_H

#include <iomanip> // hex, setw
#include "systemc.h"

#include "port_axis.h"
#include "ctlreg.h"
#include "shash.h"
// #include "short.h" // for debug

#define C_INIT 0xDEADBEEFDEADBEEFULL

//      hash unit
//      register map
// reg   31 bits  0
//     |------------|
//   0 | status:32  |
//   1 | tlen_lo:32 |
//   2 | tlen_hi:32 |
//   3 | command:30 | seldi:1 seldo:1 seed:4 tdest:4 tid:4 hlen:8 klen:8
//   4 | data_lo:32 |
//   5 | data_hi:32 |
//   6 | hash_lo:32 |
//   7 | hash_hi:32 |
//     |------------|


SC_MODULE(hsu) // Hash Unit
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

	sc_stream<sc_biguint<KEYLW+KEYW> > c_key;
	sc_stream<sc_biguint<TAPW> > c_tapi;
	sc_stream<sc_biguint<TAPW> > c_tapo;

	ctlreg u_ctlreg;
	short_hash u_hash;

#define _status(reg)  reg[0](4,0)
#define _tlen(reg)    (reg[2],reg[1])
#define _keylen(reg)  reg[3](7,0)
#define _hashlen(reg) reg[3](15,8)
#define _tid(reg)     reg[3](19,16)
#define _tdest(reg)   reg[3](23,20)
#define _seed(reg)    reg[3](27,24)
#define _seldo(reg)   reg[3][28]
#define _seldi(reg)   reg[3][29]
#define _data(reg)    (reg[5],reg[4])
#define hreg 6
#define _hash(reg)    (reg[hreg+1],reg[hreg])

#if 0
	void ms_status()
	{
		if (reset.read() == RLEVEL) {
			for (int i = 0; i < CR; i++) c_vrsp[i].write(0);
		} else {
		}
	}
#endif

	void mc_key_tap_in()
	{
		sc_uint<CD> vcmd[CR];
		sc_biguint<KEYW> key;
		for (int i = 0; i < CR; i++) vcmd[i] = c_vcmd[i].read();

		// key in
		if (_seldi(vcmd)) {key = s_dat1.data_r().tdata; c_key.valid_w(s_dat1.valid_r());}
		else {key = _data(vcmd); c_key.valid_w(c_acmd.valid_r());}
		c_key.data_w((_keylen(vcmd),key));
		s_dat1.ready_w(c_key.ready_r() &&  _seldi(vcmd));
		c_acmd.ready_w(c_key.ready_r() && !_seldi(vcmd));

		// tap in
		c_tapi.data_w((sc_uint<64>(C_INIT),sc_uint<64>(C_INIT),sc_uint<64>(_seed(vcmd)),sc_uint<64>(_seed(vcmd))));
		c_tapi.valid_w(true);
	}

	void mc_hash_out()
	{
		sc_uint<CD> vcmd[CR];
		sc_biguint<64> tapo, index;
		AXI_TD dat1;
		ACMD arsp;
		for (int i = 0; i < CR; i++) vcmd[i] = c_vcmd[i].read();
		tapo = c_tapo.data_r()(63,0);
		index = tapo & sc_biguint<64>(_tlen(vcmd));

		// prepare data out
		dat1.tdata = index;
		dat1.tid = _tid(vcmd);
		dat1.tdest = _tdest(vcmd);
		dat1.tkeep = -1;
		dat1.tlast = 1;
		// write hash to data out
		m_dat1.data_w(dat1);
		m_dat1.valid_w(_seldo(vcmd) && c_tapo.valid_r());

		// prepare response
		arsp.sid = _tid(vcmd);
		arsp.did = _tdest(vcmd);
		arsp.srac.len = (_hashlen(vcmd)+3) >> 2;
		arsp.srac.sel = hreg;
		arsp.srac.wr  = 0;
		arsp.srac.go  = 0;
		arsp.drac.len = arsp.srac.len;
		arsp.drac.sel = 4;
		arsp.drac.wr  = 1;
		arsp.drac.go  = 1;
		// send response
		c_arsp.data_w(arsp);
		c_arsp.valid_w(!_seldo(vcmd) && c_tapo.valid_r());
		// write hash to vrsp registers
		for (int i = 0; i < CR; i++) {
			c_vrsp[i].write(0); // defaults
			c_vwe[i].write(false);
		}
		c_vrsp[hreg  ].write(sc_uint<CD>(index(31, 0)));
		c_vrsp[hreg+1].write(sc_uint<CD>(index(63,32)));
		if (!_seldo(vcmd) && c_tapo.valid_r() && c_arsp.ready_r()) {
			c_vwe[hreg  ].write(true);
			c_vwe[hreg+1].write(true);
		}

		if (_seldo(vcmd)) c_tapo.ready_w(m_dat1.ready_r());
		else c_tapo.ready_w(c_arsp.ready_r());

#if 0 // TODO: update status with count of keys in hash unit
		c_vrsp[0].write(_status(vcmd) | kcount);
		c_vwe[0].write(true);
#endif
	}

#undef _status
#undef _tlen
#undef _keylen
#undef _hashlen
#undef _tid
#undef _tdest
#undef _seed
#undef _seldo
#undef _seldi
#undef _data
#undef hreg
#undef _hash

#if 0
	void start_of_simulation()
	{
		extern sc_trace_file *tf;
		sc_trace(tf, c_acmd, (std::string(name())+".c_acmd").c_str());
		sc_trace(tf, c_arsp, (std::string(name())+".c_arsp").c_str());
		sc_trace(tf, c_key, (std::string(name())+".c_key").c_str());
		sc_trace(tf, c_tapi, (std::string(name())+".c_tapi").c_str());
		sc_trace(tf, c_tapo, (std::string(name())+".c_tapo").c_str());
	}
#endif

	SC_CTOR(hsu) :
		c_acmd("c_acmd"),
		c_arsp("c_arsp"),
		c_key("c_key"),
		c_tapi("c_tapi"),
		c_tapo("c_tapo"),
		u_ctlreg("u_ctlreg"),
		u_hash("u_hash")
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

		u_hash.clk(clk);
		u_hash.reset(reset);
		u_hash.s_dat(c_key);
		u_hash.s_tap(c_tapi);
		u_hash.m_tap(c_tapo);

		SC_METHOD(mc_key_tap_in);
			for (int i = 0; i < CR; i++) sensitive << c_vcmd[i];
			sensitive << c_acmd.valid_event();
			sensitive << s_dat1.data_chg() << s_dat1.valid_chg();
			sensitive << c_key.ready_event();
		SC_METHOD(mc_hash_out);
			for (int i = 0; i < CR; i++) sensitive << c_vcmd[i];
			sensitive << c_tapo.data_event() << c_tapo.valid_event();
			sensitive << m_dat1.ready_chg();
			sensitive << c_arsp.ready_event();
	}

};

#endif // _HSU_H
