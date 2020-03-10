--**********************************************************************************************************
-- Lawrence Livermore National Labs
-- 20200122 CM Initial creation 
-- priority_controller.vhd:  This priority_controller manages reading packets out of the packet_buffer and 
--                           other functions/processes related to this.
--**********************************************************************************************************
 
library ieee;
use ieee.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;

library axi_delay_lib;
use axi_delay_lib.all;
use axi_delay_lib.axi_delay_pkg.all;

entity priority_controller is
generic (
    DELAY_WIDTH         : integer := 16;
    NUM_MINI_BUFS       : integer := 32;
    CTR_PTR_WIDTH       : integer := 9;
    MINIBUF_IDX_WIDTH   : integer := 5;
    AXI_INFO_WIDTH      : integer := 256;
    C_AXI_ID_WIDTH      : integer := 16
);
port (
    clk_i               : in  std_logic;
    rst_i               : in  std_logic;
    
    scoreboard_valid_i  : in  std_logic_vector(NUM_MINI_BUFS-1 downto 0);     -- read valid output
    scoreboard_rd_idx_o : out integer;                                        -- read index (for clear)
    scoreboard_rd_clr_o : out std_logic;                                      -- read clear

    pq_dout_i           : in  std_logic_vector(DELAY_WIDTH+MINIBUF_IDX_WIDTH+C_AXI_ID_WIDTH-1 downto 0);
    pq_dout_valid_i     : in  std_logic;
    pq_dout_ready_o     : out std_logic;
    pq_count_time_i     : in  std_logic_vector(31 downto 0);

    pktbuf_enb_o        : out std_logic;                        -- packet buffer enable
    pktbuf_addrb_o      : out std_logic_vector(7 downto 0);     -- packet buffer address
    pktbuf_dinb_o       : out std_logic_vector(AXI_INFO_WIDTH-1 downto 0);  -- output data to packet_buffer
    pktbuf_doutb_i      : in  std_logic_vector(AXI_INFO_WIDTH-1 downto 0);  -- input data from packet buffer (for writing tlast)
    
    aidb_baddr_o        : out std_logic_vector(MINIBUF_IDX_WIDTH-1 downto 0);
    aidb_bdata_i        : in  std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);

    random_dly_i        : in  std_logic_vector(23 downto 0);
    random_dly_req_o    : out std_logic;

    free_ctrptr_wr_o    : out std_logic;                                  -- write to minibuf_fifo after packet has been read out of packet_buffer
    free_ctrptr_o       : out std_logic_vector(CTR_PTR_WIDTH-1 downto 0); -- write to minibuf_fifo after packet has been read out of packet_buffer

    axi_info_valid_o    : out std_logic;
    axi_info_data_o     : out std_logic_vector(AXI_INFO_WIDTH-1 downto 0) -- concatenated axi bus
);
end priority_controller;

architecture behavioral of priority_controller is

--******************************************************************************
-- Constants
--******************************************************************************
constant ARBITER_W : integer := NUM_MINI_BUFS; -- arbiter width, i.e. number of minibuffers

--******************************************************************************
--Signal Definitions
--******************************************************************************
-- priority queue interface
signal pq_mb_idx  : std_logic_vector(MINIBUF_IDX_WIDTH - 1 downto 0);
signal pq_axi_id  : std_logic_vector(C_AXI_ID_WIDTH - 1 downto 0);
signal pq_delay   : std_logic_vector(DELAY_WIDTH -1 downto 0);

-- arbiter signals
signal req        : std_logic_vector(NUM_MINI_BUFS-1 downto 0); -- arbiter request, i.e. scoreboard_valid
signal gnt        : std_logic_vector(NUM_MINI_BUFS-1 downto 0); -- arbiter grant, i.e. minibuffer to be serviced
signal double_req : std_logic_vector(2*ARBITER_W-1 downto 0);
signal double_gnt : std_logic_vector(2*ARBITER_W-1 downto 0);
signal priority   : std_logic_vector(ARBITER_W-1 downto 0);
signal last_req   : std_logic_vector(ARBITER_W-1 downto 0);
signal gnt_or     : std_logic; -- OR of all gnt bits
signal gnt_or_q   : std_logic; -- OR of all gnt bits

-- packet buffer i/o
signal pktbuf_enb          : std_logic;                   
signal pktbuf_addrb        : std_logic_vector(7 downto 0); 
signal pktbuf_addrb_ns     : std_logic_vector(7 downto 0); 
signal pktbuf_dinb         : std_logic_vector(AXI_INFO_WIDTH-1 downto 0);

-- scoreboard interface
signal scoreboard_rd_idx   : integer;
signal scoreboard_rd_idx_ns: integer;
signal scoreboard_rd_clr   : std_logic;
signal latch_sb_rd_idx     : std_logic;

-- misc.
signal free_ctrptr_wr      : std_logic;                  
signal free_ctrptr         : std_logic_vector(CTR_PTR_WIDTH-1 downto 0);
signal random_dly_int      : integer;
signal axi_info_data       : std_logic_vector(AXI_INFO_WIDTH-1 downto 0);
signal random_dly_req      : std_logic;

constant PBRDSM_IDLE       : std_logic_vector(2 downto 0) := "000";
constant PBRDSM_WAIT       : std_logic_vector(2 downto 0) := "001"; -- wait for req (scoreboard_valid)
constant PBRDSM_DLY        : std_logic_vector(2 downto 0) := "010"; -- count delay cycles
constant PBRDSM_RD_MINIBUF : std_logic_vector(2 downto 0) := "100"; -- read minibuffer 
signal   pbrd_cs           : std_logic_vector(2 downto 0) := "000";
signal   pbrd_ns           : std_logic_vector(2 downto 0) := "000";

signal gnt_bit           : integer;
signal base_minicam_addr : unsigned(31 downto 0);
signal ctr_ptr_addr      : unsigned(31 downto 0); 

--******************************************************************************
-- Connectivity and Logic
--******************************************************************************

begin

pq_delay  <= pq_dout_i(DELAY_WIDTH + C_AXI_ID_WIDTH + MINIBUF_IDX_WIDTH - 1 downto C_AXI_ID_WIDTH + MINIBUF_IDX_WIDTH);
pq_axi_id <= pq_dout_i(C_AXI_ID_WIDTH + MINIBUF_IDX_WIDTH - 1 downto MINIBUF_IDX_WIDTH);
pq_mb_idx <= pq_dout_i(MINIBUF_IDX_WIDTH - 1 downto 0);

---------------------------------------
-- Packet Buffer Read State Machine
-- This process will handle reading packets out of the packet_buffer. One packet is stored in each minibuffer;
-- A minibuffer will be read only when an entire packet has been written to it, as indicated by the minibuffer's 
-- scoreboard_valid ("req" to the arbiter) bit being asserted
---------------------------------------

random_dly_int <= to_integer(unsigned(random_dly_i));
gnt_bit <= to_integer(unsigned(pq_mb_idx));
gnt_or  <= pq_dout_valid_i;

pbrd_ns_proc: process(clk_i) begin
    if rising_edge(clk_i) then
        if (rst_i = '1') then
            scoreboard_rd_idx_ns <= 0;
            ctr_ptr_addr         <= (others => '0');
            base_minicam_addr    <= (others => '0');         
            pktbuf_addrb_ns      <= (others => '0');
            pbrd_ns              <= PBRDSM_IDLE;
        else
            if (latch_sb_rd_idx = '1') then
                scoreboard_rd_idx_ns <= scoreboard_rd_idx;
            end if;

        if (gnt_or = '1') then
            ctr_ptr_addr       <= to_unsigned(gnt_bit,32);
            base_minicam_addr  <= shift_left(to_unsigned(gnt_bit,32),2);
        end if;

            pktbuf_addrb_ns    <= pktbuf_addrb;
            pbrd_ns            <= pbrd_cs;
        end if;
    end if;
end process;

--gnt_bit            <= log2rp_long(gnt);
--ctr_ptr_addr       <= to_unsigned(gnt_bit,32);
--base_minicam_addr  <= shift_left(ctr_ptr_addr,2);

vcpsm_proc : process(pbrd_ns, gnt_or, gnt_bit, pktbuf_addrb, pktbuf_addrb_ns, pktbuf_doutb_i,
                     scoreboard_rd_idx_ns, base_minicam_addr, ctr_ptr_addr)
begin
    pktbuf_enb        <= '0';
    pktbuf_addrb      <= (others => '0');
    pktbuf_dinb       <= (others => '0');

    free_ctrptr_wr    <= '0';
    free_ctrptr       <= (others => '0');

    scoreboard_rd_idx <= 0;
    scoreboard_rd_clr <= '0';
    latch_sb_rd_idx   <= '0';

    axi_info_valid_o  <= '0';
    axi_info_data     <= (others => '0');

    random_dly_req   <= '0';

    case pbrd_ns is                                        
        when PBRDSM_IDLE =>
            random_dly_req   <= '1';
            pbrd_cs          <= PBRDSM_WAIT;

        when PBRDSM_WAIT =>  -- look for gnt, then read from packet buffer 
            if (gnt_or = '1') then
                pbrd_cs        <= PBRDSM_DLY;
            else
                pbrd_cs        <= PBRDSM_WAIT;
            end if;

        --  No longer counts cycles, but the extra delay is needed (for now)
        when PBRDSM_DLY => 
            pktbuf_enb      <= '1';
            latch_sb_rd_idx <= '1';

            pktbuf_addrb      <= std_logic_vector(base_minicam_addr(pktbuf_addrb'length-1 downto 0));
            free_ctrptr       <= std_logic_vector(ctr_ptr_addr(free_ctrptr'length-1 downto 0));
            free_ctrptr_wr    <= '1';
            scoreboard_rd_idx <= gnt_bit;

            pbrd_cs           <= PBRDSM_RD_MINIBUF;

        -- read the packet from the minibuffer
        when PBRDSM_RD_MINIBUF =>
            if (pktbuf_doutb_i(0) = '1') then -- If Tlast asserted, return to wait state. 
                scoreboard_rd_idx <= scoreboard_rd_idx_ns;
                scoreboard_rd_clr <= '1';

                axi_info_valid_o <= '1';
                axi_info_data    <= pktbuf_doutb_i;

                random_dly_req   <= '1';

                pbrd_cs          <= PBRDSM_WAIT;
            else   -- If Tlast not asserted, increment address and continue reading
                pktbuf_enb       <= '1';
                pktbuf_addrb     <= pktbuf_addrb_ns + '1';

                axi_info_valid_o <= '1';
                axi_info_data    <= pktbuf_doutb_i;

                pbrd_cs          <= PBRDSM_RD_MINIBUF;
            end if;                

        when others => 
            pbrd_cs <= PBRDSM_IDLE;
    
    end case;
end process;

----------------------------------------------------------------------------------------------
-- Output assignments
----------------------------------------------------------------------------------------------
pktbuf_enb_o     <= pktbuf_enb;
pktbuf_addrb_o   <= pktbuf_addrb;
pktbuf_dinb_o    <= pktbuf_dinb;

free_ctrptr_wr_o <= free_ctrptr_wr;
free_ctrptr_o    <= free_ctrptr;

axi_info_data_o  <= axi_info_data;

random_dly_req_o <= random_dly_req;

--Change assignment to improve timing
scoreboard_rd_idx_o <= scoreboard_rd_idx;
scoreboard_rd_clr_o <= latch_sb_rd_idx;

pq_dout_ready_o     <= '1' when (pbrd_ns = PBRDSM_WAIT) else '0'; 

----------------------------------------------------------------------------------------------
end behavioral;
