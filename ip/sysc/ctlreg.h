
#ifndef _CTLREG_H
#define _CTLREG_H

#include "systemc.h"

#include "port_axis.h"

#if defined(__SYNTHESIS__)
#define ACMD_T ACMD::ui_t
#else
#define ACMD_T ACMD
#endif

#define ACMD_CONCAT \
	(drac.go,drac.wr,drac.sel,drac.len,srac.go,srac.wr,srac.sel,srac.len,did,sid)

class ACMD {
public:
	typedef sc_uint<(2*CI+2*CU)> ui_t;

	sc_uint<CI> sid; // source id
	sc_uint<CI> did; // destination id
	RACC srac;       // source register access command
	RACC drac;       // destination register access command

	ACMD(ui_t ui = 0)
	{
		ACMD_CONCAT = ui;
	}

	ACMD& operator=(ui_t ui)
	{
		ACMD_CONCAT = ui;
		return *this;
	}

	operator ui_t() const
	{
		return ACMD_CONCAT;
	}

	bool operator==(const ACMD& ob)
	{
		return
			this->sid  == ob.sid  &&
			this->did  == ob.did  &&
			this->srac == ob.srac &&
			this->drac == ob.drac;
	}
};

inline std::ostream& operator<<(std::ostream& os, const ACMD& ob)
{
	return os << hex << ob.drac << ':' << ob.srac << ':' << ob.did << ':' << ob.sid;
}

inline void sc_trace(sc_trace_file* tf, const ACMD& ob, const std::string& nm)
{
	sc_trace(tf, ob.sid,  nm+".sid");
	sc_trace(tf, ob.did,  nm+".did");
	sc_trace(tf, ob.srac, nm+".srac");
	sc_trace(tf, ob.drac, nm+".drac");
}


SC_MODULE(ctlreg) // Control Port Register Access
{
	sc_in<bool> clk;
	sc_in<bool> reset;

	axi_tc_in  s_ctl;
	axi_tc_out m_ctl;

	sc_stream_in <ACMD_T> s_acmd;
	sc_stream_out<ACMD_T> m_acmd;

	sc_in <sc_uint<CD> > s_reg[CR];
	sc_in <bool>         s_we[CR];
	sc_out<sc_uint<CD> > m_reg[CR];

	sc_signal<sc_uint<CD> > c_reg[CR];
	sc_signal<sc_uint<CD> > c_ain;
	sc_signal<sc_uint<CA> > c_asel;
	sc_signal<bool>         c_awe;

	sc_stream<ACMD_T> c_acmd1, c_acmd2;
	sc_stream<ACMD_T> c_arsp1, c_arsp2;

	sfifo_cc<ACMD_T> u_acmd;
	sfifo_cc<ACMD_T> u_arsp;
	sfifo_cc<ACMD_T> u_loop;

// can sfifo_cc read-write be used with a SC_METHOD process? no
// how to synchronize vector register write with response messages?
// use a response FIFO of depth 1

	void ct_command()
	{
		AXI_TC flit;
		while (true) {
			wait();
			c_ain.write(0);
			c_asel.write(0);
			c_awe.write(false);
			flit = s_ctl.read();
			if (flit.tuser.wr) { // write, signal write process
				sc_uint<CA> len = flit.tuser.len;
				sc_uint<CA> sel = flit.tuser.sel;
				// if (strstr(name(),"u_lsu2.u_lsur") != NULL)
				// cout << name() << "::ct_command ts: " << sc_time_stamp() << ", flit: " << flit << ", rdy: " << c_acmd1.ready_r() << endl;
				while (!c_acmd1.ready_r()) wait();
				c_ain.write(flit.tdata);
				c_asel.write(sel++);
				c_awe.write(true);
				while (--len) {
					wait();
					c_ain.write(0);
					c_asel.write(0);
					c_awe.write(false);
					AXI_TC flit = s_ctl.read();
					// if (strstr(name(),"u_lsu2.u_lsur") != NULL)
					// cout << name() << "::ct_command ts: " << sc_time_stamp() << ", flit: " << flit << ", rdy: " << c_acmd1.ready_r() << endl;
					while (!c_acmd1.ready_r()) wait();
					c_ain.write(flit.tdata);
					c_asel.write(sel++);
					c_awe.write(true);
				}
				if (flit.tuser.go) wait(); // wait for register write
			} else { // read, send to response process, tdata not used
				ACMD acmd;
				acmd.sid = flit.tdest; // swap source and destination
				acmd.did = flit.tid;
				acmd.srac = flit.tuser; // command is source of response
				acmd.drac = flit.tuser; // echo register access
				// cout << name() << "::ct_command ts: " << sc_time_stamp() << ", acmd: " << acmd << endl;
				c_acmd2.write(acmd);
			}
			if (flit.tuser.go) { // go, send to command interpreter, tdata not used
				ACMD acmd;
				acmd.sid = flit.tid;
				acmd.did = flit.tdest;
				acmd.srac = 0; // unknown source register access
				acmd.drac = flit.tuser;
				// if (strstr(name(),"u_lsu2.u_lsur") != NULL)
				// cout << name() << "::ct_command ts: " << sc_time_stamp() << ", acmd: " << acmd << ", rdy: " << c_acmd1.ready_r() << ", tdata: " << flit.tdata.to_uint() << endl;
				c_acmd1.write(acmd);
			}
		}
	}

	void ct_response()
	{
		ACMD acmd;
		while (true) {
			wait();
			if (c_arsp2.valid_r()) acmd = c_arsp2.read();
			else if (c_arsp1.valid_r()) acmd = c_arsp1.read();
			else continue;
			// cout << name() << "::ct_response ts: " << sc_time_stamp() << ", acmd: " << acmd << endl;
			while (acmd.srac.len--) {
				AXI_TC flit;
				flit.tid = acmd.sid;
				flit.tdest = acmd.did;
				flit.tuser = acmd.drac;
				flit.tdata = c_reg[acmd.srac.sel++].read();
				flit.tlast = acmd.srac.len == 0;
				// if (strstr(name(),"hsu") != NULL)
				// cout << name() << "::ct_response ts: " << sc_time_stamp() << ", flit: " << flit << endl;
				m_ctl.write(flit);
			}
		}
	}

	void ms_reg_write()
	{
		if (reset.read() == RLEVEL) {
			for (int i = 0; i < CR; i++) c_reg[i].write(0);
		} else {
			sc_uint<CD> ain = c_ain.read();
			sc_uint<CA> asel = c_asel.read();
			bool awe = c_awe.read();
			for (unsigned i = 0; i < CR; i++) {
				if (s_we[i].read()) {
					c_reg[i].write(s_reg[i].read());
				} else if (i == asel && awe) {
					// cout << name() << "::ms_reg_write ts: " << sc_time_stamp() << ", ain: " << ain << endl;
					c_reg[i].write(ain);
				}
			}
		}
	}

	void mc_assign()
	{
		for (int i = 0; i < CR; i++) m_reg[i].write(c_reg[i].read());
	}

	SC_CTOR(ctlreg) :
		u_acmd("u_acmd", 1), // must be 1 to prevent register overwrite
		u_arsp("u_arsp", 1), // must be 1 to prevent register overwrite
		u_loop("u_loop", 2)
	{
		u_acmd.clk(clk);
		u_acmd.reset(reset);
		u_acmd.s_port(c_acmd1);
		u_acmd.m_port(m_acmd);

		u_arsp.clk(clk);
		u_arsp.reset(reset);
		u_arsp.s_port(s_acmd);
		u_arsp.m_port(c_arsp1);

		u_loop.clk(clk);
		u_loop.reset(reset);
		u_loop.s_port(c_acmd2);
		u_loop.m_port(c_arsp2);

		SC_CTHREAD(ct_command, clk.pos());
			reset_signal_is(reset, RLEVEL);
		SC_CTHREAD(ct_response, clk.pos());
			reset_signal_is(reset, RLEVEL);
		SC_METHOD(ms_reg_write);
			sensitive << clk.pos();
		SC_METHOD(mc_assign);
			for (int i = 0; i < CR; i++) sensitive << c_reg[i];
	}

};

#endif // _CTLREG_H
