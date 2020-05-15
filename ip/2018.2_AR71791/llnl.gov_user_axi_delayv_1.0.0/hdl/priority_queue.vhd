--**********************************************************************************************************
-- Lawrence Livermore National Labs
-- 20200213 CM Initial creation, based on P.Srivastava's code
-- priority_queue.vhd:  Priority Queue - contains all shift register blocks and associated logic/connectivity.
--**********************************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library axi_delay_lib;
use axi_delay_lib.axi_delay_pkg.all;
use axi_delay_lib.shift_reg_block;

entity priority_queue is
generic (
    PRIORITY_QUEUE_WIDTH : integer := 32;
    DELAY_WIDTH          : integer := 32;
    INDEX_WIDTH          : integer := 32;
    C_AXI_ID_WIDTH       : integer := 1;
    C_AXI_ADDR_WIDTH     : integer := 32;
    C_AXI_DATA_WIDTH     : integer := 32;
    MINIBUF_IDX_WIDTH    : integer := 6
);
port (
    clk_i         : in  std_logic;
    nreset_i      : in  std_logic;

    -- (delay & axi_id & sb_index) of the transaction (from axi_parser)
    din_sr_i      : in  std_logic_vector(PRIORITY_QUEUE_WIDTH*(DELAY_WIDTH+C_AXI_ID_WIDTH+MINIBUF_IDX_WIDTH)-1 downto 0);
    din_i         : in  std_logic_vector(DELAY_WIDTH+INDEX_WIDTH+C_AXI_ID_WIDTH-1 downto 0);
    din_en_i      : in  std_logic;
    din_ready_o   : out std_logic;

    -- (delay & axi_id & sb_index) of the transaction (to priority controller)
    dout_o        : out std_logic_vector(DELAY_WIDTH+INDEX_WIDTH+C_AXI_ID_WIDTH-1 downto 0);
    dout_valid_o  : out std_logic;
    dout_ready_i  : in  std_logic;
    axi_id_ins_err_o : out std_logic   -- axi_id insertione erro (no availble SRB)
);
end priority_queue;

architecture behavioral of priority_queue is

--******************************************************************************
-- Constants
--******************************************************************************

--******************************************************************************
--Signal Definitions
--******************************************************************************
type dat is array (0 to PRIORITY_QUEUE_WIDTH-1) of std_logic_vector(DELAY_WIDTH+INDEX_WIDTH+C_AXI_ID_WIDTH-1 downto 0);
signal s_shift_data    : dat;
signal m_shift_data    : dat;
signal m_data          : dat;
signal s_data          : dat;
type delay_array is array (0 to PRIORITY_QUEUE_WIDTH-1) of std_logic_vector(DELAY_WIDTH-1 downto 0);
signal delay_reg       : delay_array  := (others => (others => '0'));
type id_array is array (0 to PRIORITY_QUEUE_WIDTH-1) of std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);
signal id_reg          : id_array  := (others => (others => '0'));

signal valid_reg       : std_logic_vector(PRIORITY_QUEUE_WIDTH-1 downto 0);
signal delay_new       : std_logic_vector(DELAY_WIDTH-1 downto 0) := (others => '0');   
signal delay_srb_low   : integer := 0; -- lowest srb for delay insertion
signal axi_id_new      : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
signal axi_id_max_hi   : integer := 0; -- highest SRB with matching axi_id
signal srb_insert      : integer := 0;

type bit_signal is array (0 to PRIORITY_QUEUE_WIDTH-1) of std_logic;
signal s_shift_valid   : bit_signal;
signal s_shift_ready   : bit_signal;
signal m_shift_valid   : bit_signal;
signal m_shift_ready   : bit_signal;
signal m_data_en       : bit_signal;
signal s_data_en       : bit_signal;

signal dout_ready      : std_logic;

--------------------------------------------------------------------------------
--attribute mark_debug : string;

--attribute mark_debug of din_i           : signal is "true";
--attribute mark_debug of din_en_i        : signal is "true";
--attribute mark_debug of din_ready_o     : signal is "true";

--attribute mark_debug of dout_o          : signal is "true";
--attribute mark_debug of dout_valid_o    : signal is "true";
--attribute mark_debug of dout_ready_i    : signal is "true";
--attribute mark_debug of axi_id_ins_err_o: signal is "true";

--attribute mark_debug of delay_reg       : signal is "true";
--attribute mark_debug of id_reg          : signal is "true";
--attribute mark_debug of valid_reg       : signal is "true";
--attribute mark_debug of srb_insert      : signal is "true";
--attribute mark_debug of delay_srb_low   : signal is "true";
--attribute mark_debug of axi_id_max_hi   : signal is "true";
--attribute mark_debug of delay_new       : signal is "true";
--attribute mark_debug of axi_id_new      : signal is "true";

--attribute mark_debug of m_data_en       : signal is "true";
--attribute mark_debug of s_data_en       : signal is "true";

--attribute mark_debug of m_shift_valid   : signal is "true";
--attribute mark_debug of m_shift_ready   : signal is "true";
--attribute mark_debug of s_shift_valid   : signal is "true";
--attribute mark_debug of s_shift_ready   : signal is "true";


--******************************************************************************
-- Connectivity and Logic
--******************************************************************************

begin

dout_ready    <= '1' when (dout_ready_i = '1' and din_en_i = '0' and (delay_reg(0) = x"000000")) else
                 '0';

GEN_shift_reg_blocks :
for i in 0 to PRIORITY_QUEUE_WIDTH-1 generate

    srb : entity axi_delay_lib.shift_reg_block
        generic map(
        C_DELAY_WIDTH     => DELAY_WIDTH,
        C_INDEX_WIDTH     => INDEX_WIDTH,
        C_AXI_ID_WIDTH    => C_AXI_ID_WIDTH,
        C_AXI_ADDR_WIDTH  => C_AXI_ADDR_WIDTH,
        C_AXI_DATA_WIDTH  => C_AXI_DATA_WIDTH
    )
    port map(
        clk_i             => clk_i,
        nreset_i          => nreset_i,
        delay_reg_o       => delay_reg(i),
        id_reg_o          => id_reg(i),
        valid_reg_o       => valid_reg(i),
        srb_insert_i      => srb_insert,

        -- input from Priority controller (deletion, or pop, towards Priority Controller)
        index_srb_i       => std_logic_vector(to_unsigned(i, 32)),
        din_i             => din_sr_i((i+1)*(DELAY_WIDTH+C_AXI_ID_WIDTH+MINIBUF_IDX_WIDTH)-1 downto i*(DELAY_WIDTH+C_AXI_ID_WIDTH+MINIBUF_IDX_WIDTH)),
--        din_i             => din_i,
        din_en_i          => din_en_i,

        -- Top Channel from previous device
        s_data_i          => s_data(i),
        s_data_en_i       => s_data_en(i),

        -- Top Channel to next device
        m_data_o          => m_data(i),
        m_data_en_o       => m_data_en(i),
        
        -- Bottom Channel data from previous device (deletion, or pop, towards Priority Controller)
        s_shift_data_i    => s_shift_data(i),
        s_shift_valid_i   => s_shift_valid(i),
        s_shift_ready_o   => s_shift_ready(i),

        -- Bottom Channel data to next device (deletion, or pop, towards Priority Controller), or output to Priority Controller
        m_shift_data_o    => m_shift_data(i),
        m_shift_valid_o   => m_shift_valid(i),
        m_shift_ready_i   => m_shift_ready(i)
    );

    -- head register block assignments
    head_queue : if i = 0 generate
        s_data(i)        <= (others => '0');
        s_data_en(i)     <= '0';

        s_shift_data(i)  <= m_shift_data(i+1);
        s_shift_valid(i) <= m_shift_valid(i+1);

        m_shift_ready(i) <= dout_ready;
    end generate head_queue;

    -- tail register block assignments
    tail_queue : if i = PRIORITY_QUEUE_WIDTH-1 generate
        s_data(i)        <= m_data(i-1);
        s_data_en(i)     <= m_data_en(i-1);

        s_shift_data(i)  <= (others => '1');
        s_shift_valid(i) <= '0';

        m_shift_ready(i) <= s_shift_ready(i-1);
    end generate tail_queue;

    -- middle register block assignments
    middle_queue : if i>0 and i<PRIORITY_QUEUE_WIDTH-1 generate
        s_data(i)        <= m_data(i-1);
        s_data_en(i)     <= m_data_en(i-1);

        s_shift_data(i)  <= m_shift_data(i+1);
        s_shift_valid(i) <= m_shift_valid(i+1);

        m_shift_ready(i) <= s_shift_ready(i-1);
    end generate middle_queue;

end generate GEN_shift_reg_blocks;

----------------------------------------------------------------------------------------------
-- Insertion Check loop
-- A loop is required to determine exactly which srb to store the new packet information (delay, id, index).
-- Two checks are needed - (1) an AXI ID check to ensure that the new packet is inserted *after* 
-- any packets with the same AXI ID that are already in the SRB, and (2) a delay check to ensure that 
-- the new packet is inserted in the correct SRB.
--
-- The AXI ID loop will determine the highest numbered SRB (i.e. lowest priority) which contains a packet
-- with the same SRB (if any) - let's call this SRB# n. Then the delay loop will check SRB # n+1 through
-- PRIORITY_QUEUE_WIDTH-1 to determine where to place the new packet.
--
-- There will often be multiple srb's where the stored delay (delay_reg) is greater than the delay.
-- This loop determines which of these is the *first* srb (i.e. lowest number) where its stored delay
-- is higher than the new packet's delay. The new packet info is stored in this one, all others are
-- shifted left

-- NOTE (2020-0422): The timing of this path is horrible (~0.35ns worst case). Although the design works
-- in hardware, this must be fixed, and the only way is to pipeline this path. There may be a corner
-- case that occurs in HW testing that doesn't show up in simulation, so take note during hardware operation.
----------------------------------------------------------------------------------------------

delay_new  <= din_i(DELAY_WIDTH+C_AXI_ID_WIDTH+INDEX_WIDTH-1 downto C_AXI_ID_WIDTH+INDEX_WIDTH);
axi_id_new <= din_i(C_AXI_ID_WIDTH+INDEX_WIDTH-1 downto INDEX_WIDTH);

axi_id_chk_loop_proc : process (din_en_i, valid_reg, axi_id_new, id_reg) begin
    axi_id_chk_loop: for kk in (PRIORITY_QUEUE_WIDTH-1) downto 0 loop
        if (din_en_i = '1') and valid_reg(kk) = '1' and (axi_id_new = id_reg(kk)) then
            axi_id_max_hi <= kk;
            exit axi_id_chk_loop when (din_en_i = '1') and (axi_id_new = id_reg(kk)); -- same as if condition
        else
            axi_id_max_hi <= 0;
        end if;
    end loop;
end process;

axi_id_ins_err_o <= '1' when (axi_id_max_hi = (PRIORITY_QUEUE_WIDTH-1)) else '0';

ins_chk_loop_proc : process (din_en_i, delay_new, delay_reg) begin
    insert_check_loop: for jj in 0 to (PRIORITY_QUEUE_WIDTH-1) loop
        if (din_en_i = '1') and (delay_new <  delay_reg(jj)) then
            delay_srb_low <= jj;
            exit insert_check_loop when (delay_new <  delay_reg(jj)); -- same as if condition
        end if;
    end loop;   
end process;

srb_insert <= axi_id_max_hi when (axi_id_max_hi > delay_srb_low) else delay_srb_low;

----------------------------------------------------------------------------------------------
-- Output assignments
----------------------------------------------------------------------------------------------
din_ready_o <= '1';

dout_o           <= m_shift_data(0)(DELAY_WIDTH+INDEX_WIDTH+C_AXI_ID_WIDTH-1 downto 0);
dout_valid_o     <= m_shift_valid(0);

----------------------------------------------------------------------------------------------
end behavioral;
