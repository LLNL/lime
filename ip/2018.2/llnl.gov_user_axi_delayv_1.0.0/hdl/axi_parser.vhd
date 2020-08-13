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
        PRIORITY_QUEUE_WIDTH : integer := 16;
        C_AXI_ID_WIDTH     : integer := 16;
        C_AXI_ADDR_WIDTH   : integer := 40;
        C_AXI_DATA_WIDTH   : integer := 128;
        AXI_INFO_WIDTH     : integer := 192;
        AXI_INFO_DEPTH     : integer := 32;
        DELAY_WIDTH        : integer := 16;
        AIDBUF_ADDR_WIDTH  : integer := 6
    );
    port (
        clk_i              : in  std_logic;
        rst_i              : in  std_logic;

        minibuf_fe_i       : in  std_logic;
        minicam_full_i     : in  std_logic;
        available_ctrptr_i : in  std_logic;
        random_dly_i       : in  std_logic_vector(DELAY_WIDTH-1 downto 0);
        random_dly_o       : out std_logic_vector(DELAY_WIDTH-1 downto 0);

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

        ----- priority_queue interface -----
        pq_data_sr_o         : out std_logic_vector(PRIORITY_QUEUE_WIDTH*(DELAY_WIDTH+C_AXI_ID_WIDTH+MINIBUF_IDX_WIDTH)-1 downto 0);
        pq_data_o            : out std_logic_vector(C_AXI_ID_WIDTH+MINIBUF_IDX_WIDTH-1 downto 0);
        pq_en_o              : out std_logic;
        pq_ready_i           : in  std_logic
    );
end axi_parser;

architecture behavioral of axi_parser is

--******************************************************************************
-- Constants
--******************************************************************************
constant C_ZERO   : std_logic_vector(255 downto 0) := (others => '0'); -- create std_logic_vector for FIFO i/p leading zeros
--******************************************************************************
-- Components
--******************************************************************************

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
signal axi_info_wdata   : std_logic_vector(AXI_INFO_WIDTH-1 downto 0);
signal axi_info_wdata_q : std_logic_vector(AXI_INFO_WIDTH-1 downto 0);
signal axi_info_wr      : std_logic;
signal axi_info_af      : std_logic;
--signal axi_info_full    : std_logic;
signal axi_info_empty   : std_logic;
signal axi_info_valid   : std_logic;
signal axi_info_rdata   : std_logic_vector(AXI_INFO_WIDTH-1 downto 0);
signal axi_info_rd      : std_logic;

signal misc_fifo_din    : std_logic_vector(CTR_PTR_WIDTH + DELAY_WIDTH - 1 downto 0);
signal misc_fifo_dout   : std_logic_vector(CTR_PTR_WIDTH + DELAY_WIDTH - 1 downto 0);

-- misc. logic
signal s_axi_ready      : std_logic;
signal s_axi_last       : std_logic;
signal sb_index         : std_logic_vector(MINIBUF_IDX_WIDTH-1 downto 0);
signal mc_ctr_ptr_wr_q  : std_logic;
signal mc_ctr_ptr_q     : std_logic_vector(CTR_PTR_WIDTH-1 downto 0);
signal pq_data_sr       : std_logic_vector(PRIORITY_QUEUE_WIDTH*(DELAY_WIDTH+C_AXI_ID_WIDTH+MINIBUF_IDX_WIDTH)-1 downto 0);

--------------------------------------------------------------------------------
--attribute mark_debug : string;
--attribute DONT_TOUCH : string;
--attribute keep       : string;

--attribute mark_debug of axi_info_wr    : signal is "true";
--attribute mark_debug of axi_info_af    : signal is "true";
--attribute mark_debug of axi_info_valid : signal is "true";
--attribute DONT_TOUCH of axi_info_rdata : signal is "true";
--attribute mark_debug of axi_info_rd    : signal is "true";
--attribute mark_debug of minibuf_fe_i   : signal is "true";
--attribute mark_debug of pq_ready_i     : signal is "true";

--attribute keep of axi_info_rdata    : signal is "true";
--attribute keep of axi_info_wdata_q    : signal is "true";

--attribute DONT_TOUCH of pq_data_sr    : signal is "true";

--******************************************************************************
-- Connectivity and Logic
--******************************************************************************

begin

--------------------------------------------------------------------------------
-- Generate write enable for axi_info_fifo based on "bus cycle type" flags. These flags are based on the flags 
-- generated in axi_perf_mon_v5_0_10_flags_gen.v
--------------------------------------------------------------------------------
s_axi_last  <= s_axi_last_i when (CHANNEL_TYPE = "R" or CHANNEL_TYPE = "W") else '1';
s_axi_ready <= (not axi_info_af) and (not minibuf_fe_i);
--s_axi_ready <= (not axi_info_af) and (not minibuf_fe_i) and (pq_ready_i);

first_data_flag  <= s_axi_valid_i and s_axi_ready and (not acc_going_on);
mid_data_flag    <= s_axi_valid_i and s_axi_ready and acc_going_on and (not s_axi_last);
last_data_flag   <= s_axi_valid_i and s_axi_ready and s_axi_last;
rwaddr_resp_flag <= s_axi_valid_i and s_axi_ready;

-- acc_going_on (access in progress)
acc_ip_proc : process (clk_i, rst_i) begin
    if (rst_i = '1') then
        acc_going_on <= '0';
    elsif rising_edge(clk_i) then
        if (s_axi_valid_i = '1' and s_axi_ready = '1' and s_axi_last = '1') then -- last write flag
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
    mc_valid_o  <= rwaddr_resp_flag;  
    mc_axi_id_o <= s_axi_id_i;
end generate; 

-- generate fifo write enable for read or write data
data_flag_gen : if (CHANNEL_TYPE = "W" or CHANNEL_TYPE = "R") generate
    mc_valid_o  <= first_data_flag or mid_data_flag or last_data_flag; 
    mc_axi_id_o <= s_axi_id_i;
end generate;

--------------------------------------------------------------------------------
-- AXI Information FIFO - buffers all information from AXI events
--------------------------------------------------------------------------------

-- concatenate all axi input signals (outputs are not concatenated)

wdata_proc : process (clk_i, rst_i) begin
    if (rst_i = '1') then
        axi_info_wr       <= '0';  
        axi_info_wdata    <= (others => '0');
    elsif rising_edge(clk_i) then
        axi_info_wr       <= first_data_flag or mid_data_flag or last_data_flag; 
        axi_info_wdata    <= s_axi_resp_i & s_axi_id_i & s_axi_addr_i & s_axi_data_i & s_axi_strb_i & s_axi_len_i & s_axi_size_i & s_axi_burst_i & 
                             s_axi_lock_i  & s_axi_cache_i & s_axi_prot_i & s_axi_qos_i & s_axi_region_i & s_axi_valid_i & s_axi_last;
    end if;
end process;


--------------------------------------------------------------------------------
-- AXI Input Buffer:
-- This section contains the shallow FIFO implementation for buffering AXI events                    
--------------------------------------------------------------------------------
axi_info_rd <= (pq_ready_i) and (not axi_info_empty);

axi_info_fifo : entity fifo_sync
    GENERIC MAP (
        C_DEPTH      => AXI_INFO_DEPTH,
        C_DIN_WIDTH  => AXI_INFO_WIDTH,
        C_DOUT_WIDTH => AXI_INFO_WIDTH,
        C_THRESH     => 4
    ) 
PORT MAP (
        wr_clk      => clk_i,
        rst         => rst_i,

        din         => axi_info_wdata,
        prog_full   => axi_info_af,
        full        => OPEN,
        wr_en       => axi_info_wr,

        dout        => axi_info_rdata,
        prog_empty  => OPEN,
        empty       => axi_info_empty,
        valid       => axi_info_valid,
        rd_en       => axi_info_rd
  );

pq_data_repl_proc : process(random_dly_i, axi_info_rdata, mc_ctr_ptr_i) begin   
    pq_data_sr_loop :
        for j in 0 to PRIORITY_QUEUE_WIDTH-1 loop
          pq_data_sr((j+1)*(DELAY_WIDTH+C_AXI_ID_WIDTH+MINIBUF_IDX_WIDTH)-1 downto j*(DELAY_WIDTH+C_AXI_ID_WIDTH+MINIBUF_IDX_WIDTH)) <= 
              random_dly_i & axi_info_rdata(AXI_INFO_WIDTH-2-1 downto AXI_INFO_WIDTH-2-C_AXI_ID_WIDTH) & mc_ctr_ptr_i(CTR_PTR_WIDTH-1 downto (CTR_PTR_WIDTH-MINIBUF_IDX_WIDTH));
    end loop pq_data_sr_loop;            
end process;

--------------------------------------------------------------------------------
-- This will buffer addition information that has to be synchronized with the AXI packet information.
-- The timing of dout has to be synced with axi_info_fifo's dout.
--------------------------------------------------------------------------------

misc_fifo_din <= mc_ctr_ptr_i & random_dly_i;
 
misc_info_fifo : entity fifo_sync
    GENERIC MAP (
        C_DEPTH      => AXI_INFO_DEPTH,
        C_DIN_WIDTH  => CTR_PTR_WIDTH + DELAY_WIDTH,
        C_DOUT_WIDTH => CTR_PTR_WIDTH + DELAY_WIDTH,
        C_THRESH     => 4
    ) 
PORT MAP (
        wr_clk      => clk_i,
        rst         => rst_i,

        din         => misc_fifo_din,
        prog_full   => OPEN ,
        full        => OPEN,
        wr_en       => axi_info_wr, --mc_ctr_ptr_wr_i,

        dout        => misc_fifo_dout, --mc_ctr_ptr_q,
        prog_empty  => OPEN,
        empty       => OPEN,
        valid       => mc_ctr_ptr_wr_q,
        rd_en       => axi_info_rd
  );
  
mc_ctr_ptr_q <= misc_fifo_dout(CTR_PTR_WIDTH + DELAY_WIDTH - 1 downto DELAY_WIDTH);
random_dly_o <= misc_fifo_dout(DELAY_WIDTH - 1 downto 0);
  
sb_index     <= mc_ctr_ptr_q(CTR_PTR_WIDTH-1 downto (CTR_PTR_WIDTH-MINIBUF_IDX_WIDTH));

--------------------------------------------------------------------------------
-- AXI Input Buffer:
-- This section contains the register implementation
--------------------------------------------------------------------------------
-----  axi_info_proc : process (clk_i, rst_i) begin
-----      if (rst_i = '1') then
-----          axi_info_rd      <= '0';
-----          axi_info_af      <= '0';
-----          axi_info_valid   <= '0';
-----          axi_info_wdata_q <= (others => '0');
-----          axi_info_rdata   <= (others => '0');
-----          pq_data_sr       <= (others => '0');
-----      elsif rising_edge(clk_i) then
-----          axi_info_rd      <= axi_info_wr;
-----          axi_info_af      <= '0';
-----          axi_info_valid   <= axi_info_rd;
-----          axi_info_wdata_q <= axi_info_wdata;
-----          axi_info_rdata   <= axi_info_wdata_q;
-----  
-----          pq_data_sr_loop :
-----              for j in 0 to PRIORITY_QUEUE_WIDTH-1 loop
-----                pq_data_sr((j+1)*(DELAY_WIDTH+C_AXI_ID_WIDTH+MINIBUF_IDX_WIDTH)-1 downto j*(DELAY_WIDTH+C_AXI_ID_WIDTH+MINIBUF_IDX_WIDTH)) <= 
-----                    random_dly_i & axi_info_wdata_q(AXI_INFO_WIDTH-2-1 downto AXI_INFO_WIDTH-2-C_AXI_ID_WIDTH) & mc_ctr_ptr_i(CTR_PTR_WIDTH-1 downto (CTR_PTR_WIDTH-MINIBUF_IDX_WIDTH));
-----          end loop pq_data_sr_loop;            
-----  
-----      end if;
-----  end process;
-----  
-----  pipeline_proc : process (clk_i, rst_i) begin
-----      if (rst_i = '1') then
-----          mc_ctr_ptr_wr_q <= '0';
-----          mc_ctr_ptr_q    <= (others => '0');
-----      elsif rising_edge(clk_i) then
-----          mc_ctr_ptr_wr_q <= mc_ctr_ptr_wr_i;
-----          mc_ctr_ptr_q    <= mc_ctr_ptr_i;
-----      end if;
-----  end process;
-----  
-----  sb_index     <= mc_ctr_ptr_q(CTR_PTR_WIDTH-1 downto (CTR_PTR_WIDTH-MINIBUF_IDX_WIDTH));

----------------------------------------------------------------------------------------------
-- Output assignments
----------------------------------------------------------------------------------------------
s_axi_ready_o <= s_axi_ready;
mc_last_o     <= last_data_flag;

-----  pkt_buffer interface -----
pb_info_data_o   <= axi_info_rdata;
pb_cntr_ptr_o    <= mc_ctr_ptr_q;
pb_wr_o          <= axi_info_valid;

----- axi_id_buffer interface -----
aidb_id_o            <= axi_info_rdata(AXI_INFO_WIDTH-2-1 downto AXI_INFO_WIDTH-2-C_AXI_ID_WIDTH);
aidb_cntr_ptr_base_o <= sb_index;
aidb_wr_o            <= mc_ctr_ptr_wr_q;

----- priority_controller interface -----
-- pq_data_o contains (axi_id & sb_index), width = C_AXI_ID_WIDTH + MINIBUF_IDX_WIDTH
pq_data_sr_o <= pq_data_sr;
pq_data_o    <= axi_info_rdata(AXI_INFO_WIDTH-2-1 downto AXI_INFO_WIDTH-2-C_AXI_ID_WIDTH) & sb_index;
pq_en_o      <= mc_ctr_ptr_wr_q and axi_info_rdata(0);

----------------------------------------------------------------------------------------------
end behavioral;
