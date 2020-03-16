--**********************************************************************************************************
-- Lawrence Livermore National Labs
-- 20191217 CM Initial creation 
-- axi_parser.vhd:  This module "parses" the input axi bus, i.e. pulls out or concatenates fields as required by
--                  functional logic.
--**********************************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;

library axi_delay_lib;
use axi_delay_lib.all;
use axi_delay_lib.axi_delay_pkg.all;

entity axi_parser is
    generic (
        CHANNEL_TYPE       : string  := "AW" ; -- valid values are:  AW, W, B, AR, R
        MINIBUF_IDX_WIDTH  : integer := 6;     -- Number of Minibuffers = 2^MINIBUF_IDX_WIDTH
        CTR_PTR_WIDTH      : integer := 9;     -- Number of addressable locations (events) in each Minibuffer = 2^(CTR_PTR_WIDTH-MINIBUF_IDX_WIDTH)
                                               -- minimum depth of Packet Buffer DPRAM = 2^(CTR_PTR_WIDTH)
     
        -- AXI-Full Bus Interface
        C_AXI_ID_WIDTH     : integer := 16;
        C_AXI_ADDR_WIDTH   : integer := 40;
        C_AXI_DATA_WIDTH   : integer := 128;
        AXI_INFO_WIDTH     : integer := 192;
        AIDBUF_ADDR_WIDTH  : integer := 6
    );
    port (
        clk_i              : in  std_logic;
        rst_i              : in  std_logic;

        minibuf_fe_i       : in  std_logic;
        minicam_full_i     : in  std_logic;
        available_ctrptr_i : in  std_logic;

	    ----- Slave AXI Interface -----
        s_axi_id_i       : in  std_logic_vector(C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
        s_axi_addr_i     : in  std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0) := (others => '0'); 
        s_axi_data_i     : in  std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0) := (others => '0'); 
        s_axi_strb_i     : in  std_logic_vector((C_AXI_DATA_WIDTH/8)-1 downto 0) := (others => '1');
        s_axi_len_i      : in  std_logic_vector(7 downto 0) := (others => '0');
        s_axi_size_i     : in  std_logic_vector(2 downto 0) := "110";
        s_axi_burst_i    : in  std_logic_vector(1 downto 0) := "01";
        s_axi_lock_i     : in  std_logic_vector(1 downto 0) := (others => '0');
        s_axi_cache_i    : in  std_logic_vector(3 downto 0) := (others => '0');
        s_axi_prot_i     : in  std_logic_vector(2 downto 0) := (others => '0'); 
        s_axi_qos_i      : in  std_logic_vector(3 downto 0) := (others => '0'); 
        s_axi_region_i   : in  std_logic_vector(3 downto 0) := (others => '0');
        
        s_axi_valid_i    : in  std_logic;
        s_axi_ready_o    : out std_logic;

        s_axi_last_i     : in  std_logic;
        s_axi_resp_i     : in  std_logic_vector(1 downto 0);

        ----- AW ID latch output to W ID input
        aw_id_o          : out std_logic_vector(C_AXI_ID_WIDTH-1 downto 0); -- only for "AW" instance - open for others
        w_last_i         : in  std_logic;                                   -- only for "AW" instance, '0' for others
        w_last_o         : out std_logic;                                   -- only for "W" instance - open for others
        w_id_i           : in  std_logic_vector(C_AXI_ID_WIDTH-1 downto 0); -- only for "W" instance - tie to zeroes for others

        ----- minicam interface -----
        mc_valid_o       : out std_logic;
        mc_axi_id_o      : out std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);
        mc_last_o        : out std_logic;

        mc_ctr_ptr_wr_i  : in  std_logic;
        mc_ctr_ptr_i     : in  std_logic_vector(CTR_PTR_WIDTH-1 downto 0);
        
        ----- axi_id_buffer interface -----
        aidb_id_o            : out std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);
        aidb_cntr_ptr_base_o : out std_logic_vector(AIDBUF_ADDR_WIDTH-1 downto 0);
        aidb_wr_o            : out std_logic;   

        ----- pkt_buffer interface -----
        pb_info_data_o       : out std_logic_vector(AXI_INFO_WIDTH-1 downto 0);
        pb_cntr_ptr_o        : out std_logic_vector(CTR_PTR_WIDTH-1 downto 0);
        pb_wr_o              : out std_logic;

        ----- scoreboard interface -----
        sb_wr_o              : out std_logic; -- s_axi_last_i detected, assert corresonding valid bit
        sb_index_o           : out integer;   -- index of scoreboard valid bit

        pq_data_o            : out std_logic_vector(C_AXI_ID_WIDTH+MINIBUF_IDX_WIDTH-1 downto 0);
        pq_en_o              : out std_logic;
        pq_ready_i           : in  std_logic
    );
end axi_parser;

architecture behavioral of axi_parser is

--******************************************************************************
-- Constants
--******************************************************************************
constant C_ZERO : std_logic_vector(255 downto 0) := (others => '0'); -- create std_logic_vector for FIFO i/p leading zeros

--******************************************************************************
-- Components
--******************************************************************************

-- COMPONENT FIFO_16x256
--   PORT (
--     clk         : IN STD_LOGIC;
--     srst        : IN STD_LOGIC;
--     din         : IN STD_LOGIC_VECTOR(255 DOWNTO 0);
--     wr_en       : IN STD_LOGIC;
--     rd_en       : IN STD_LOGIC;
--     dout        : OUT STD_LOGIC_VECTOR(255 DOWNTO 0);
--     full        : OUT STD_LOGIC;
--     empty       : OUT STD_LOGIC;
--     valid       : OUT STD_LOGIC;
--     prog_full   : OUT STD_LOGIC;
--     prog_empty  : OUT STD_LOGIC;
--     wr_rst_busy : OUT STD_LOGIC;
--     rd_rst_busy : OUT STD_LOGIC
--   );
-- END COMPONENT;

-- COMPONENT fifo_32x16
--   PORT (
--     clk         : IN STD_LOGIC;
--     srst        : IN STD_LOGIC;
--     din         : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--     wr_en       : IN STD_LOGIC;
--     rd_en       : IN STD_LOGIC;
--     dout        : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
--     full        : OUT STD_LOGIC;
--     empty       : OUT STD_LOGIC;
--     valid       : OUT STD_LOGIC;
--     prog_full   : OUT STD_LOGIC;
--     prog_empty  : OUT STD_LOGIC;
--     wr_rst_busy : OUT STD_LOGIC;
--     rd_rst_busy : OUT STD_LOGIC
--   );
-- END COMPONENT;

--******************************************************************************
--Signal Definitions
--******************************************************************************
-- flag and fifo write generation
signal first_data_flag  : std_logic;
signal mid_data_flag    : std_logic;
signal last_data_flag   : std_logic;
signal rwaddr_resp_flag : std_logic; -- write addr, read addr, or response flags
signal acc_going_on     : std_logic; -- access in progress flag

-- FIFO interface signals
signal axi_info_wdata   : std_logic_vector(255 downto 0);
signal axi_info_wr      : std_logic;
signal axi_info_af      : std_logic;
signal axi_info_full    : std_logic;
signal axi_info_valid   : std_logic;
signal axi_info_rdata   : std_logic_vector(255 downto 0);
signal axi_info_rd      : std_logic;

-- misc. logic
signal s_axi_id         : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0); -- multiplexed axi_id for use with the "W" bus
signal s_axi_ready      : std_logic;
signal sb_index         : std_logic_vector(MINIBUF_IDX_WIDTH-1 downto 0);
signal sb_index_int     : integer;
signal mc_ctr_ptr_wr_q  : std_logic;
signal mc_ctr_ptr_q     : std_logic_vector(CTR_PTR_WIDTH-1 downto 0);

--******************************************************************************
-- Connectivity and Logic
--******************************************************************************

begin

--------------------------------------------------------------------------------
-- Generate write enable for axi_info_fifo based on "bus cycle type" flags. These flags are based on the flags 
-- generated in axi_perf_mon_v5_0_10_flags_gen.v
--------------------------------------------------------------------------------

first_data_flag  <= s_axi_valid_i and s_axi_ready and (not acc_going_on);
mid_data_flag    <= s_axi_valid_i and s_axi_ready and acc_going_on and (not s_axi_last_i);
last_data_flag   <= s_axi_valid_i and s_axi_ready and s_axi_last_i;
rwaddr_resp_flag <= s_axi_valid_i and s_axi_ready;

-- acc_going_on (access in progress)
acc_ip_proc : process (clk_i, rst_i) begin
    if (rst_i = '1') then
        acc_going_on <= '0';
    elsif rising_edge(clk_i) then
        if (s_axi_valid_i = '1' and s_axi_ready = '1' and s_axi_last_i = '1') then -- last write flag
            acc_going_on <= '0';
        elsif (first_data_flag = '1') then
            acc_going_on <= '1';
        else
            acc_going_on <= acc_going_on;
        end if;
    end if;
end process;

-- generate fifo write enable for write address, read address, or write response
addr_flag_gen : if (CHANNEL_TYPE = "AW" or CHANNEL_TYPE = "AR" or CHANNEL_TYPE = "B") generate
    axi_info_wr <= rwaddr_resp_flag;  
    mc_valid_o  <= rwaddr_resp_flag;  
    mc_axi_id_o <= s_axi_id_i;
end generate; 

-- generate fifo write enable for read or write data
data_flag_gen : if (CHANNEL_TYPE = "W" or CHANNEL_TYPE = "R") generate
    axi_info_wr <= first_data_flag or mid_data_flag or last_data_flag; 
    mc_valid_o  <= first_data_flag or mid_data_flag or last_data_flag; 
    mc_axi_id_o <= s_axi_id;
end generate;

--------------------------------------------------------------------------------
-- AXI WID processing - *************FOR "AW" INSTANCES ONLY!!!*************
-- The "W" bus is the only AXI bus that doesn't contain a valid ID field for AXI4. However, an ID field is required
-- for the minicam and packet buffer operation.
-- If there are any AXI3 masters that feed data to this module, then "write interleaving depth" must be set to a value of "1"
-- to make it compatible with an AXI4 slave.
-- In any case, since ordering can/should be guaranteed, we can latch the AW bus ID and use it for succeeding W bus transactions
-- A FIFO is required because the "W" cycle for a corresponsing "AW" cycle may not appear on the bus until after several more
-- "AW"'s have appeared on the bus.
--------------------------------------------------------------------------------
-- generate FIFO for AW instance only. This will buffer/save AWIDs (in the AW instance) for corelation with WIDs (in the W instance)
awid_fifo_gen : if (CHANNEL_TYPE = "AW") generate
    awid_fifo : entity  fifo_32x16
        PORT MAP (
            clk         => clk_i,
            srst        => rst_i,
            din         => s_axi_id_i,
            prog_full   => OPEN,
            full        => OPEN,
            wr_en       => rwaddr_resp_flag,

            rd_en       => w_last_i,
            dout        => aw_id_o,
            empty       => OPEN,
            valid       => OPEN,
            prog_empty  => OPEN,
            wr_rst_busy => OPEN,
            rd_rst_busy => OPEN
        );        
end generate;

not_awid_gen : if (CHANNEL_TYPE /= "AW") generate
    aw_id_o  <= (others => '0');
end generate;

--------------------------------------------------------------------------------
-- AXI Information FIFO - buffers all information from AXI events
--------------------------------------------------------------------------------

s_axi_id <= w_id_i when (CHANNEL_TYPE = "W") else s_axi_id_i;

-- concatenate all axi input signals (outputs are not concatenated)
axi_info_wdata <= C_ZERO(255 downto AXI_INFO_WIDTH) & s_axi_resp_i & s_axi_id & s_axi_addr_i & s_axi_data_i & s_axi_strb_i & s_axi_len_i & s_axi_size_i & s_axi_burst_i & 
                   s_axi_lock_i  & s_axi_cache_i & s_axi_prot_i & s_axi_qos_i & s_axi_region_i & s_axi_valid_i & s_axi_last_i;

-- shallow FIFO for buffering AXI events                    
axi_info_fifo : entity  FIFO_16x256
    PORT MAP (
        clk         => clk_i,
        srst        => rst_i,

        din         => axi_info_wdata,
        prog_full   => axi_info_af,
        full        => axi_info_full,
        wr_en       => axi_info_wr,

        dout        => axi_info_rdata,
        prog_empty  => OPEN,
        empty       => OPEN,
        valid       => axi_info_valid,
        rd_en       => axi_info_rd,
        wr_rst_busy => OPEN,
        rd_rst_busy => OPEN
  );

s_axi_ready <= (not axi_info_af) and (not minibuf_fe_i) and (pq_ready_i);
--s_axi_ready <= (not axi_info_af) and (not minibuf_fe_i) and (not minicam_full_i) and (pq_ready_i);

sb_index     <= mc_ctr_ptr_q(CTR_PTR_WIDTH-1 downto (CTR_PTR_WIDTH-MINIBUF_IDX_WIDTH));
sb_index_int <= to_integer(unsigned(sb_index));

--------------------------------------------------------------------------------
-- Pipeline registers
--------------------------------------------------------------------------------
pipeline_proc : process (clk_i, rst_i) begin
    if (rst_i = '1') then
        axi_info_rd     <= '0';
        mc_ctr_ptr_wr_q <= '0';
        mc_ctr_ptr_q    <= (others => '0');
    elsif rising_edge(clk_i) then
        axi_info_rd     <= axi_info_wr;
        mc_ctr_ptr_wr_q <= mc_ctr_ptr_wr_i;
        mc_ctr_ptr_q    <= mc_ctr_ptr_i;
    end if;
end process;

----------------------------------------------------------------------------------------------
-- Output assignments
----------------------------------------------------------------------------------------------
s_axi_ready_o <= s_axi_ready;
--s_axi_resp_o  <= axi_info_full & '0'; --status = "okay" when axi_info_full = 0, "slave error" when = 1. See IHI022E for other codes
w_last_o      <= last_data_flag; -- used for "AW" instances only
mc_last_o     <= last_data_flag;

-----  pkt_buffer interface -----
pb_info_data_o   <= axi_info_rdata(AXI_INFO_WIDTH-1 downto 0);
pb_cntr_ptr_o    <= mc_ctr_ptr_q;
pb_wr_o          <= axi_info_valid;

----- axi_id_buffer interface -----
aidb_id_o            <= axi_info_rdata(AXI_INFO_WIDTH-2-1 downto AXI_INFO_WIDTH-2-C_AXI_ID_WIDTH);
aidb_cntr_ptr_base_o <= sb_index;
aidb_wr_o            <= mc_ctr_ptr_wr_q;

----- scoreboard interface -----
sb_index_o <= sb_index_int;
sb_wr_o    <= mc_ctr_ptr_wr_q and axi_info_rdata(0); -- Assert scoreboard valid bit if last_data_flag = 1

----- priority_controller interface -----
-- pq_data_o contains (axi_id & sb_index), width = C_AXI_ID_WIDTH + MINIBUF_IDX_WIDTH
pq_data_o  <= axi_info_rdata(AXI_INFO_WIDTH-2-1 downto AXI_INFO_WIDTH-2-C_AXI_ID_WIDTH) & sb_index;
pq_en_o    <= mc_ctr_ptr_wr_q and axi_info_rdata(0);

----------------------------------------------------------------------------------------------
end behavioral;
