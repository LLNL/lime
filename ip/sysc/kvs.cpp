
#include <cstdlib> // getenv

#include "pulse.h"
#include "kvs.h"
#include "cpu.h"

#if defined(HMCSIM)
#include "HMCSim.h"
using namespace Micron::Internal::HMC;

#else // not HMCSIM
#include "tlm_utils/peq_with_cb_and_phase.h"

#define NSOCKETS 4

#if !defined(T_W)
#define T_W 106 // Average DRAM Write, off-chip
#endif
#if !defined(T_R)
#define T_R  85 // Average DRAM Read, off-chip
#endif
#if !defined(T_TRANS)
#define T_TRANS 24 // 24 32 40
#endif
#define T_SRAM_W 12
#define T_SRAM_R 12
#define T_DRAM_W 45 // (T_W - T_TRANS) // 45
#define T_DRAM_R 45 // (T_R - T_TRANS) // 45
#define T_QUEUE_W (T_W - T_DRAM_W - T_TRANS) // 00 20 40
#define T_QUEUE_R (T_R - T_DRAM_R - T_TRANS) // 00 20 40

// Queue delay, ps per entry
#define _PSPE 1900

// Interconnect bandwidth, ps per byte
// 32 GiB/s is ~ 29.10 ps/byte
#define _PSPB 30

class Config {} conf;

SC_MODULE(HMCController)
{
	std::vector<tlm_utils::simple_target_socket<HMCController>*> sockets;
	tlm_utils::peq_with_cb_and_phase<HMCController> peq;
	unsigned reqcnt[NSOCKETS], treqcnt;
	sc_time nextrd, nextwr;

	tlm::tlm_sync_enum nb_transport_fw(tlm::tlm_generic_payload& tpay, tlm::tlm_phase& phase, sc_time& delay)
	{
		unsigned id = tpay.get_streaming_width();
		if (id < NSOCKETS) {reqcnt[id]++; treqcnt++;}

		// multiple queue delay model
		// delay += sc_time(reqcnt[id] * _PSPE, SC_PS);
		// single queue delay model
		delay += sc_time(treqcnt * _PSPE, SC_PS);

		// bandwidth model, for write
		if (tpay.is_write()) {
			sc_time tslot = sc_time(tpay.get_data_length() * _PSPB, SC_PS); // time slot in ps
			sc_time ttarg = sc_time_stamp() + delay;
			if (ttarg < nextwr) {
				delay += nextwr-ttarg;
				// cout << "id:" << id << " ttarg:" << ttarg << " nextwr:" << nextwr << endl;
			}
			nextwr = sc_time_stamp() + delay + tslot;
		}

#if 1
		// FIXME: use address to determine memory type (SRAM, DRAM)
		// instead of id (id == 2 is LSU2 write).
		if (tpay.is_read()) delay += sc_time(T_DRAM_R+T_QUEUE_R, SC_NS);
		else delay += sc_time(id == 2 ? T_SRAM_W : (T_DRAM_W+T_QUEUE_W), SC_NS);
#else
		// accelerator has off-chip transport delay
		if (tpay.is_read()) delay += sc_time(T_R, SC_NS);
		else delay += sc_time(T_W, SC_NS);
#endif

		// cout << reqcnt[0] << ':' << reqcnt[1] << ':' << reqcnt[2] << ':' << reqcnt[3] << endl;
		// cout << id << ':' << sc_time_stamp() << ':' << sc_time_stamp()+delay << endl;
		// cout << "id:" << id << " delay:" << delay << endl;
		// cout << "id:" << id << " delay:" << delay << " rcnt:" << reqcnt[id] << " qdpt:" << tpay.get_extension<extension>()->qdepth << endl;

		peq.notify(tpay, phase, delay);
		// peq_cb(tpay, phase);
		return tlm::TLM_UPDATED;
	}

	void peq_cb(tlm::tlm_generic_payload& tpay, const tlm::tlm_phase& phase)
	{
		// tlm::tlm_sync_enum status;
		sc_time delay;
		tlm::tlm_phase next_phase = tlm::BEGIN_RESP;
		unsigned id = tpay.get_streaming_width(); // non-standard for HMCSim, should use tag
		if (id < NSOCKETS) {reqcnt[id]--; treqcnt--;}

		// bandwidth model, for read
		if (tpay.is_read()) {
			sc_time tslot = sc_time(tpay.get_data_length() * _PSPB, SC_PS); // time slot in ps
			sc_time ttarg = sc_time_stamp() + delay;
			if (ttarg < nextrd) {
				delay += nextrd-ttarg;
				// cout << "id:" << id << " ttarg:" << ttarg << " nextrd:" << nextrd << endl;
			}
			nextrd = sc_time_stamp() + delay + tslot;
		}

		/*status =*/ (*(sockets.at(id)))->nb_transport_bw(tpay, next_phase, delay);
	}

	SC_CTOR(HMCController) : peq("peq", this, &HMCController::peq_cb)
	{
		for (unsigned i = 0; i < NSOCKETS; i++) {
			sockets.push_back(new tlm_utils::simple_target_socket<HMCController>);
			sockets[i]->register_nb_transport_fw(this, &HMCController::nb_transport_fw);
			reqcnt[i] = 0;
			nextrd = SC_ZERO_TIME;
			nextwr = SC_ZERO_TIME;
		}
	}
};

SC_MODULE(HMCWrapper)
{
	HMCController hmc;

public:
	SC_CTOR(HMCWrapper) : hmc("hmc")
	{
	}

	std::vector<tlm_utils::simple_target_socket<HMCController>*> GetControllerSockets()
	{
		return hmc.sockets;
	}

	void DumpStats()
	{
	}
};

Config* GetConfig(std::string configFilename)
{
	return &conf;
}

HMCWrapper* getHMCWrapper(const Config& config)
{
	HMCWrapper *wrapper = new HMCWrapper("HMCWrapper");
	return wrapper;
}
#endif // end HMCSIM

using std::string;
using std::vector;

FILE *tfp;
sc_trace_file *tf;

int sc_main(int argc, char *argv[])
{
	sc_report_handler::set_actions(SC_ID_IEEE_1666_DEPRECATION_, SC_DO_NOTHING);
	// sc_report_handler::set_actions(SC_ID_LOGIC_X_TO_BOOL_, SC_LOG);
	// sc_report_handler::set_actions(SC_ID_VECTOR_CONTAINS_LOGIC_VALUE_, SC_LOG);
	// sc_report_handler::set_actions(SC_ID_OBJECT_EXISTS_, SC_LOG);

	sc_clock clk("clk", 800, SC_PS); // create a 800ps period clock signal
	sc_signal<bool> reset("reset");

	// channels - named in context of accelerator
	axi_tc s_ctl0("s_ctl0");
	axi_tc m_ctl0("m_ctl0");

	// axi_tc s_ctl1("s_ctl1", 2);
	// axi_tc m_ctl1("m_ctl1", 2);

	pulse<1,2,RLEVEL> u_pulse("u_pulse");
	cpu u_cpu("u_cpu");
	kvs u_acc("u_acc");

#if defined(HMCSIM)
	char *cpath = std::getenv("HMC_CONFIG"); // currently: lime/ip/sysc/config.def
	if (cpath == nullptr) SC_REPORT_ERROR("set HMC_CONFIG env variable", 0);
#else
	char *cpath = (char *)"not_needed";
#endif
	Config *cfg = GetConfig(string(cpath));
	if (cfg == nullptr) SC_REPORT_ERROR("GetConfig failed", 0);
	HMCWrapper *wrapper = getHMCWrapper(*cfg);
	vector<tlm_utils::simple_target_socket<HMCController>*> s_mem = wrapper->GetControllerSockets();

	// connect pulse
	u_pulse.clk(clk);
	u_pulse.sig(reset);

	// connect CPU
	u_cpu.clk(clk);
	u_cpu.reset(reset);
	u_cpu.s_ctl(m_ctl0);
	u_cpu.m_ctl(s_ctl0);

	// connect accelerator
	u_acc.clk(clk);
	u_acc.reset(reset);
	u_acc.s_ctl0(s_ctl0);
	u_acc.m_ctl0(m_ctl0);
	u_acc.m_mem1_w(*(s_mem[0]));
	u_acc.m_mem1_r(*(s_mem[1]));
	u_acc.m_mem2_w(*(s_mem[2]));
	u_acc.m_mem2_r(*(s_mem[3]));

#if defined(VCD)
	extern sc_trace_file *tf;
	tf = sc_create_vcd_trace_file("kvs");
	tf->set_time_unit(10, SC_PS);
	sc_trace(tf, clk, clk.name());
	sc_trace(tf, reset, reset.name());
	// sc_trace(tf, s_ctl0, "s_ctl0");
	// sc_trace(tf, m_ctl0, "m_ctl0");

	// for (int i = 0; i < 8; i++) {
		// sc_trace(tf, u_acc.u_csw0.s_port[i],
			// (string("u_acc.u_csw0.s_port_")+std::to_string(i)).c_str());
	// }
	// for (int i = 0; i < 8; i++) {
		// sc_trace(tf, u_acc.u_csw0.m_port[i],
			// (string("u_acc.u_csw0.m_port_")+std::to_string(i)).c_str());
	// }
#endif

#if defined(TRACE)
	tfp = fopen("trace.csv", "w");
#endif

	cout << "time resolution: " << sc_get_time_resolution() << endl;
	cout << "max time: " << sc_max_time() << endl;
	SC_REPORT_INFO("/OSCI/SystemC", "Simulation begin.");
	clock_t start = clock();
	sc_start();
	clock_t finish = clock();
	cout << "simulation time: " << 
		((signed long long)(finish-start)/(double)CLOCKS_PER_SEC) <<
		" sec" << endl;

#if defined(TRACE)
	fclose(tfp);
#endif

#if defined(VCD)
	sc_close_vcd_trace_file(tf);
#endif

	return u_cpu.exitval;
}
