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
    CHANNEL_TYPE         : string  := "AW" ; -- valid values are:  AW, W, B, AR, R
    PRIORITY_QUEUE_WIDTH : integer := 16;
    DELAY_WIDTH          : integer := 24;
    BYPASS_MINICAM       : integer := 0;
    -- AXI-Full Bus Interface
    C_AXI_ID_WIDTH       : integer := 16;
    C_AXI_ADDR_WIDTH     : integer := 40;
    C_AXI_DATA_WIDTH     : integer := 128;
    
    GDT_ADDR_BITS        : integer := 10;
    GDT_DATA_BITS        : integer := 24;
    -- minicam generics
    CAM_DEPTH            : integer := 8;  -- depth of cam (i.e. number of entries), must be modulo 2.
    CAM_WIDTH            : integer := 16; -- maximum width of axi_id input. Requirement: CAMWIDTH <= NUM_MINI_BUFS
    NUM_EVENTS_PER_MBUF  : integer := 8;  -- maximum number of events each minibuffer can hold
    NUM_MINI_BUFS        : integer := 64  -- number of minibufs; each must be sized to hold the largest packet size supported
);
port (
    --------------------------------------------
    ----- AXI Slave Interface ---
    --------------------------------------------
    s_axi_aclk    : in  std_logic;
    s_axi_aresetn : in  std_logic;
    
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
    gdt_rdata_o   : out std_logic_vector(23 downto 0)
);

end chan_delay_variable;

architecture chan_delay_variable of chan_delay_variable is

--******************************************************************************
-- Constants
--******************************************************************************
constant C_DATA_LEN        : integer := 150; --length of pl_dly_din variable, i.e. depth of pl
constant MINIBUF_IDX_WIDTH : integer := log2rp(NUM_MINI_BUFS);
constant CTR_PTR_WIDTH     : integer := MINIBUF_IDX_WIDTH + 2; -- indexes into (i.e. addresses) the packet buffer. Minimum depth of Packet Buffer DPRAM = 2^(CTR_PTR_WIDTH)

-- Note: assuming maximum width defined by C_AXI_ID_WIDTH = 16 and C_AXI_DATA_WIDTH = 128 (C_AXI_DATA_WIDTH/8 = 16) and misc (32) = 192
constant AXI_INFO_WIDTH    : integer := C_AXI_ID_WIDTH + C_AXI_DATA_WIDTH + C_AXI_ADDR_WIDTH + C_AXI_DATA_WIDTH/8 + 
                                    8 + 3 + 2 + 2 + 4 + 3 + 4 + 4 + 1 + 1 + 2;

constant C_ZERO    : std_logic_vector(1023 downto 0) := (others => '0');
constant C_ZERO_16 : std_logic_vector(15 downto 0) := (others => '0');

--******************************************************************************
--Signal Definitions
--******************************************************************************
signal random_dly     : std_logic_vector(DELAY_WIDTH-1 downto 0);
signal random_dly_req : std_logic;

signal s_axi_areset   : std_logic;
signal m_axi_areset   : std_logic;

signal pktbuf_enb     : std_logic;
signal pktbuf_addrb   : std_logic_vector(7 downto 0);
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
--signal pb_dina            : std_logic_vector(1023 downto 0);
signal pb_wr              : std_logic_vector(0 downto 0);

signal minibuf_fe         : std_logic;
signal free_ctrptr_wr     : std_logic;
signal free_ctrptr        : std_logic_vector(CTR_PTR_WIDTH-1 downto 0); 

signal minicam_full       : std_logic;
signal available_ctrptr   : std_logic;
signal minicam_err        : std_logic;

signal scoreboard_wr      : std_logic;
signal scoreboard_wr_idx  : integer;
signal scoreboard_valid   : std_logic_vector(NUM_MINI_BUFS-1 downto 0);
signal scoreboard_rd_idx  : integer;
signal scoreboard_rd_clr  : std_logic;

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

--------------------------------------------------------------------------------
--For Chipscope
attribute mark_debug : string;
--attribute mark_debug of pb_wr        : signal is "true";
attribute mark_debug of pb_cntr_ptr  : signal is "true";
--attribute mark_debug of pb_info_data : signal is "true";
--attribute mark_debug of pktbuf_enb   : signal is "true";
--attribute mark_debug of pktbuf_addrb : signal is "true";
--attribute mark_debug of pktbuf_doutb : signal is "true";

attribute mark_debug of pq_data_complete : signal is "true";
attribute mark_debug of random_dly       : signal is "true";
attribute mark_debug of pq_data          : signal is "true";

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
    DELAY_WIDTH          => DELAY_WIDTH
)
port map (
    clk_i                => s_axi_aclk,
    rst_i                => s_axi_areset,
				 
    minibuf_fe_i         => minibuf_fe,
    minicam_full_i       => minicam_full,
    available_ctrptr_i   => available_ctrptr,

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
    
    ----- scoreboard interface -----
    sb_wr_o              => scoreboard_wr,
    sb_index_o           => scoreboard_wr_idx,

    ----- priority_queue interface -----
    random_dly_i         => random_dly,
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

--pb_dina <= C_ZERO(1023 downto AXI_INFO_WIDTH) & pb_info_data;

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
    dina  => pb_info_data, --pb_dina, 
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

--aidb_id_zero <= aidb_id when (C_AXI_ID_WIDTH = 16) else
--                (C_ZERO_16(15 downto C_AXI_ID_WIDTH) & aidb_id);


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
-- ScoreBoard
---------------------------------------
scoreboard_inst : entity axi_delay_lib.scoreboard
GENERIC MAP (
    NUM_MINI_BUFS     => NUM_MINI_BUFS,
    MINIBUF_IDX_WIDTH => MINIBUF_IDX_WIDTH
)
PORT MAP (
    s_clk_i             => s_axi_aclk,
    s_rst_i             => s_axi_areset,
    
    m_clk_i             => m_axi_aclk,
    m_rst_i             => m_axi_areset,
    
    scoreboard_wr_i     => scoreboard_wr,
    scoreboard_wr_idx_i => scoreboard_wr_idx,
    
    scoreboard_valid_o  => scoreboard_valid,
    scoreboard_rd_idx_i => scoreboard_rd_idx,
    scoreboard_rd_clr_i => scoreboard_rd_clr
);

---------------------------------------
-- Random Delay Generator
-- random_dly_gen will take the raw output of a random number generator, calculate the appropriate delay, and output
-- that delay to the priority_ctlr. A new random delay will be available on every clock cycle.
---------------------------------------
random_dly_inst : entity axi_delay_lib.random_dly
generic map (
    GDT_ADDR_BITS    => GDT_ADDR_BITS,
    GDT_DATA_BITS    => GDT_DATA_BITS,
    LFSR_BITS        => 16
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
    
    random_dly_req_i => pq_en,
    random_dly_o     => random_dly
);

---------------------------------------
-- Priority Queue
---------------------------------------
pq_data_complete <= random_dly & pq_data;

priority_queue_inst : entity axi_delay_lib.priority_queue
generic map (
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
  
    -- (delay & axi_id & sb_index) of the transaction (from axi_parser)
    din_sr_i      => pq_data_sr,
    din_i         => pq_data_complete,
    din_en_i      => pq_en,
    din_ready_o   => pq_ready,
  
    -- (delay & axi_id & sb_index) of the transaction (to priority controller)
    dout_o        => pq_dout,
    dout_valid_o  => pq_dout_valid,
    dout_ready_i  => pq_dout_ready
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
    C_AXI_ID_WIDTH      => C_AXI_ID_WIDTH
)
port map (
    clk_i               => m_axi_aclk,
    rst_i               => m_axi_areset,
    
    scoreboard_valid_i  => scoreboard_valid,  -- scoreboard valid, indicating which minibuffers contain a complete packet ready for processing
    scoreboard_rd_idx_o => scoreboard_rd_idx, -- index to minibuffer that has been emptied
    scoreboard_rd_clr_o => scoreboard_rd_clr, -- clear bit, which clears the minbuffer indicated by index

    pq_dout_i           => pq_dout,
    pq_dout_valid_i     => pq_dout_valid,
    pq_dout_ready_o     => pq_dout_ready,

    pktbuf_enb_o        => pktbuf_enb,
    pktbuf_addrb_o      => pktbuf_addrb,
    pktbuf_dinb_o       => pktbuf_dinb,
    pktbuf_doutb_i      => pktbuf_doutb,
    
    aidb_baddr_o        => aidb_baddr,
    aidb_bdata_i        => aidb_bdata,
    
    random_dly_i        => random_dly, 
    random_dly_req_o    => random_dly_req,
    
    free_ctrptr_wr_o    => free_ctrptr_wr, -- write to minibuf_fifo after packet has been read out of packet_buffer
    free_ctrptr_o       => free_ctrptr,     -- write to minibuf_fifo after packet has been read out of packet_buffer
    
    axi_info_valid_o    => axi_info_valid,
    axi_info_data_o     => axi_info_data 
);

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
