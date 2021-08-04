--**********************************************************************************************************
-- Lawrence Livermore National Labs
-- 20200215 CM Initial creation 
-- chan_delay_variable.vhd:  Top level for Channel Delay module.
--**********************************************************************************************************

library IEEE;
--synopsys translate_off
library unisim;
--synopsys translate_on

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;

library axi_delay_lib;
use axi_delay_lib.all;
use axi_delay_lib.axi_delay_pkg.all;

entity chan_delay_variable is
generic (
    SIMULATION           : std_logic := '0';
    CHANNEL_TYPE         : string  := "AW" ; -- valid values are:  AW, W, B, AR, R
    PRIORITY_QUEUE_WIDTH : integer := 16;
    DELAY_WIDTH          : integer := 24;

    -- AXI-Full Bus Interface
    C_AXI_ID_WIDTH       : integer := 16;
    C_AXI_ADDR_WIDTH     : integer := 40;
    C_AXI_DATA_WIDTH     : integer := 128;
    
    -- AXI Information FIFO
    AXI_INFO_WIDTH       : integer := 192;
    AXI_INFO_DEPTH       : integer := 32;
    
    GDT_FILENAME         : string := "bram_del_table.mem";
    GDT_ADDR_BITS        : integer := 8;
    GDT_DATA_BITS        : integer := 24;

    -- minicam and packet buffer generics
    BYPASS_MINICAM       : integer := 1;
    CAM_DEPTH            : integer := 8;  -- depth of cam (i.e. number of entries), must be modulo 2.
    CAM_WIDTH            : integer := 16; -- maximum width of axi_id input. Requirement: CAMWIDTH <= NUM_MINI_BUFS
    NUM_EVENTS_PER_MBUF  : integer := 32;  -- maximum number of events each minibuffer can hold
    NUM_MINI_BUFS        : integer := 64  -- number of minibufs; each must be sized to hold the largest packet size supported
);
port (
    --------------------------------------------
    ----- AXI Slave Interface ---
    --------------------------------------------
    s_axi_aclk    : in  std_logic;
    s_axi_aresetn : in  std_logic;
    counter       : in  std_logic_vector(DELAY_WIDTH-1 downto 0);
    
    -- Slave AXI Interface --
    s_axi_id      : in  std_logic_vector(C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
    s_axi_addr    : in  std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');
    s_axi_data    : in  std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0) := (others => '0'); 
    s_axi_strb    : in  std_logic_vector((C_AXI_DATA_WIDTH/8)-1 downto 0) := (others => '1');
    s_axi_len     : in  std_logic_vector(7 downto 0) := (others => '0');
    s_axi_size    : in  std_logic_vector(2 downto 0) := "110";
    s_axi_burst   : in  std_logic_vector(1 downto 0) := "01";
    s_axi_lock    : in  std_logic_vector(1 downto 0) := (others => '0');
    s_axi_cache   : in  std_logic_vector(3 downto 0) := (others => '0');
    s_axi_prot    : in  std_logic_vector(2 downto 0) := (others => '0'); 
    s_axi_qos     : in  std_logic_vector(3 downto 0) := (others => '0'); 
    s_axi_region  : in  std_logic_vector(3 downto 0) := (others => '0');
    s_axi_valid   : in  std_logic;
    s_axi_ready   : out std_logic;
    
    s_axi_last    : in  std_logic;
    s_axi_resp    : in  std_logic_vector(1 downto 0); 

    --------------------------------------------
    ----- AXI Master Interface ---
    --------------------------------------------
    m_axi_aclk    : in  std_logic;
    m_axi_aresetn : in  std_logic;
    
    m_axi_id      : out std_logic_vector(C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
    m_axi_addr    : out std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');
    m_axi_data    : out std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0) := (others => '0'); 
    m_axi_strb    : out std_logic_vector((C_AXI_DATA_WIDTH/8)-1 downto 0) := (others => '1'); 
    m_axi_len     : out std_logic_vector(7 downto 0) := (others => '0'); 
    m_axi_size    : out std_logic_vector(2 downto 0) := "110";
    m_axi_burst   : out std_logic_vector(1 downto 0) := "01";
    m_axi_lock    : out std_logic_vector(1 downto 0) := (others => '0');
    m_axi_cache   : out std_logic_vector(3 downto 0) := (others => '0');
    m_axi_prot    : out std_logic_vector(2 downto 0) := (others => '0');
    m_axi_qos     : out std_logic_vector(3 downto 0) := (others => '0');
    m_axi_region  : out std_logic_vector(3 downto 0) := (others => '0');
    m_axi_valid   : out std_logic;
    m_axi_ready   : in  std_logic;
    
    m_axi_last    : out std_logic;
    m_axi_resp    : out std_logic_vector(1 downto 0);

    ----- Guassian delay table initialization port	
    dclk_i        : in  std_logic;
    dresetn_i     : in  std_logic;
    gdt_wren_i    : in  std_logic_vector(0 downto 0);
    gdt_addr_i    : in  std_logic_vector(15 downto 0); 
    gdt_wdata_i   : in  std_logic_vector(23 downto 0);
    gdt_rdata_o   : out std_logic_vector(23 downto 0);
    pwclt_reg     : in std_logic_vector(23 downto 0);
    pwclt_calib_reg     : in std_logic_vector(23 downto 0);
    grng_output   : in std_logic_vector(17-1 downto 0)
);

end chan_delay_variable;

architecture chan_delay_variable of chan_delay_variable is

--******************************************************************************
-- Constants
--******************************************************************************
constant C_DATA_LEN        : integer := 150; --length of pl_dly_din variable, i.e. depth of pl
constant MINIBUF_IDX_WIDTH : integer := log2rp(NUM_MINI_BUFS);
constant CTR_PTR_WIDTH     : integer := MINIBUF_IDX_WIDTH + log2rp(NUM_EVENTS_PER_MBUF); -- indexes into (i.e. addresses) the packet buffer. Minimum depth of Packet Buffer DPRAM = 2^(CTR_PTR_WIDTH)

-- Note: assuming maximum width defined by C_AXI_ID_WIDTH = 16 and C_AXI_DATA_WIDTH = 128 (C_AXI_DATA_WIDTH/8 = 16) and misc (32) = 192
--constant AXI_INFO_WIDTH    : integer := C_AXI_ID_WIDTH + C_AXI_DATA_WIDTH + C_AXI_ADDR_WIDTH + C_AXI_DATA_WIDTH/8 + 
--                                    8 + 3 + 2 + 2 + 4 + 3 + 4 + 4 + 1 + 1 + 2;

constant C_ZERO    : std_logic_vector(1023 downto 0) := (others => '0');
constant C_ZERO_16 : std_logic_vector(15 downto 0) := (others => '0');

constant C_SIGN_FACTOR                      : std_logic_vector(17 downto 0) := "001000000000000000";
constant C_ONE_BOOL                         : std_logic := '1';
constant C_ZERO_BOOL                        : std_logic := '0';
-- These were without the 187.5/300 clock scaling
-- constant C_TRUNCATION_FACTOR_DIV4_MU_72     : std_logic_vector(19 downto 0) := x"00480";
-- constant C_TRUNCATION_FACTOR_DIV4_MU_216    : std_logic_vector(19 downto 0) := x"00D80";
-- constant C_TRUNCATION_FACTOR_DIV4_MU_366    : std_logic_vector(19 downto 0) := x"016E0";
-- constant C_TRUNCATION_FACTOR_DIV4_MU_492    : std_logic_vector(19 downto 0) := x"01EC0";
-- constant C_TRUNCATION_FACTOR_DIV4_MU_510    : std_logic_vector(19 downto 0) := x"01FE0";
-- constant C_TRUNCATION_FACTOR_DIV4_MU_636    : std_logic_vector(19 downto 0) := x"027C0";
-- constant C_TRUNCATION_FACTOR_DIV4_MU_1056   : std_logic_vector(19 downto 0) := x"04200";
-- constant C_TRUNCATION_FACTOR_DIV4_MU_1200   : std_logic_vector(19 downto 0) := x"04B00";
-- constant C_TRUNCATION_FACTOR_DIV4_MU_2256   : std_logic_vector(19 downto 0) := x"08D00";
-- constant C_TRUNCATION_FACTOR_DIV4_MU_2400   : std_logic_vector(19 downto 0) := x"09600";
-- constant C_MU_72                            : std_logic_vector(31 downto 0) := x"00910000";
-- constant C_MU_216                           : std_logic_vector(31 downto 0) := x"01B10000";
-- constant C_MU_366                           : std_logic_vector(31 downto 0) := x"02DD0000";
-- constant C_MU_492                           : std_logic_vector(31 downto 0) := x"03D90000";
-- constant C_MU_510                           : std_logic_vector(31 downto 0) := x"03FD0000";
-- constant C_MU_636                           : std_logic_vector(31 downto 0) := x"04F90000";
-- constant C_MU_1056                          : std_logic_vector(31 downto 0) := x"08410000";
-- constant C_MU_1200                          : std_logic_vector(31 downto 0) := x"09610000";
-- constant C_MU_2256                          : std_logic_vector(31 downto 0) := x"11A10000";
-- constant C_MU_2400                          : std_logic_vector(31 downto 0) := x"12C10000";
-- After 187.5/300 clock scaling
constant C_TRUNCATION_FACTOR_DIV4_MU_72     : std_logic_vector(19 downto 0) := x"002D0";
constant C_TRUNCATION_FACTOR_DIV4_MU_216    : std_logic_vector(19 downto 0) := x"00870";
constant C_TRUNCATION_FACTOR_DIV4_MU_366    : std_logic_vector(19 downto 0) := x"00E50";
constant C_TRUNCATION_FACTOR_DIV4_MU_492    : std_logic_vector(19 downto 0) := x"01340";
constant C_TRUNCATION_FACTOR_DIV4_MU_510    : std_logic_vector(19 downto 0) := x"013F0";
constant C_TRUNCATION_FACTOR_DIV4_MU_636    : std_logic_vector(19 downto 0) := x"018E0";
constant C_TRUNCATION_FACTOR_DIV4_MU_1056   : std_logic_vector(19 downto 0) := x"02940";
constant C_TRUNCATION_FACTOR_DIV4_MU_1200   : std_logic_vector(19 downto 0) := x"02EE0";
constant C_TRUNCATION_FACTOR_DIV4_MU_2256   : std_logic_vector(19 downto 0) := x"05050";
constant C_TRUNCATION_FACTOR_DIV4_MU_2400   : std_logic_vector(19 downto 0) := x"05DC0";
constant C_TRUNCATION_FACTOR_DIV8_MU_72     : std_logic_vector(19 downto 0) := x"00168";
constant C_TRUNCATION_FACTOR_DIV8_MU_216    : std_logic_vector(19 downto 0) := x"00438";
constant C_TRUNCATION_FACTOR_DIV8_MU_366    : std_logic_vector(19 downto 0) := x"00728";
constant C_TRUNCATION_FACTOR_DIV8_MU_492    : std_logic_vector(19 downto 0) := x"009A0";
constant C_TRUNCATION_FACTOR_DIV8_MU_510    : std_logic_vector(19 downto 0) := x"009F8";
constant C_TRUNCATION_FACTOR_DIV8_MU_636    : std_logic_vector(19 downto 0) := x"00C70";
constant C_TRUNCATION_FACTOR_DIV8_MU_1056   : std_logic_vector(19 downto 0) := x"014A0";
constant C_TRUNCATION_FACTOR_DIV8_MU_1200   : std_logic_vector(19 downto 0) := x"01770";
constant C_TRUNCATION_FACTOR_DIV8_MU_2256   : std_logic_vector(19 downto 0) := x"02828";
constant C_TRUNCATION_FACTOR_DIV8_MU_2400   : std_logic_vector(19 downto 0) := x"02EE0";
constant C_TRUNCATION_FACTOR_DIV16_MU_72    : std_logic_vector(19 downto 0) := x"000B4";
constant C_TRUNCATION_FACTOR_DIV16_MU_216   : std_logic_vector(19 downto 0) := x"0021C";
constant C_TRUNCATION_FACTOR_DIV16_MU_366   : std_logic_vector(19 downto 0) := x"00394";
constant C_TRUNCATION_FACTOR_DIV16_MU_492   : std_logic_vector(19 downto 0) := x"004D0";
constant C_TRUNCATION_FACTOR_DIV16_MU_510   : std_logic_vector(19 downto 0) := x"004FC";
constant C_TRUNCATION_FACTOR_DIV16_MU_636   : std_logic_vector(19 downto 0) := x"00638";
constant C_TRUNCATION_FACTOR_DIV16_MU_1056  : std_logic_vector(19 downto 0) := x"00A50";
constant C_TRUNCATION_FACTOR_DIV16_MU_1200  : std_logic_vector(19 downto 0) := x"00BB8";
constant C_TRUNCATION_FACTOR_DIV16_MU_2256  : std_logic_vector(19 downto 0) := x"01414";
constant C_TRUNCATION_FACTOR_DIV16_MU_2400  : std_logic_vector(19 downto 0) := x"01770";
constant C_TRUNCATION_FACTOR_DIV32_MU_72    : std_logic_vector(19 downto 0) := x"0005A";
constant C_TRUNCATION_FACTOR_DIV32_MU_216   : std_logic_vector(19 downto 0) := x"0010E";
constant C_TRUNCATION_FACTOR_DIV32_MU_366   : std_logic_vector(19 downto 0) := x"001CA";
constant C_TRUNCATION_FACTOR_DIV32_MU_492   : std_logic_vector(19 downto 0) := x"00268";
constant C_TRUNCATION_FACTOR_DIV32_MU_510   : std_logic_vector(19 downto 0) := x"0027E";
constant C_TRUNCATION_FACTOR_DIV32_MU_636   : std_logic_vector(19 downto 0) := x"0031C";
constant C_TRUNCATION_FACTOR_DIV32_MU_1056  : std_logic_vector(19 downto 0) := x"00528";
constant C_TRUNCATION_FACTOR_DIV32_MU_1200  : std_logic_vector(19 downto 0) := x"005DC";
constant C_TRUNCATION_FACTOR_DIV32_MU_2256  : std_logic_vector(19 downto 0) := x"00A0A";
constant C_TRUNCATION_FACTOR_DIV32_MU_2400  : std_logic_vector(19 downto 0) := x"00BB8";
constant C_MU_72                            : std_logic_vector(31 downto 0) := x"005B0000";
constant C_MU_216                           : std_logic_vector(31 downto 0) := x"010F0000";
constant C_MU_366                           : std_logic_vector(31 downto 0) := x"01CB0000";
constant C_MU_492                           : std_logic_vector(31 downto 0) := x"02690000";
constant C_MU_510                           : std_logic_vector(31 downto 0) := x"027F0000";
constant C_MU_636                           : std_logic_vector(31 downto 0) := x"031D0000";
constant C_MU_1056                          : std_logic_vector(31 downto 0) := x"05290000";
constant C_MU_1200                          : std_logic_vector(31 downto 0) := x"05DD0000";
constant C_MU_2256                          : std_logic_vector(31 downto 0) := x"0A0B0000";
constant C_MU_2400                          : std_logic_vector(31 downto 0) := x"0BB90000";

--******************************************************************************
--Signal Definitions
--******************************************************************************
signal random_dly     : std_logic_vector(DELAY_WIDTH-1 downto 0);
signal random_dly_buf : std_logic_vector(DELAY_WIDTH-1 downto 0);
signal random_dly_req : std_logic;
signal s_time         : std_logic_vector(DELAY_WIDTH-1 downto 0);

signal s_axi_areset   : std_logic;
signal m_axi_areset   : std_logic;

signal pktbuf_enb     : std_logic;
signal pktbuf_addrb   : std_logic_vector(CTR_PTR_WIDTH-1 downto 0);
signal pktbuf_dinb    : std_logic_vector(AXI_INFO_WIDTH-1 downto 0); 
signal pktbuf_doutb   : std_logic_vector(AXI_INFO_WIDTH-1 downto 0); 

signal mc_valid       : std_logic;
signal mc_axi_id      : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);
signal mc_last        : std_logic;
signal mc_ctr_ptr     : std_logic_vector(CTR_PTR_WIDTH-1 downto 0);
signal mc_ctr_ptr_wr  : std_logic;

signal aidb_id            : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);
signal aidb_id_zero       : std_logic_vector(15 downto 0);
signal aidb_cntr_ptr_base : std_logic_vector(MINIBUF_IDX_WIDTH-1 downto 0);
signal aidb_wr            : std_logic_vector(0 downto 0);

signal aidb_baddr         : std_logic_vector(MINIBUF_IDX_WIDTH-1 downto 0);
signal aidb_bdata_zero    : std_logic_vector(15 downto 0);
signal aidb_bdata         : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);

signal pb_info_data       : std_logic_vector(AXI_INFO_WIDTH-1 downto 0);
signal pb_cntr_ptr        : std_logic_vector(CTR_PTR_WIDTH-1 downto 0);
signal pb_wr              : std_logic_vector(0 downto 0);

signal minibuf_fe         : std_logic;
signal free_ctrptr_wr     : std_logic;
signal free_ctrptr        : std_logic_vector(CTR_PTR_WIDTH-1 downto 0); 

signal minicam_full       : std_logic;
signal available_ctrptr   : std_logic;
signal minicam_err        : std_logic;

signal axi_info_valid     : std_logic;
signal axi_info_data      : std_logic_vector(AXI_INFO_WIDTH-1 downto 0);

signal pq_data            : std_logic_vector(C_AXI_ID_WIDTH+MINIBUF_IDX_WIDTH-1 downto 0);
signal pq_data_complete   : std_logic_vector(DELAY_WIDTH+C_AXI_ID_WIDTH+MINIBUF_IDX_WIDTH-1 downto 0);
signal pq_en              : std_logic;
signal pq_ready           : std_logic;
signal pq_dout            : std_logic_vector(DELAY_WIDTH+C_AXI_ID_WIDTH+MINIBUF_IDX_WIDTH-1 downto 0);
signal pq_dout_valid      : std_logic;
signal pq_dout_ready      : std_logic;
signal pq_data_sr         : std_logic_vector(PRIORITY_QUEUE_WIDTH*(DELAY_WIDTH+C_AXI_ID_WIDTH+MINIBUF_IDX_WIDTH)-1 downto 0);

signal grng_output_m      : std_logic_vector(37-1 downto 0);
signal grng_output_a      : std_logic_vector(37-1 downto 0);

signal random_dly_gdt     : std_logic_vector(DELAY_WIDTH-1 downto 0);
signal random_dly_pwclt_0 : std_logic_vector(DELAY_WIDTH-1 downto 0);
signal random_dly_pwclt_1 : std_logic_vector(DELAY_WIDTH-1 downto 0);
signal random_dly_pwclt_2 : std_logic_vector(DELAY_WIDTH-1 downto 0);
signal addition_factor    : std_logic_vector(32-1 downto 0);
signal truncation_factor  : std_logic_vector(20-1 downto 0);
signal random_dly_clip    : std_logic_vector(DELAY_WIDTH-1 downto 0);

--------------------------------------------------------------------------------
-- attribute mark_debug : string;

-- attribute mark_debug of pb_wr         : signal is "true";
-- attribute mark_debug of pb_cntr_ptr   : signal is "true";
-- attribute mark_debug of pktbuf_enb    : signal is "true";
-- attribute mark_debug of pktbuf_addrb  : signal is "true";

-- attribute mark_debug of s_axi_id        : signal is "true";
-- attribute mark_debug of s_axi_valid     : signal is "true";
-- attribute mark_debug of s_axi_ready     : signal is "true";
-- attribute mark_debug of s_axi_last      : signal is "true";
-- attribute mark_debug of s_axi_resp      : signal is "true";
-- attribute mark_debug of s_axi_region    : signal is "true";
-- attribute mark_debug of m_axi_id        : signal is "true";
-- attribute mark_debug of m_axi_valid     : signal is "true";
-- attribute mark_debug of m_axi_ready     : signal is "true";
-- attribute mark_debug of m_axi_last      : signal is "true";
-- attribute mark_debug of m_axi_resp      : signal is "true";
-- attribute mark_debug of m_axi_region    : signal is "true";

--******************************************************************************
--Component Definitions
--******************************************************************************

--******************************************************************************
-- Connectivity and Logic
--******************************************************************************

begin

s_axi_areset <= not s_axi_aresetn;
m_axi_areset <= not m_axi_aresetn;

---------------------------------------
-- axi_parser
---------------------------------------
axi_parser_inst : entity axi_delay_lib.axi_parser
generic map (
    CHANNEL_TYPE         => CHANNEL_TYPE,
    MINIBUF_IDX_WIDTH    => MINIBUF_IDX_WIDTH,-- Number of Minibuffers = 2^MINIBUF_IDX_WIDTH
    CTR_PTR_WIDTH        => CTR_PTR_WIDTH,    -- indexes into (i.e. addresses) the packet buffer.
    PRIORITY_QUEUE_WIDTH => PRIORITY_QUEUE_WIDTH,
    C_AXI_ID_WIDTH       => C_AXI_ID_WIDTH,
    C_AXI_DATA_WIDTH     => C_AXI_DATA_WIDTH,
    C_AXI_ADDR_WIDTH     => C_AXI_ADDR_WIDTH,
    AXI_INFO_WIDTH       => AXI_INFO_WIDTH,
    AXI_INFO_DEPTH       => AXI_INFO_DEPTH,
    DELAY_WIDTH          => DELAY_WIDTH
)
port map (
    clk_i                => s_axi_aclk,
    rst_i                => s_axi_areset,
				 
    minibuf_fe_i         => minibuf_fe,
    minicam_full_i       => minicam_full,
    available_ctrptr_i   => available_ctrptr,
    random_dly_i         => s_time, --random_dly, -- replaced by s_time for conversion to timestamp operation (from delay operation)
    random_dly_o         => random_dly_buf,

    ----- Slave AXI Interface -----
    s_axi_id_i           => s_axi_id,    
    s_axi_addr_i         => s_axi_addr,
    s_axi_data_i         => s_axi_data,
    s_axi_strb_i         => s_axi_strb,  
    s_axi_len_i          => s_axi_len,   
    s_axi_size_i         => s_axi_size,  
    s_axi_burst_i        => s_axi_burst, 
    s_axi_lock_i         => s_axi_lock,  
    s_axi_cache_i        => s_axi_cache, 
    s_axi_prot_i         => s_axi_prot,  
    s_axi_qos_i          => s_axi_qos,   
    s_axi_region_i       => s_axi_region,
    		     			
    s_axi_valid_i        => s_axi_valid, 
    s_axi_ready_o        => s_axi_ready, 
    		     			
    s_axi_last_i         => s_axi_last,  
    s_axi_resp_i         => s_axi_resp,
    		     
    ----- minicam interface -----
    mc_valid_o           => mc_valid,
    mc_axi_id_o          => mc_axi_id,
    mc_last_o            => mc_last,
	
    mc_ctr_ptr_wr_i      => mc_ctr_ptr_wr,
    mc_ctr_ptr_i         => mc_ctr_ptr,
    		     
    ----- axi_id_buffer interface -----
    aidb_id_o            => aidb_id,
    aidb_cntr_ptr_base_o => aidb_cntr_ptr_base,
    aidb_wr_o            => aidb_wr(0),
    
    ----- pkt_buffer interface -----
    pb_info_data_o       => pb_info_data,
    pb_cntr_ptr_o        => pb_cntr_ptr,
    pb_wr_o              => pb_wr(0),
    
    ----- priority_queue interface -----
    pq_data_sr_o         => pq_data_sr,
    pq_data_o            => pq_data, --(axi_id & sb_index)
    pq_en_o              => pq_en,
    pq_ready_i           => pq_ready
);

---------------------------------------
-- minicam
---------------------------------------

use_minicam : if (BYPASS_MINICAM = 0) generate
    minicam_inst : entity axi_delay_lib.minicam
    generic map (
        CAM_DEPTH           => CAM_DEPTH,           -- depth of cam (i.e. number of entried), must be modulo 2
        CAM_WIDTH           => CAM_WIDTH,           -- maximum width of axi_id input. Requirement: CAMWIDTH => NUM_MINI_BUFS
        CTR_PTR_WIDTH       => CTR_PTR_WIDTH,       -- width of counter/pointer, which is the index to the Packet Buffer (start of mini-buffer)
        NUM_EVENTS_PER_MBUF => NUM_EVENTS_PER_MBUF, -- maximum number of events each minibuffer can hold
        NUM_MINI_BUFS       => NUM_MINI_BUFS        -- number of minibufs; each must be sized to hold the largest packet size supported
    )
    port map (
        clk_i               => s_axi_aclk,
        rst_i               => s_axi_areset,
        
        -- CAM I/O
        data_valid_i        => mc_valid,
        data_i              => mc_axi_id,
        
        tlast_i             => mc_last,       -- from the AXI downstream device, indicates that packet is completely stored in Mini buffer
        ctr_ptr_o           => mc_ctr_ptr,    -- counter/pointer to Packet Buffer
        ctr_ptr_wr_o        => mc_ctr_ptr_wr, -- write enable for counter/pointer to Pcaket Buffer
        minicam_full_o      => minicam_full,
        available_ctrptr_o  => available_ctrptr,
        minicam_err_o       => minicam_err,   -- this should never occur
        
        minibuf_fe_o        => minibuf_fe,
        minibuf_wr_i        => free_ctrptr_wr, -- write to minibuf_fifo after packet has been read out of packet_buffer
        minibuf_wdata_i     => free_ctrptr     -- write to minibuf_fifo after packet has been read out of packet_buffer
    );
end generate use_minicam;

skip_minicam : if (BYPASS_MINICAM = 1) generate
    minicam_bp_inst : entity axi_delay_lib.minicam_bypass
    generic map (
        CAM_WIDTH           => CAM_WIDTH,           -- maximum width of axi_id input. Requirement: CAMWIDTH => NUM_MINI_BUFS
        CTR_PTR_WIDTH       => CTR_PTR_WIDTH,       -- width of counter/pointer, which is the index to the Packet Buffer (start of mini-buffer)
        NUM_EVENTS_PER_MBUF => NUM_EVENTS_PER_MBUF, -- maximum number of events each minibuffer can hold
        NUM_MINI_BUFS       => NUM_MINI_BUFS        -- number of minibufs; each must be sized to hold the largest packet size supported
    )
    port map (
        clk_i               => s_axi_aclk,
        rst_i               => s_axi_areset,
        
        -- CAM I/O
        data_valid_i        => mc_valid,
        data_i              => mc_axi_id,
        
        tlast_i             => mc_last,       -- from the AXI downstream device, indicates that packet is completely stored in Mini buffer
        ctr_ptr_o           => mc_ctr_ptr,    -- counter/pointer to Packet Buffer
        ctr_ptr_wr_o        => mc_ctr_ptr_wr, -- write enable for counter/pointer to Pcaket Buffer
        minicam_full_o      => minicam_full,
        available_ctrptr_o  => available_ctrptr,
        minicam_err_o       => minicam_err,   -- this should never occur
        
        minibuf_fe_o        => minibuf_fe,
        minibuf_wr_i        => free_ctrptr_wr, -- write to minibuf_fifo after packet has been read out of packet_buffer
        minibuf_wdata_i     => free_ctrptr     -- write to minibuf_fifo after packet has been read out of packet_buffer
    );
end generate skip_minicam;

---------------------------------------
-- Packet Buffer
---------------------------------------
packet_buffer : entity dpram_true
GENERIC MAP (
    ADDR_WIDTH       => CTR_PTR_WIDTH,
    DATA_WIDTH       => AXI_INFO_WIDTH,
    CLOCKING_MODE    => "independent_clock",
    MEMORY_INIT_FILE => "none"
)
PORT MAP (
    clka  => s_axi_aclk,
    rsta  => s_axi_areset,
    ena   => '1',
    wea   => pb_wr,
    addra => pb_cntr_ptr,
    dina  => pb_info_data, 
    douta => OPEN,
    
    clkb  => m_axi_aclk,
    rstb  => m_axi_areset,
    enb   => pktbuf_enb,
    web   => (others => '0'),
    addrb => pktbuf_addrb,
    dinb  => pktbuf_dinb,
    doutb => pktbuf_doutb
);

---------------------------------------
-- AXI ID Buffer
---------------------------------------

axi_id_buffer : entity dpram_true
GENERIC MAP (
    ADDR_WIDTH       => MINIBUF_IDX_WIDTH,
    DATA_WIDTH       => C_AXI_ID_WIDTH,
    CLOCKING_MODE    => "independent_clock",
    MEMORY_INIT_FILE => "none"
)
PORT MAP (
    clka  => s_axi_aclk,
    rsta  => s_axi_areset,
    ena   => '1',
    wea   => aidb_wr,
    addra => aidb_cntr_ptr_base,
    dina  => aidb_id, 
    douta => OPEN,
    
    clkb  => m_axi_aclk,
    rstb  => m_axi_areset,
    enb   => '1',
    web   => (others => '0'),
    addrb => aidb_baddr,
    dinb  => (others => '0'),
    doutb => aidb_bdata
);

---------------------------------------
-- Random Delay Generator
-- random_dly_gen will take the raw output of a random number generator, calculate the appropriate delay, and output
-- that delay to the priority_ctlr. A new random delay will be available on every clock cycle.
---------------------------------------
random_dly_inst : entity axi_delay_lib.random_dly
generic map (
    SIMULATION       => SIMULATION,
    GDT_FILENAME     => GDT_FILENAME,
    GDT_ADDR_BITS    => GDT_ADDR_BITS,
    GDT_DATA_BITS    => GDT_DATA_BITS,
    LFSR_BITS        => GDT_ADDR_BITS
)
port map (
    clk_i            => m_axi_aclk,
    rst_i            => m_axi_areset,

    dclk_i           => dclk_i,
    dresetn_i        => dresetn_i,
    gdt_wren_i       => gdt_wren_i,
    gdt_addr_i       => gdt_addr_i,
    gdt_wdata_i      => gdt_wdata_i,
    gdt_rdata_o      => gdt_rdata_o,
    
    random_dly_req_i => mc_valid, --pq_en,
    random_dly_o     => random_dly_gdt
);

-- process(m_axi_aclk)
-- begin
--     if rising_edge(m_axi_aclk) then
--         case (pwclt_reg(3 downto 0)) is
--             when x"1"    => 
--                 truncation_factor <= std_logic_vector(shift_right(signed(C_TRUNCATION_FACTOR_DIV4_MU_72),  to_integer(unsigned(pwclt_reg(7 downto 4)))));
--                 addition_factor <= C_MU_72;
--             when x"2"    => 
--                 truncation_factor <= std_logic_vector(shift_right(signed(C_TRUNCATION_FACTOR_DIV4_MU_216), to_integer(unsigned(pwclt_reg(7 downto 4)))));
--                 addition_factor <= C_MU_216;
--             when x"3"    => 
--                 truncation_factor <= std_logic_vector(shift_right(signed(C_TRUNCATION_FACTOR_DIV4_MU_366), to_integer(unsigned(pwclt_reg(7 downto 4)))));
--                 addition_factor <= C_MU_366;
--             when x"4"    => 
--                 truncation_factor <= std_logic_vector(shift_right(signed(C_TRUNCATION_FACTOR_DIV4_MU_492), to_integer(unsigned(pwclt_reg(7 downto 4)))));
--                 addition_factor <= C_MU_492;
--             when x"5"    => 
--                 truncation_factor <= std_logic_vector(shift_right(signed(C_TRUNCATION_FACTOR_DIV4_MU_510), to_integer(unsigned(pwclt_reg(7 downto 4)))));
--                 addition_factor <= C_MU_510;
--             when x"6"    => 
--                 truncation_factor <= std_logic_vector(shift_right(signed(C_TRUNCATION_FACTOR_DIV4_MU_636), to_integer(unsigned(pwclt_reg(7 downto 4)))));
--                 addition_factor <= C_MU_636;
--             when x"7"    => 
--                 truncation_factor <= std_logic_vector(shift_right(signed(C_TRUNCATION_FACTOR_DIV4_MU_1056),to_integer(unsigned(pwclt_reg(7 downto 4)))));
--                 addition_factor <= C_MU_1056;
--             when x"8"    => 
--                 truncation_factor <= std_logic_vector(shift_right(signed(C_TRUNCATION_FACTOR_DIV4_MU_1200),to_integer(unsigned(pwclt_reg(7 downto 4)))));
--                 addition_factor <= C_MU_1200;
--             when x"9"    => 
--                 truncation_factor <= std_logic_vector(shift_right(signed(C_TRUNCATION_FACTOR_DIV4_MU_2256),to_integer(unsigned(pwclt_reg(7 downto 4)))));
--                 addition_factor <= C_MU_2256;
--             when x"A"    => 
--                 truncation_factor <= std_logic_vector(shift_right(signed(C_TRUNCATION_FACTOR_DIV4_MU_2400),to_integer(unsigned(pwclt_reg(7 downto 4)))));
--                 addition_factor <= C_MU_2400;
--             when others 	=> 
--                 truncation_factor <= (others => '0');
--                 addition_factor <= (others => '0');
--         end case;

--         grng_output_m <= std_logic_vector(signed(grng_output)*signed(truncation_factor));
--         grng_output_a <= std_logic_vector(signed(grng_output_m)+resize(signed(addition_factor),37)) ;
        
--         if pwclt_reg = x"000000" then
--             random_dly_clip <= random_dly_gdt;
--             random_dly <= random_dly_clip;
--         else
--             random_dly_clip <= (C_ZERO(3 downto 0) & grng_output_a(36 downto 17));
--             if signed(random_dly_clip) >= signed(pwclt_calib_reg) then
--                 random_dly <= std_logic_vector(signed(random_dly_clip) - signed(pwclt_calib_reg));
--             else
--                 random_dly <= (others => '0');
--             end if;
--         end if;

--     end if ;
-- end process;

process(m_axi_aclk)
begin
    if rising_edge(m_axi_aclk) then
        grng_output_m <= std_logic_vector(signed(grng_output)*signed(truncation_factor));
        grng_output_a <= std_logic_vector(signed(grng_output_m)+resize(signed(addition_factor),37)) ;
        
        if pwclt_reg = x"000000" then
            random_dly <= random_dly_clip;
        else
            if signed(random_dly_clip) >= signed(pwclt_calib_reg) then
                random_dly <= std_logic_vector(signed(random_dly_clip) - signed(pwclt_calib_reg));
            else
                random_dly <= (others => '0');
            end if;
        end if;

        case (pwclt_reg) is
            when x"000001"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV4_MU_72 ;
            when x"000002"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV4_MU_216;
            when x"000003"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV4_MU_366;
            when x"000004"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV4_MU_492;
            when x"000005"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV4_MU_510;
            when x"000006"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV4_MU_636;
            when x"000007"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV4_MU_1056;
            when x"000008"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV4_MU_1200;
            when x"000009"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV4_MU_2256;
            when x"00000A"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV4_MU_2400;
            when x"000011"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV8_MU_72 ;
            when x"000012"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV8_MU_216;
            when x"000013"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV8_MU_366;
            when x"000014"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV8_MU_492;
            when x"000015"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV8_MU_510;
            when x"000016"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV8_MU_636;
            when x"000017"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV8_MU_1056;
            when x"000018"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV8_MU_1200;
            when x"000019"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV8_MU_2256;
            when x"00001A"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV8_MU_2400;
            when x"000021"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV16_MU_72 ;
            when x"000022"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV16_MU_216;
            when x"000023"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV16_MU_366;
            when x"000024"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV16_MU_492;
            when x"000025"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV16_MU_510;
            when x"000026"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV16_MU_636;
            when x"000027"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV16_MU_1056;
            when x"000028"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV16_MU_1200;
            when x"000029"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV16_MU_2256;
            when x"00002A"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV16_MU_2400;
            when x"000031"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV32_MU_72 ;
            when x"000032"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV32_MU_216;
            when x"000033"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV32_MU_366;
            when x"000034"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV32_MU_492;
            when x"000035"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV32_MU_510;
            when x"000036"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV32_MU_636;
            when x"000037"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV32_MU_1056;
            when x"000038"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV32_MU_1200;
            when x"000039"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV32_MU_2256;
            when x"00003A"    => truncation_factor <= C_TRUNCATION_FACTOR_DIV32_MU_2400;
            when others 	=> truncation_factor <= (others => '0');
        end case;

        case (pwclt_reg(3 downto 0)) is
            when x"1"    => addition_factor <= C_MU_72;
            when x"2"    => addition_factor <= C_MU_216;
            when x"3"    => addition_factor <= C_MU_366;
            when x"4"    => addition_factor <= C_MU_492;
            when x"5"    => addition_factor <= C_MU_510;
            when x"6"    => addition_factor <= C_MU_636;
            when x"7"    => addition_factor <= C_MU_1056;
            when x"8"    => addition_factor <= C_MU_1200;
            when x"9"    => addition_factor <= C_MU_2256;
            when x"A"    => addition_factor <= C_MU_2400;
            when others   => addition_factor <= (others => '0');
        end case;
        
        case (pwclt_reg) is
            when x"000000"	=> random_dly_clip <= random_dly_gdt;
            when others 	=> random_dly_clip <= (grng_output_a(36) & grng_output_a(36) & grng_output_a(36) & grng_output_a(36) & grng_output_a(36 downto 17));
        end case;
    end if ;
end process;

---------------------------------------
-- Priority Queue
---------------------------------------
pq_data_complete <= random_dly_buf & pq_data;

priority_queue_inst : entity axi_delay_lib.priority_queue
generic map (
    SIMULATION           => SIMULATION,
    PRIORITY_QUEUE_WIDTH => PRIORITY_QUEUE_WIDTH,
    DELAY_WIDTH          => DELAY_WIDTH,
    INDEX_WIDTH          => MINIBUF_IDX_WIDTH,
    C_AXI_ID_WIDTH       => C_AXI_ID_WIDTH,
    C_AXI_ADDR_WIDTH     => C_AXI_ADDR_WIDTH,
    C_AXI_DATA_WIDTH     => C_AXI_DATA_WIDTH,
    MINIBUF_IDX_WIDTH    => MINIBUF_IDX_WIDTH
  )
port map (
    clk_i                => m_axi_aclk,
    nreset_i             => m_axi_aresetn,
    counter_i            => counter,
  
    -- (delay & axi_id & sb_index) of the transaction (from axi_parser)
    din_sr_i             => pq_data_sr,
    din_i                => pq_data_complete,
    din_en_i             => pq_en,
    din_ready_o          => pq_ready,
  
    -- (delay & axi_id & sb_index) of the transaction (to priority controller)
    dout_o               => pq_dout,
    dout_valid_o         => pq_dout_valid,
    dout_ready_i         => pq_dout_ready
  );
  
---------------------------------------
-- Priority Controller
---------------------------------------
priority_controller_inst : entity axi_delay_lib.priority_controller
generic map(
    DELAY_WIDTH         => DELAY_WIDTH,
    NUM_MINI_BUFS       => NUM_MINI_BUFS,
    MINIBUF_IDX_WIDTH   => MINIBUF_IDX_WIDTH,
    CTR_PTR_WIDTH       => CTR_PTR_WIDTH,
    AXI_INFO_WIDTH      => AXI_INFO_WIDTH,
    C_AXI_ID_WIDTH      => C_AXI_ID_WIDTH,
    NUM_EVENTS_PER_MBUF => NUM_EVENTS_PER_MBUF
)
port map (
    clk_i               => m_axi_aclk,
    rst_i               => m_axi_areset,
    
    m_axi_ready_i       => m_axi_ready,
    
    pq_dout_i           => pq_dout,
    pq_dout_valid_i     => pq_dout_valid,
    pq_dout_ready_o     => pq_dout_ready,

    pktbuf_enb_o        => pktbuf_enb,
    pktbuf_addrb_o      => pktbuf_addrb,
    pktbuf_dinb_o       => pktbuf_dinb,
    pktbuf_doutb_i      => pktbuf_doutb,
    
    aidb_baddr_o        => aidb_baddr,
    aidb_bdata_i        => aidb_bdata,
    
    free_ctrptr_wr_o    => free_ctrptr_wr, -- write to minibuf_fifo after packet has been read out of packet_buffer
    free_ctrptr_o       => free_ctrptr,     -- write to minibuf_fifo after packet has been read out of packet_buffer
    
    axi_info_valid_o    => axi_info_valid,
    axi_info_data_o     => axi_info_data 
);

---------------------------------------
-- Counter logic
---------------------------------------

s_time     <= std_logic_vector(unsigned(counter) + unsigned(random_dly));

----------------------------------------------------------------------------------------------
-- Output assignments
----------------------------------------------------------------------------------------------
m_axi_resp   <= axi_info_data(2+C_AXI_ID_WIDTH+C_AXI_ADDR_WIDTH+C_AXI_DATA_WIDTH+(C_AXI_DATA_WIDTH/8)+31 downto 
                    C_AXI_ID_WIDTH+C_AXI_ADDR_WIDTH+C_AXI_DATA_WIDTH+(C_AXI_DATA_WIDTH/8)+32) when (axi_info_valid = '1') else (others => '0');

m_axi_id     <= axi_info_data(C_AXI_ID_WIDTH+C_AXI_ADDR_WIDTH+C_AXI_DATA_WIDTH+(C_AXI_DATA_WIDTH/8)+31 downto 
		            C_AXI_ADDR_WIDTH+C_AXI_DATA_WIDTH+(C_AXI_DATA_WIDTH/8)+32) when (axi_info_valid = '1') else (others => '0');
		    
m_axi_addr   <= axi_info_data(C_AXI_ADDR_WIDTH+C_AXI_DATA_WIDTH+(C_AXI_DATA_WIDTH/8)+31 downto 
                    C_AXI_DATA_WIDTH+(C_AXI_DATA_WIDTH/8)+32) when (axi_info_valid = '1') else (others => '0');
                    
m_axi_data   <= axi_info_data(C_AXI_DATA_WIDTH+(C_AXI_DATA_WIDTH/8)+31 downto 
                    (C_AXI_DATA_WIDTH/8)+32) when (axi_info_valid = '1') else (others => '0');
                    
m_axi_strb   <= axi_info_data((C_AXI_DATA_WIDTH/8)+31 downto 32) when (axi_info_valid = '1') else (others => '0');

m_axi_len    <= axi_info_data(31 downto 24);
m_axi_size   <= axi_info_data(23 downto 21);
m_axi_burst  <= axi_info_data(20 downto 19);
m_axi_lock   <= axi_info_data(18 downto 17);
m_axi_cache  <= axi_info_data(16 downto 13);
m_axi_prot   <= axi_info_data(12 downto 10);  
m_axi_qos    <= axi_info_data(9 downto 6);   
m_axi_region <= axi_info_data(5 downto 2);
m_axi_valid  <= axi_info_data(1);
m_axi_last   <= axi_info_data(0);
----------------------------------------------------------------------------------------------

end chan_delay_variable;
