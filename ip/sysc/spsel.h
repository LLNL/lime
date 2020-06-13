
#ifndef _SPSEL_H
#define _SPSEL_H

#include "systemc.h"

#include "port_axis.h"


SC_MODULE(spsel) // Split and Select Unit
{
	sc_in<bool> clk;
	sc_in<bool> reset;

	axi_tc_in  s_ctl;
	axi_tc_out m_ctl;

	axi_td_in  s_dat1;
	axi_td_out m_dat1;
	axi_td_in  s_dat2;
	axi_td_out m_dat2;

	axi_td c_dat1;
	axi_td c_dat2;
	axi_td_fifo<1> u_slice_d1;
	axi_td_fifo<1> u_slice_d2;

	void mc_ctl()
	{
		m_ctl.data_w(s_ctl.data_r());
		m_ctl.valid_w(s_ctl.valid_r());
		s_ctl.ready_w(m_ctl.ready_r());
	}

	void mc_dat()
	{
		c_dat1.data_w(s_dat1.data_r());
		c_dat2.data_w(s_dat1.data_r());
		c_dat1.valid_w(s_dat1.valid_r() && c_dat2.ready_r());
		c_dat2.valid_w(s_dat1.valid_r() && c_dat1.ready_r());
		s_dat1.ready_w(c_dat1.ready_r() && c_dat2.ready_r());
	}

	SC_CTOR(spsel) :
		c_dat1("c_dat1"),
		c_dat2("c_dat2"),
		u_slice_d1("u_slice_d1", 2),
		u_slice_d2("u_slice_d2", 2)
	{
		u_slice_d1.clk(clk);
		u_slice_d1.reset(reset);
		u_slice_d1.s_port(c_dat1);
		u_slice_d1.m_port(m_dat1);

		u_slice_d2.clk(clk);
		u_slice_d2.reset(reset);
		u_slice_d2.s_port(c_dat2);
		u_slice_d2.m_port(m_dat2);

		SC_METHOD(mc_ctl);
			sensitive << s_ctl.data_chg() << s_ctl.valid_chg() << m_ctl.ready_chg();
		SC_METHOD(mc_dat);
			sensitive << s_dat1.data_chg() << s_dat1.valid_chg() << c_dat1.ready_event() << c_dat2.ready_event();
	}

};

#endif // _SPSEL_H
