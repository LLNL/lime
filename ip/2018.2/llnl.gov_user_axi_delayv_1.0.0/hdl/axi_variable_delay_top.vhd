--**********************************************************************************************************
-- Lawrence Livermore National Labs
-- 20191120 CM Initial creation 
-- axi_variable_delay_top.vhd:  Top-level module for the variable delay unit
--**********************************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.ext;


library axi_delay_lib;
use axi_delay_lib.axi_delay_pkg.all;
--use axi_delay_lib.chan_delay;
--use axi_delay_lib.short_hash;

library xpm;
use xpm.vcomponents.all;

entity axi_delay is

generic (
	C_FAMILY         : string := "rtl";
	C_AXI_PROTOCOL   : integer := P_AXI4;
	C_MEM_ADDR_WIDTH : integer := 30;
	C_COUNTER_WIDTH  : integer := 20;
	C_FIFO_DEPTH_AW  : integer := 0;
	C_FIFO_DEPTH_W   : integer := 0;
	C_FIFO_DEPTH_B   : integer := 0;
	C_FIFO_DEPTH_AR  : integer := 0;
	C_FIFO_DEPTH_R   : integer := 0;

	-- AXI-Lite Bus Interface
	C_AXI_LITE_ADDR_WIDTH : integer := 16;
	C_AXI_LITE_DATA_WIDTH : integer := 32;

	-- AXI-Full Bus Interface
	C_AXI_ID_WIDTH     : integer := 16;
	C_AXI_ADDR_WIDTH   : integer := 40;
	C_AXI_DATA_WIDTH   : integer := 128;
--	C_AXI_AWUSER_WIDTH : integer := 1; -- AXI4
--	C_AXI_ARUSER_WIDTH : integer := 1; -- AXI4
--	C_AXI_WUSER_WIDTH  : integer := 1; -- AXI4
--	C_AXI_RUSER_WIDTH  : integer := 1; -- AXI4
--	C_AXI_BUSER_WIDTH  : integer := 1 -- AXI4

    -- chan_delay_variable generics
    PRIORITY_QUEUE_WIDTH : integer := 16;
    DELAY_WIDTH          : integer := 24;
    CAM_DEPTH            : integer := 8;  -- depth of cam (i.e. number of entries), must be modulo 2.
    CAM_WIDTH            : integer := 16; -- maximum width of axi_id input. Requirement: CAMWIDTH <= NUM_MINI_BUFS
    NUM_MINI_BUFS        : integer := 64  -- number of minibufs; each must be sized to hold the largest packet size supported    
);

port (
	-- AXI-Lite Slave Bus Interface S_AXI_LITE
	s_axi_lite_aclk    : in  std_logic;
	s_axi_lite_aresetn : in  std_logic;
	--
	s_axi_lite_awaddr  : in  std_logic_vector(C_AXI_LITE_ADDR_WIDTH-1 downto 0) := (others => '0');
	s_axi_lite_awprot  : in  std_logic_vector(2 downto 0) := (others => '0');
	s_axi_lite_awvalid : in  std_logic;
	s_axi_lite_awready : out std_logic;
	--
	s_axi_lite_wdata   : in  std_logic_vector(C_AXI_LITE_DATA_WIDTH-1 downto 0) := (others => '0');
	s_axi_lite_wstrb   : in  std_logic_vector((C_AXI_LITE_DATA_WIDTH/8)-1 downto 0) := (others => '1');
	s_axi_lite_wvalid  : in  std_logic;
	s_axi_lite_wready  : out std_logic;
	--
	s_axi_lite_bresp   : out std_logic_vector(1 downto 0);
	s_axi_lite_bvalid  : out std_logic;
	s_axi_lite_bready  : in  std_logic;
	--
	s_axi_lite_araddr  : in  std_logic_vector(C_AXI_LITE_ADDR_WIDTH-1 downto 0) := (others => '0');
	s_axi_lite_arprot  : in  std_logic_vector(2 downto 0) := (others => '0');
	s_axi_lite_arvalid : in  std_logic;
	s_axi_lite_arready : out std_logic;
	--
	s_axi_lite_rdata   : out std_logic_vector(C_AXI_LITE_DATA_WIDTH-1 downto 0);
	s_axi_lite_rresp   : out std_logic_vector(1 downto 0);
	s_axi_lite_rvalid  : out std_logic;
	s_axi_lite_rready  : in  std_logic;

	----- AXI-Full Slave Bus Interface S_AXI -----
	s_axi_aclk     : in  std_logic;
	s_axi_aresetn  : in  std_logic;

	----- Slave Port: Write Address -----
	s_axi_awid     : in  std_logic_vector(C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
	s_axi_awaddr   : in  std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0) := (others => '0'); -- AXILITE
	s_axi_awlen    : in  std_logic_vector(AXI_LEN_WIDTH(C_AXI_PROTOCOL)-1 downto 0) := (others => '0'); -- AXI3 (3 downto 0), AXI4 (7 downto 0)
	s_axi_awsize   : in  std_logic_vector(2 downto 0) := std_logic_vector(to_unsigned(log2rp(C_AXI_DATA_WIDTH/8),3));
	s_axi_awburst  : in  std_logic_vector(1 downto 0) := (0 => '1', others => '0');
	s_axi_awlock   : in  std_logic_vector(AXI_LOCK_WIDTH(C_AXI_PROTOCOL)-1 downto 0) := (others => '0'); -- AXI3 (1 downto 0), AXI4 (0 downto 0)
	s_axi_awcache  : in  std_logic_vector(3 downto 0) := (others => '0');
	s_axi_awprot   : in  std_logic_vector(2 downto 0) := (others => '0'); -- AXILITE
	s_axi_awqos    : in  std_logic_vector(3 downto 0) := (others => '0'); -- AXI4
	s_axi_awregion : in  std_logic_vector(3 downto 0) := (others => '0'); -- AXI4
--	s_axi_awuser   : in  std_logic_vector(C_AXI_AWUSER_WIDTH-1 downto 0) := (others => '0'); -- AXI4
	s_axi_awvalid  : in  std_logic;
	s_axi_awready  : out std_logic;

	----- Slave Port:  Data -----
	s_axi_wid      : in  std_logic_vector(C_AXI_ID_WIDTH-1 downto 0) := (others => '0'); -- AXI3
	s_axi_wdata    : in  std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0) := (others => '0'); -- AXILITE
	s_axi_wstrb    : in  std_logic_vector((C_AXI_DATA_WIDTH/8)-1 downto 0) := (others => '1'); -- AXILITE
	s_axi_wlast    : in  std_logic := '1';
--	s_axi_wuser    : in  std_logic_vector(C_AXI_WUSER_WIDTH-1 downto 0) := (others => '0'); -- AXI4
	s_axi_wvalid   : in  std_logic;
	s_axi_wready   : out std_logic;

	----- Slave Port: Write Response -----
	s_axi_bid      : out std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);
	s_axi_bresp    : out std_logic_vector(1 downto 0); -- AXILITE
--	s_axi_buser    : out std_logic_vector(C_AXI_BUSER_WIDTH-1 downto 0); -- AXI4
	s_axi_bvalid   : out std_logic;
	s_axi_bready   : in  std_logic;

	----- Slave Port: Read Adress -----
	s_axi_arid     : in  std_logic_vector(C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
	s_axi_araddr   : in  std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0) := (others => '0'); -- AXILITE
	s_axi_arlen    : in  std_logic_vector(AXI_LEN_WIDTH(C_AXI_PROTOCOL)-1 downto 0) := (others => '0'); -- AXI3 (3 downto 0), AXI4 (7 downto 0)
	s_axi_arsize   : in  std_logic_vector(2 downto 0) := std_logic_vector(to_unsigned(log2rp(C_AXI_DATA_WIDTH/8),3));
	s_axi_arburst  : in  std_logic_vector(1 downto 0) := (0 => '1', others => '0');
	s_axi_arlock   : in  std_logic_vector(AXI_LOCK_WIDTH(C_AXI_PROTOCOL)-1 downto 0) := (others => '0'); -- AXI3 (1 downto 0), AXI4 (0 downto 0)
	s_axi_arcache  : in  std_logic_vector(3 downto 0) := (others => '0');
	s_axi_arprot   : in  std_logic_vector(2 downto 0) := (others => '0'); -- AXILITE
	s_axi_arqos    : in  std_logic_vector(3 downto 0) := (others => '0'); -- AXI4
	s_axi_arregion : in  std_logic_vector(3 downto 0) := (others => '0'); -- AXI4
--	s_axi_aruser   : in  std_logic_vector(C_AXI_ARUSER_WIDTH-1 downto 0) := (others => '0'); -- AXI4
	s_axi_arvalid  : in  std_logic;
	s_axi_arready  : out std_logic;

	----- Slave Port:  Data -----
	s_axi_rid      : out std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);
	s_axi_rdata    : out std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0); -- AXILITE
	s_axi_rresp    : out std_logic_vector(1 downto 0); -- AXILITE
	s_axi_rlast    : out std_logic;
--	s_axi_ruser    : out std_logic_vector(C_AXI_RUSER_WIDTH-1 downto 0); -- AXI4
	s_axi_rvalid   : out std_logic;
	s_axi_rready   : in  std_logic;

	----- AXI-Full Master Bus Interface M_AXI -----
	m_axi_aclk     : in  std_logic;
	m_axi_aresetn  : in  std_logic;

	----- Master Port: Write Adress -----
	m_axi_awid     : out std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);
	m_axi_awaddr   : out std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0); -- AXILITE
	m_axi_awlen    : out std_logic_vector(AXI_LEN_WIDTH(C_AXI_PROTOCOL)-1 downto 0); -- AXI3 (3 downto 0), AXI4 (7 downto 0)
	m_axi_awsize   : out std_logic_vector(2 downto 0);
	m_axi_awburst  : out std_logic_vector(1 downto 0);
	m_axi_awlock   : out std_logic_vector(AXI_LOCK_WIDTH(C_AXI_PROTOCOL)-1 downto 0); -- AXI3 (1 downto 0), AXI4 (0 downto 0)
	m_axi_awcache  : out std_logic_vector(3 downto 0);
	m_axi_awprot   : out std_logic_vector(2 downto 0); -- AXILITE
	m_axi_awqos    : out std_logic_vector(3 downto 0); -- AXI4
	m_axi_awregion : out std_logic_vector(3 downto 0); -- AXI4
--	m_axi_awuser   : out std_logic_vector(C_AXI_AWUSER_WIDTH-1 downto 0); -- AXI4
	m_axi_awvalid  : out std_logic;
	m_axi_awready  : in  std_logic;

	----- Master Port: Write Data -----
	m_axi_wid      : out std_logic_vector(C_AXI_ID_WIDTH-1 downto 0); -- AXI3
	m_axi_wdata    : out std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0); -- AXILITE
	m_axi_wstrb    : out std_logic_vector(C_AXI_DATA_WIDTH/8-1 downto 0); -- AXILITE
	m_axi_wlast    : out std_logic;
--	m_axi_wuser    : out std_logic_vector(C_AXI_WUSER_WIDTH-1 downto 0); -- AXI4
	m_axi_wvalid   : out std_logic;
	m_axi_wready   : in  std_logic;

	----- Master Port: Write Response -----
	m_axi_bid      : in  std_logic_vector(C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
	m_axi_bresp    : in  std_logic_vector(1 downto 0) := (others => '0'); -- AXILITE
--	m_axi_buser    : in  std_logic_vector(C_AXI_BUSER_WIDTH-1 downto 0) := (others => '0'); -- AXI4
	m_axi_bvalid   : in  std_logic;
	m_axi_bready   : out std_logic;
	--
	----- Master Port: Read Data -----
	m_axi_arid     : out std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);
	m_axi_araddr   : out std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0); -- AXILITE
	m_axi_arlen    : out std_logic_vector(AXI_LEN_WIDTH(C_AXI_PROTOCOL)-1 downto 0); -- AXI3 (3 downto 0), AXI4 (7 downto 0)
	m_axi_arsize   : out std_logic_vector(2 downto 0);
	m_axi_arburst  : out std_logic_vector(1 downto 0);
	m_axi_arlock   : out std_logic_vector(AXI_LOCK_WIDTH(C_AXI_PROTOCOL)-1 downto 0); -- AXI3 (1 downto 0), AXI4 (0 downto 0)
	m_axi_arcache  : out std_logic_vector(3 downto 0);
	m_axi_arprot   : out std_logic_vector(2 downto 0); -- AXILITE
	m_axi_arqos    : out std_logic_vector(3 downto 0); -- AXI4
	m_axi_arregion : out std_logic_vector(3 downto 0); -- AXI4
--	m_axi_aruser   : out std_logic_vector(C_AXI_ARUSER_WIDTH-1 downto 0); -- AXI4
	m_axi_arvalid  : out std_logic;
	m_axi_arready  : in  std_logic;

	----- Master Port: Read Data -----
	m_axi_rid      : in  std_logic_vector(C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
	m_axi_rdata    : in  std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0) := (others => '0'); -- AXILITE
	m_axi_rresp    : in  std_logic_vector(1 downto 0) := (others => '0'); -- AXILITE
	m_axi_rlast    : in  std_logic := '1';
--	m_axi_ruser    : in  std_logic_vector(C_AXI_RUSER_WIDTH-1 downto 0) := (others => '0'); -- AXI4
	m_axi_rvalid   : in  std_logic;
	m_axi_rready   : out std_logic
);

end axi_delay;

architecture behavioral of axi_delay is

--******************************************************************************
-- Constants
--******************************************************************************
constant NREG : integer := 3;
constant REG_ADDR_WIDTH : integer := log2rp(NREG);
constant WORD_LSB : integer := log2rp(C_AXI_LITE_DATA_WIDTH/8);

--******************************************************************************
--Signal Definitions
--******************************************************************************

subtype reg_addr_rng is natural range WORD_LSB+REG_ADDR_WIDTH-1 downto WORD_LSB;
subtype reg_rng is natural range 0 to NREG-1;

type reg_file is array(reg_rng) of std_logic_vector(C_AXI_LITE_DATA_WIDTH-1 downto 0);

-- clock domain crossing for registers is done in chan_delay
signal slv_reg : reg_file;

signal counter : std_logic_vector(C_COUNTER_WIDTH-1 downto 0);

-- AXI-Lite Slave Bus Interface S_AXI_LITE

signal s_axi_lite_awready_i : std_logic;
signal s_axi_lite_wready_i  : std_logic;
signal s_axi_lite_bvalid_i  : std_logic;

signal s_axi_lite_awaddr_r  : std_logic_vector(C_AXI_LITE_ADDR_WIDTH-1 downto 0);
signal s_axi_lite_awvalid_r : std_logic;
signal s_axi_lite_wdata_r   : std_logic_vector(C_AXI_LITE_DATA_WIDTH-1 downto 0);
signal s_axi_lite_wstrb_r   : std_logic_vector((C_AXI_LITE_DATA_WIDTH/8)-1 downto 0);
signal s_axi_lite_wvalid_r  : std_logic;

signal s_axi_lite_arready_i : std_logic;
signal s_axi_lite_rdata_i   : std_logic_vector(C_AXI_LITE_DATA_WIDTH-1 downto 0);
signal s_axi_lite_rvalid_i  : std_logic;

signal s_axi_lite_araddr_r  : std_logic_vector(C_AXI_LITE_ADDR_WIDTH-1 downto 0);
signal s_axi_lite_arvalid_r : std_logic;

signal s_axi_awaddr_i : std_logic_vector(C_MEM_ADDR_WIDTH-1 downto 0);
signal s_axi_araddr_i : std_logic_vector(C_MEM_ADDR_WIDTH-1 downto 0);
signal m_axi_awaddr_i : std_logic_vector(C_MEM_ADDR_WIDTH-1 downto 0);
signal m_axi_araddr_i : std_logic_vector(C_MEM_ADDR_WIDTH-1 downto 0);

signal s_axi_wlast_i : std_logic_vector(0 downto 0);
signal s_axi_rlast_i : std_logic_vector(0 downto 0);
signal m_axi_wlast_i : std_logic_vector(0 downto 0);
signal m_axi_rlast_i : std_logic_vector(0 downto 0);

-- signals added for decoder
signal r_decoder_input : std_logic_vector (1 downto 0);
signal w_decoder_input : std_logic_vector (1 downto 0);
signal r_chipsel       : std_logic_vector(3 downto 0);
signal w_chipsel       : std_logic_vector(3 downto 0);

-- Gaussian delay table initialization
signal gdt_b_wren      : std_logic_vector(0 downto 0);
signal gdt_b_waddr     : std_logic_vector(15 downto 0);
signal gdt_b_wdata     : std_logic_vector(23 downto 0);
signal gdt_b_raddr     : std_logic_vector(15 downto 0);
signal gdt_b_rdata     : std_logic_vector(23 downto 0);
signal gdt_b_addr      : std_logic_vector(15 downto 0);

signal gdt_r_wren      : std_logic_vector(0 downto 0);
signal gdt_r_waddr     : std_logic_vector(15 downto 0);
signal gdt_r_wdata     : std_logic_vector(23 downto 0);
signal gdt_r_raddr     : std_logic_vector(15 downto 0);
signal gdt_r_rdata     : std_logic_vector(23 downto 0);
signal gdt_r_addr      : std_logic_vector(15 downto 0);

function resize (arg: std_logic_vector; new_size: natural) return std_logic_vector is
	constant nau: std_logic_vector(0 downto 1) := (others => '0');
	constant arg_left: integer := arg'length-1;
	alias xarg: std_logic_vector(arg_left downto 0) is arg;
	variable result: std_logic_vector(new_size-1 downto 0) := (others => '0');
begin
	if (new_size < 1) then return nau; end if;
	if (xarg'length = 0) then return result; end if;
	if (result'length < arg'length) then
		result(result'left downto 0) := xarg(result'left downto 0);
	else
		result(result'left downto xarg'left+1) := (others => '0');
		result(xarg'left downto 0) := xarg;
	end if;
	return result;
end resize;

--******************************************************************************
-- Connectivity and Logic
--******************************************************************************

begin

	-- AMBA AXI and ACE Protocol Specification

	-- Section A3.2.1 - Handshake process
	-- 1) Transfer occurs only when both the VALID and READY signals are HIGH.
	-- 2) No combinatorial paths between input and output signals.
	-- 3) A source is not permitted to wait until READY is asserted before asserting VALID.
	-- 4) Once VALID is asserted it must remain asserted until the handshake occurs.
	-- 5) A destination is permitted to wait for VALID to be asserted before asserting READY.
	-- 6) If READY is asserted, it is permitted to deassert READY before VALID is asserted.

	-- Section A3.2.2 - Channel signaling requirements
	-- 1) The default state of AxREADY and xREADY can be either HIGH or LOW.
	-- 2) A default state of HIGH is recommended for AxREADY.
	-- 3) The source must assert the xLAST signal when it is driving the final transfer in the burst.

	-- Section A3.3.1 - Dependencies between channel handshake signals
	-- 1) (ARVALID & ARREADY) must be asserted before asserting RVALID.
	-- 2) (AWVALID & AWREADY) and (WVALID & WREADY & WLAST) must be asserted before asserting BVALID.

---------------------------------------
-- AXI-Lite slave address memory map
---------------------------------------
-- AXI Lite Memory Mapping:
--  r/w_chipsel(0) : 0x0000 - 0x3FFF -- control/status registers
--  r/w_chipsel(1) : 0x4000 - 0x7FFF -- gaussian delay table (B Channel)
--  r/w_chipsel(2) : 0x8000 - 0xBFFF -- gaussian delay table (R Channel)
--  r/w_chipsel(3) : 0xC000 - 0xFFFF -- spare

---------------------------------------
----- Chip select decoding - logic for decoding the chip selects for read and write processes
---------------------------------------
r_decoder_input <= s_axi_lite_araddr(C_AXI_LITE_ADDR_WIDTH-1 downto C_AXI_LITE_ADDR_WIDTH-2);
w_decoder_input <= s_axi_lite_awaddr(C_AXI_LITE_ADDR_WIDTH-1 downto C_AXI_LITE_ADDR_WIDTH-2);

r_decoder : process(r_decoder_input)
begin
	r_chipsel <= B"0000";
	case  r_decoder_input is
		when "00"   => r_chipsel <= B"0001";
		when "01"   => r_chipsel <= B"0010";
		when "10"   => r_chipsel <= B"0100";
		when others => r_chipsel <= B"0000";
	end case;
end process;

w_decoder : process(w_decoder_input)
begin
	w_chipsel <= B"0000";
	case  w_decoder_input is
		when "00"   => w_chipsel <= B"0001";
		when "01"   => w_chipsel <= B"0010";
		when "10"   => w_chipsel <= B"0100";
		when others => w_chipsel <= B"0000";
	end case;
end process;


--	s_axi_lite_awaddr
--	s_axi_lite_awprot
--	s_axi_lite_awvalid
	s_axi_lite_awready <= s_axi_lite_awready_i;
	--
--	s_axi_lite_wdata
--	s_axi_lite_wstrb
--	s_axi_lite_wvalid
	s_axi_lite_wready <= s_axi_lite_wready_i;
	--
	s_axi_lite_bresp  <= (others => '0');
	s_axi_lite_bvalid <= s_axi_lite_bvalid_i;
--	s_axi_lite_bready

	s_axi_lite_awready_i <= not s_axi_lite_awvalid_r;
	s_axi_lite_wready_i  <= not s_axi_lite_wvalid_r;
	s_axi_lite_bvalid_i  <= s_axi_lite_awvalid_r and s_axi_lite_wvalid_r;

	s_axil_w: process(s_axi_lite_aclk)
	begin
		if (rising_edge(s_axi_lite_aclk)) then
			if (s_axi_lite_aresetn = '0') then -- synchronous reset
				s_axi_lite_awaddr_r  <= (others => '0');
				s_axi_lite_awvalid_r <= '0';
				s_axi_lite_wdata_r   <= (others => '0');
				s_axi_lite_wstrb_r   <= (others => '0');
				s_axi_lite_wvalid_r  <= '0';
			else
				if (s_axi_lite_awvalid = '1' and s_axi_lite_awready_i = '1') then
					s_axi_lite_awaddr_r <= s_axi_lite_awaddr;
					s_axi_lite_awvalid_r <= '1';
				end if;
				if (s_axi_lite_wvalid = '1' and s_axi_lite_wready_i = '1') then
					s_axi_lite_wdata_r <= s_axi_lite_wdata;
					s_axi_lite_wstrb_r <= s_axi_lite_wstrb;
					s_axi_lite_wvalid_r <= '1';
				end if;
				if (s_axi_lite_bvalid_i = '1' and s_axi_lite_bready = '1') then
					s_axi_lite_awvalid_r <= '0';
					s_axi_lite_wvalid_r <= '0';
				end if;
			end if;
		end if;
	end process;

---------------------------------------
----- AXI-Lite slave memory write (register and BRAM) process
---------------------------------------

	s_axil_wr: process(s_axi_lite_aclk)
		variable rsel : reg_rng;
	begin
		if rising_edge(s_axi_lite_aclk) then
			if (s_axi_lite_aresetn = '0') then
				for i in reg_rng loop
					slv_reg(i) <= (others => '0');
				end loop;
			else 

    			gdt_r_wren   <= (others => '0');
	    		gdt_r_waddr  <= (others => '0');
		    	gdt_r_wdata  <= (others => '0');
			    gdt_b_wren   <= (others => '0');
			    gdt_b_waddr  <= (others => '0');
			    gdt_b_wdata  <= (others => '0');

				if (s_axi_lite_bvalid_i = '1') then

                    if (w_chipsel(0) = '1') then
                        rsel := to_integer(unsigned(s_axi_lite_awaddr_r(reg_addr_rng)));
                        case rsel is
                        when reg_rng'low to reg_rng'high =>
                            for bsel in 0 to (C_AXI_LITE_DATA_WIDTH/8-1) loop
                                if (s_axi_lite_wstrb_r(bsel) = '1') then
                                    slv_reg(rsel)(bsel*8+7 downto bsel*8) <= s_axi_lite_wdata_r(bsel*8+7 downto bsel*8);
                                end if;
                            end loop;
                        when others => null;
                        end case;
					end if;
					
					if (w_chipsel(1) = '1') then
						gdt_b_wren   <= (others => '1');
                        gdt_b_waddr  <= s_axi_lite_awaddr_r(15 downto 0);
						gdt_b_wdata  <= s_axi_lite_wdata_r(23 downto 0);
					end if;

					if (w_chipsel(2) = '1') then
						gdt_r_wren   <= (others => '1');
                        gdt_r_waddr  <= s_axi_lite_awaddr_r(15 downto 0);
						gdt_r_wdata  <= s_axi_lite_wdata_r(23 downto 0);
					end if;

				end if;
			end if;
		end if;
	end process;

---------------------------------------
----- AXI-Lite slave memory read (register and BRAM) process
---------------------------------------

--	s_axi_lite_araddr
--	s_axi_lite_arprot
--	s_axi_lite_arvalid
	s_axi_lite_arready <= s_axi_lite_arready_i;
	--
	s_axi_lite_rdata  <= s_axi_lite_rdata_i;
	s_axi_lite_rresp  <= (others => '0');
	s_axi_lite_rvalid <= s_axi_lite_rvalid_i;
--	s_axi_lite_rready

	s_axi_lite_arready_i <= not s_axi_lite_arvalid_r;
	s_axi_lite_rvalid_i  <= s_axi_lite_arvalid_r;

	s_axil_r: process(s_axi_lite_aclk)
	begin
		if (rising_edge(s_axi_lite_aclk)) then
			if (s_axi_lite_aresetn = '0') then -- synchronous reset
				s_axi_lite_araddr_r  <= (others => '0');
				s_axi_lite_arvalid_r <= '0';
			else
				if (s_axi_lite_arvalid = '1' and s_axi_lite_arready_i = '1') then
					s_axi_lite_araddr_r <= s_axi_lite_araddr;
					s_axi_lite_arvalid_r <= '1';
				end if;
				if (s_axi_lite_rvalid_i = '1' and s_axi_lite_rready = '1') then
					s_axi_lite_arvalid_r <= '0';
				end if;
			end if;
		end if;
	end process;

	c_axil_rr: process(s_axi_lite_rvalid_i, s_axi_lite_araddr_r, slv_reg)
		variable rsel : reg_rng;  begin
		s_axi_lite_rdata_i <= (others => '0');
		if (s_axi_lite_rvalid_i = '1') then

            if(r_chipsel(0) = '1') then
                rsel := to_integer(unsigned(s_axi_lite_araddr_r(reg_addr_rng)));
                case rsel is
                when reg_rng'low to reg_rng'high =>
                    s_axi_lite_rdata_i <= slv_reg(rsel);
                when others => null;
				end case;
			elsif (r_chipsel(1) = '1') then
				gdt_b_raddr        <= s_axi_lite_araddr_r(15 downto 0);
				s_axi_lite_rdata_i <= gdt_b_rdata;
			elsif (r_chipsel(2) = '1') then
				gdt_r_raddr        <= s_axi_lite_araddr_r(15 downto 0);
				s_axi_lite_rdata_i <= gdt_r_rdata;			
            else
                s_axi_lite_rdata_i <= (others=>'0');
			end if;

		end if;
	end process;

	-- wrap-around counter

	s_counter: process(s_axi_aclk)
	begin
		if (rising_edge(s_axi_aclk)) then
			if (s_axi_aresetn = '0') then
				counter <= (others => '0');
			else
				counter <= std_logic_vector(unsigned(counter) + 1);
			end if;
		end if;
	end process;

	-- AXI-Full

	s_axi_awaddr_i <= resize(s_axi_awaddr,  C_MEM_ADDR_WIDTH);
	s_axi_araddr_i <= resize(s_axi_araddr,  C_MEM_ADDR_WIDTH);
	m_axi_awaddr   <= resize(m_axi_awaddr_i,C_AXI_ADDR_WIDTH);
	m_axi_araddr   <= resize(m_axi_araddr_i,C_AXI_ADDR_WIDTH);

	s_axi_wlast_i(0) <= s_axi_wlast;
	s_axi_rlast      <= s_axi_rlast_i(0);
	m_axi_wlast      <= m_axi_wlast_i(0);
	m_axi_rlast_i(0) <= m_axi_rlast;

	gdt_r_addr <= gdt_r_waddr when (s_axi_lite_bvalid_i = '1') else gdt_r_raddr;
	gdt_b_addr <= gdt_b_waddr when (s_axi_lite_bvalid_i = '1') else gdt_b_raddr;

---------------------------------------
-- AW AXI Channel
---------------------------------------

i_aw: entity axi_delay_lib.chan_delay
    generic map (
	C_FAMILY        => C_FAMILY,
	C_COUNTER_WIDTH => C_COUNTER_WIDTH,
	C_FIFO_DEPTH    => C_FIFO_DEPTH_AW,
	C_00_USE        => ite(C_AXI_PROTOCOL /= P_AXILITE,1,0), -- awid
	C_01_USE        => 1,                                    -- awaddr -- AXILITE
	C_02_USE        => ite(C_AXI_PROTOCOL /= P_AXILITE,1,0), -- awlen
	C_03_USE        => ite(C_AXI_PROTOCOL /= P_AXILITE,1,0), -- awsize
	C_04_USE        => ite(C_AXI_PROTOCOL /= P_AXILITE,1,0), -- awburst
	C_05_USE        => ite(C_AXI_PROTOCOL /= P_AXILITE,1,0), -- awlock
	C_06_USE        => ite(C_AXI_PROTOCOL /= P_AXILITE,1,0), -- awcache
	C_07_USE        => 1,                                    -- awprot -- AXILITE
	C_08_USE        => ite(C_AXI_PROTOCOL = P_AXI4,1,0),     -- awqos -- AXI4
	C_09_USE        => ite(C_AXI_PROTOCOL = P_AXI4,1,0),     -- awregion -- AXI4
--	C_10_USE        => ite(C_AXI_PROTOCOL = P_AXI4,1,0),     -- awuser -- AXI4
	C_00_WIDTH      => s_axi_awid'length,
	C_01_WIDTH      => s_axi_awaddr_i'length,
	C_02_WIDTH      => s_axi_awlen'length,
	C_03_WIDTH      => s_axi_awsize'length,
	C_04_WIDTH      => s_axi_awburst'length,
	C_05_WIDTH      => s_axi_awlock'length,
	C_06_WIDTH      => s_axi_awcache'length,
	C_07_WIDTH      => s_axi_awprot'length,
	C_08_WIDTH      => s_axi_awqos'length, -- AXI4
	C_09_WIDTH      => s_axi_awregion'length -- AXI4
--	C_10_WIDTH      => s_axi_awuser'length -- AXI4
    )
    port map (
	dclk    => s_axi_lite_aclk,
	dresetn => s_axi_lite_aresetn,
	delay   => slv_reg(0)(C_COUNTER_WIDTH-1 downto 0), 
	aclk    => s_axi_aclk,
	aresetn => s_axi_aresetn,
	counter => counter, 
	s_00    => s_axi_awid,
	s_01    => s_axi_awaddr_i,
	s_02    => s_axi_awlen,
	s_03    => s_axi_awsize,
	s_04    => s_axi_awburst,
	s_05    => s_axi_awlock,
	s_06    => s_axi_awcache,
	s_07    => s_axi_awprot,
	s_08    => s_axi_awqos, -- AXI4
	s_09    => s_axi_awregion, -- AXI4
--	s_10    => s_axi_awuser, -- AXI4
	s_valid => s_axi_awvalid,
	s_ready => s_axi_awready,
	m_00    => m_axi_awid,
	m_01    => m_axi_awaddr_i,
	m_02    => m_axi_awlen,
	m_03    => m_axi_awsize,
	m_04    => m_axi_awburst,
	m_05    => m_axi_awlock,
	m_06    => m_axi_awcache,
	m_07    => m_axi_awprot,
	m_08    => m_axi_awqos, -- AXI4
	m_09    => m_axi_awregion, -- AXI4
--	m_10    => m_axi_awuser, -- AXI4
	m_valid => m_axi_awvalid,
	m_ready => m_axi_awready
    );

---------------------------------------
-- W AXI Channel
---------------------------------------

i_w: entity axi_delay_lib.chan_delay
    generic map (
	C_FAMILY        => C_FAMILY,
	C_COUNTER_WIDTH => C_COUNTER_WIDTH,
	C_FIFO_DEPTH    => C_FIFO_DEPTH_W,
	C_00_USE        => ite(C_AXI_PROTOCOL = P_AXI3,1,0),     -- wid -- AXI3
	C_01_USE        => 1,                                    -- wdata -- AXILITE
	C_02_USE        => 1,                                    -- wstrb -- AXILITE
	C_03_USE        => ite(C_AXI_PROTOCOL /= P_AXILITE,1,0), -- wlast
--	C_04_USE        => ite(C_AXI_PROTOCOL = P_AXI4,1,0),     -- wuser -- AXI4
	C_00_WIDTH      => s_axi_wid'length,
	C_01_WIDTH      => s_axi_wdata'length,
	C_02_WIDTH      => s_axi_wstrb'length,
	C_03_WIDTH      => s_axi_wlast_i'length
--	C_04_WIDTH      => s_axi_wuser'length -- AXI4
    )
    port map (
	dclk    => s_axi_lite_aclk,
	dresetn => s_axi_lite_aresetn,
	delay   => slv_reg(1)(C_COUNTER_WIDTH-1 downto 0), 
	aclk    => s_axi_aclk,
	aresetn => s_axi_aresetn,
	counter => counter, 
	s_00    => s_axi_wid,
	s_01    => s_axi_wdata,
	s_02    => s_axi_wstrb,
	s_03    => s_axi_wlast_i,
--	s_04    => s_axi_wuser, -- AXI4
	s_valid => s_axi_wvalid,
	s_ready => s_axi_wready,
	m_00    => m_axi_wid,
	m_01    => m_axi_wdata,
	m_02    => m_axi_wstrb,
	m_03    => m_axi_wlast_i,
--	m_04    => m_axi_wuser, -- AXI4
	m_valid => m_axi_wvalid,
	m_ready => m_axi_wready
    );
 
---------------------------------------
-- B AXI Channel
---------------------------------------

-----     i_b: entity chan_delay_fixed
-----         generic map (
-----     	C_FAMILY        => C_FAMILY,
-----     	C_COUNTER_WIDTH => C_COUNTER_WIDTH,
-----     	C_FIFO_DEPTH    => C_FIFO_DEPTH_B,
-----     	C_00_USE        => ite(C_AXI_PROTOCOL /= P_AXILITE,1,0), -- bid
-----     	C_01_USE        => 1,                                    -- bresp -- AXILITE
-----     --	C_02_USE        => ite(C_AXI_PROTOCOL = P_AXI4,1,0),     -- buser -- AXI4
-----     	C_00_WIDTH      => m_axi_bid'length,
-----     	C_01_WIDTH      => m_axi_bresp'length
-----     --	C_02_WIDTH      => m_axi_buser'length -- AXI4
-----     	)
-----     	port map (
-----     	dclk    => s_axi_lite_aclk,
-----     	dresetn => s_axi_lite_aresetn,
-----     	delay   => b_doutb_i(C_COUNTER_WIDTH-1 downto 0),
-----     	aclk    => m_axi_aclk,
-----     	aresetn => m_axi_aresetn,
-----     	counter => counter,
-----     	s_00    => m_axi_bid,
-----     	s_01    => m_axi_bresp,
-----     --	s_02    => m_axi_buser, -- AXI4
-----     	s_valid =>  m_axi_bvalid and b_m_axis_tap_tvalid,
-----     	s_ready => m_axi_bready_i,
-----     	m_00    => s_axi_bid,
-----     	m_01    => s_axi_bresp,
-----     --	m_02    => s_axi_buser, -- AXI4
-----     	m_valid => s_axi_bvalid,
-----     	m_ready => s_axi_bready
-----         );

i_b : entity axi_delay_lib.chan_delay_variable
generic map (
    CHANNEL_TYPE         => "B", -- valid values are:  AW, W, B, AR, R
    PRIORITY_QUEUE_WIDTH => PRIORITY_QUEUE_WIDTH,
    DELAY_WIDTH          => DELAY_WIDTH,

    C_AXI_ID_WIDTH       => C_AXI_ID_WIDTH,
    C_AXI_ADDR_WIDTH     => C_AXI_ADDR_WIDTH,
    C_AXI_DATA_WIDTH     => C_AXI_DATA_WIDTH,
    
    CAM_DEPTH            => CAM_DEPTH,
    CAM_WIDTH            => CAM_WIDTH,
    NUM_MINI_BUFS        => NUM_MINI_BUFS
)
port map (
    --------------------------------------------
    ----- AXI Slave Interface ---
    --------------------------------------------
    s_axi_aclk    => s_axi_aclk,
    s_axi_aresetn => s_axi_aresetn,
								
    s_axi_id      => m_axi_bid,     			
    s_axi_addr    => (others => '0'),   		
    s_axi_data    => (others => '0'),   		
    s_axi_strb    => (others => '0'),   		
    s_axi_len     => (others => '0'),    		
    s_axi_size    => (others => '0'),   		
    s_axi_burst   => (others => '0'),  			
    s_axi_lock    => (others => '0'),   		
    s_axi_cache   => (others => '0'),  			
    s_axi_prot    => (others => '0'),   		
    s_axi_qos     => (others => '0'),    		
    s_axi_region  => (others => '0'), 			
    s_axi_valid   => m_axi_bvalid,
    s_axi_ready   => m_axi_bready,
    					
    s_axi_last    => '0',   			
    s_axi_resp    => m_axi_bresp,

    --------------------------------------------
    ----- AXI Master Interface ---
    --------------------------------------------
    m_axi_aclk    => m_axi_aclk,
    m_axi_aresetn => m_axi_aresetn,

    m_axi_id      => s_axi_bid,   
    m_axi_addr    => OPEN,  
    m_axi_data    => OPEN, 
    m_axi_strb    => OPEN,  
    m_axi_len     => OPEN,   
    m_axi_size    => OPEN,  
    m_axi_burst   => OPEN, 
    m_axi_lock    => OPEN,  
    m_axi_cache   => OPEN, 
    m_axi_prot    => OPEN,  
    m_axi_qos     => OPEN,   
    m_axi_region  => OPEN, 
    m_axi_valid   => s_axi_bvalid,  
    m_axi_ready   => s_axi_bready,  
 
    m_axi_last    => OPEN,   
    m_axi_resp    => s_axi_bresp,   

    ----- Guassian delay table initialization port	
	gdt_wren_i       => gdt_b_wren,
    gdt_addr_i       => gdt_b_addr,
	gdt_wdata_i      => gdt_b_wdata,
	gdt_rdata_o      => gdt_b_rdata,
    
    ----- AW (address write) ID output to W (write) ID input	
    aw_id_o       => OPEN,
    w_last_i      => '0',
    w_last_o      => OPEN,
    w_id_i        => (others => '0')
);

---------------------------------------
-- AR AXI Channel
---------------------------------------

i_ar: entity axi_delay_lib.chan_delay
    generic map (
	C_FAMILY        => C_FAMILY,
	C_COUNTER_WIDTH => C_COUNTER_WIDTH,
	C_FIFO_DEPTH    => C_FIFO_DEPTH_AR,
	C_00_USE        => ite(C_AXI_PROTOCOL /= P_AXILITE,1,0), -- arid
	C_01_USE        => 1,                                    -- araddr -- AXILITE
	C_02_USE        => ite(C_AXI_PROTOCOL /= P_AXILITE,1,0), -- arlen
	C_03_USE        => ite(C_AXI_PROTOCOL /= P_AXILITE,1,0), -- arsize
	C_04_USE        => ite(C_AXI_PROTOCOL /= P_AXILITE,1,0), -- arburst
	C_05_USE        => ite(C_AXI_PROTOCOL /= P_AXILITE,1,0), -- arlock
	C_06_USE        => ite(C_AXI_PROTOCOL /= P_AXILITE,1,0), -- arcache
	C_07_USE        => 1,                                    -- arprot -- AXILITE
	C_08_USE        => ite(C_AXI_PROTOCOL = P_AXI4,1,0),     -- arqos -- AXI4
	C_09_USE        => ite(C_AXI_PROTOCOL = P_AXI4,1,0),     -- arregion -- AXI4
--	C_10_USE        => ite(C_AXI_PROTOCOL = P_AXI4,1,0),     -- aruser -- AXI4
	C_00_WIDTH      => s_axi_arid'length,
	C_01_WIDTH      => s_axi_araddr_i'length,
	C_02_WIDTH      => s_axi_arlen'length,
	C_03_WIDTH      => s_axi_arsize'length,
	C_04_WIDTH      => s_axi_arburst'length,
	C_05_WIDTH      => s_axi_arlock'length,
	C_06_WIDTH      => s_axi_arcache'length,
	C_07_WIDTH      => s_axi_arprot'length,
	C_08_WIDTH      => s_axi_arqos'length, -- AXI4
	C_09_WIDTH      => s_axi_arregion'length -- AXI4
--	C_10_WIDTH      => s_axi_aruser'length -- AXI4
    )
    port map (
	dclk    => s_axi_lite_aclk,
	dresetn => s_axi_lite_aresetn,
	delay   => slv_reg(2)(C_COUNTER_WIDTH-1 downto 0),
	aclk    => s_axi_aclk,
	aresetn => s_axi_aresetn,
	counter => counter,
	s_00    => s_axi_arid,
	s_01    => s_axi_araddr_i,
	s_02    => s_axi_arlen,
	s_03    => s_axi_arsize,
	s_04    => s_axi_arburst,
	s_05    => s_axi_arlock,
	s_06    => s_axi_arcache,
	s_07    => s_axi_arprot,
	s_08    => s_axi_arqos, -- AXI4
	s_09    => s_axi_arregion, -- AXI4
--	s_10    => s_axi_aruser, -- AXI4
	s_valid => s_axi_arvalid,
	s_ready => s_axi_arready,
	m_00    => m_axi_arid,
	m_01    => m_axi_araddr_i,
	m_02    => m_axi_arlen,
	m_03    => m_axi_arsize,
	m_04    => m_axi_arburst,
	m_05    => m_axi_arlock,
	m_06    => m_axi_arcache,
	m_07    => m_axi_arprot,
	m_08    => m_axi_arqos, -- AXI4
	m_09    => m_axi_arregion, -- AXI4
--	m_10    => m_axi_aruser, -- AXI4
	m_valid => m_axi_arvalid,
	m_ready => m_axi_arready
    ); 

---------------------------------------
-- R AXI Channel
---------------------------------------

-----     	i_r: entity chan_delay
-----     	generic map (
-----     	C_FAMILY        => C_FAMILY,
-----     	C_COUNTER_WIDTH => C_COUNTER_WIDTH,
-----     	C_FIFO_DEPTH    => C_FIFO_DEPTH_R,
-----     	C_00_USE        => ite(C_AXI_PROTOCOL /= P_AXILITE,1,0), -- rid
-----     	C_01_USE        => 1,                                    -- rdata -- AXILITE
-----     	C_02_USE        => 1,                                    -- rresp -- AXILITE
-----     	C_03_USE        => ite(C_AXI_PROTOCOL /= P_AXILITE,1,0), -- rlast
-----     --	C_04_USE        => ite(C_AXI_PROTOCOL = P_AXI4,1,0),     -- ruser -- AXI4
-----     	C_00_WIDTH      => m_axi_rid'length,
-----     	C_01_WIDTH      => m_axi_rdata'length,
-----     	C_02_WIDTH      => m_axi_rresp'length,
-----     	C_03_WIDTH      => m_axi_rlast_i'length
-----     --	C_04_WIDTH      => m_axi_ruser'length -- AXI4
-----     	)
-----     	port map (
-----     	dclk    => s_axi_lite_aclk,
-----     	dresetn => s_axi_lite_aresetn,
-----     	delay   => r_doutb_i(C_COUNTER_WIDTH-1 downto 0),
-----     	aclk    => m_axi_aclk,
-----     	aresetn => m_axi_aresetn,
-----     	counter => counter,
-----     	s_00    => m_axi_rid,
-----     	s_01    => m_axi_rdata,
-----     	s_02    => m_axi_rresp,
-----     	s_03    => m_axi_rlast_i,
-----     --	s_04    => m_axi_ruser, -- AXI4
-----     	s_valid => m_axi_rvalid and r_m_axis_tap_tvalid,
-----     	s_ready => m_axi_rready_i,
-----     	m_00    => s_axi_rid,
-----     	m_01    => s_axi_rdata,
-----     	m_02    => s_axi_rresp,
-----     	m_03    => s_axi_rlast_i,
-----     --	m_04    => s_axi_ruser, -- AXI4
-----     	m_valid => s_axi_rvalid,
-----     	m_ready => s_axi_rready
-----     	);    

i_r : entity axi_delay_lib.chan_delay_variable
generic map (
    CHANNEL_TYPE         => "R", -- valid values are:  AW, W, B, AR, R
    PRIORITY_QUEUE_WIDTH => PRIORITY_QUEUE_WIDTH,
    DELAY_WIDTH          => DELAY_WIDTH,

    C_AXI_ID_WIDTH       => C_AXI_ID_WIDTH,
    C_AXI_ADDR_WIDTH     => C_AXI_ADDR_WIDTH,
    C_AXI_DATA_WIDTH     => C_AXI_DATA_WIDTH,
    
    CAM_DEPTH            => CAM_DEPTH,
    CAM_WIDTH            => CAM_WIDTH,
    NUM_MINI_BUFS        => NUM_MINI_BUFS
)
port map (
    --------------------------------------------
    ----- AXI Slave Interface ---
    --------------------------------------------
    s_axi_aclk    => s_axi_aclk,
    s_axi_aresetn => s_axi_aresetn,
								
    s_axi_id      => m_axi_rid,     				
    s_axi_addr    => (others => '0'),   				
    s_axi_data    => m_axi_rdata,   				
    s_axi_strb    => (others => '0'),   				
    s_axi_len     => (others => '0'),    				 
    s_axi_size    => (others => '0'),   				 
    s_axi_burst   => (others => '0'),  				 
    s_axi_lock    => (others => '0'),   				 
    s_axi_cache   => (others => '0'),  				 
    s_axi_prot    => (others => '0'),   				 
    s_axi_qos     => (others => '0'),    				 
    s_axi_region  => (others => '0'), 				 
    s_axi_valid   => m_axi_aclk, --m_axi_rvalid and r_m_axis_tap_tvalid,  
    s_axi_ready   => m_axi_rready, --m_axi_rready_i,  
    
    s_axi_last    => m_axi_rlast_i(0),
    s_axi_resp    => m_axi_rresp,   

    --------------------------------------------
    ----- AXI Master Interface ---
    --------------------------------------------
    m_axi_aclk    => m_axi_aclk,
    m_axi_aresetn => m_axi_aresetn,

    m_axi_id      => s_axi_rid,   
    m_axi_addr    => OPEN,  
    m_axi_data    => s_axi_rdata, 
    m_axi_strb    => OPEN,  
    m_axi_len     => OPEN,   
    m_axi_size    => OPEN,  
    m_axi_burst   => OPEN, 
    m_axi_lock    => OPEN,  
    m_axi_cache   => OPEN, 
    m_axi_prot    => OPEN,  
    m_axi_qos     => OPEN,   
    m_axi_region  => OPEN, 
    m_axi_valid   => s_axi_rvalid,  
    m_axi_ready   => s_axi_rready,  
 
    m_axi_last    => s_axi_rlast_i(0),   
    m_axi_resp    => s_axi_rresp,   

    ----- Guassian delay table initialization port	
	gdt_wren_i       => gdt_r_wren,
    gdt_addr_i       => gdt_r_addr,
	gdt_wdata_i      => gdt_r_wdata,
	gdt_rdata_o      => gdt_r_rdata,
	
	----- AW (address write) ID output to W (write) ID input	
    aw_id_o       => OPEN,
    w_last_i      => '0',
    w_last_o      => OPEN,
    w_id_i        => (others => '0')
);

end behavioral;
