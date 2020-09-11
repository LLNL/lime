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
    SIMULATION           : std_logic := '0';
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
    counter_i     : in   std_logic_vector(DELAY_WIDTH-1 downto 0);
    
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
constant C_ZERO   : std_logic_vector(PRIORITY_QUEUE_WIDTH-1 downto 0) := (others => '0');

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
signal ddiff           : delay_array  := (others => (others => '0'));
type id_array is array (0 to PRIORITY_QUEUE_WIDTH-1) of std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);
signal id_reg          : id_array  := (others => (others => '0'));
signal tdiff           : std_logic_vector(DELAY_WIDTH-1 downto 0); -- time diff, compare counter with timestamp in output SRB

signal valid_reg       : std_logic_vector(PRIORITY_QUEUE_WIDTH-1 downto 0);
signal delay_new       : std_logic_vector(DELAY_WIDTH-1 downto 0) := (others => '0');   
signal delay_srb_low   : integer := 0; -- lowest srb for delay insertion
signal axi_id_new      : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
signal axi_id_max_hi   : integer := 0; -- highest SRB with matching axi_id
signal srb_insert      : integer := 0;
signal found_axi_id    : std_logic := '0';
signal din_ready       : std_logic := '0';

type bit_signal is array (0 to PRIORITY_QUEUE_WIDTH-1) of std_logic;
signal s_shift_valid   : bit_signal;
signal s_shift_ready   : bit_signal;
signal m_shift_valid   : bit_signal;
signal m_shift_ready   : bit_signal;
signal m_data_en       : bit_signal;
signal s_data_en       : bit_signal;

signal dout_ready      : std_logic;

----------------------------------------------------------------------------------------------
-- FOR DEBUG (CHIPSCOPE) ONLY
----------------------------------------------------------------------------------------------
signal CS_id_reg        : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0) := (others => '0');  
signal CS_valid_reg     : std_logic_vector(PRIORITY_QUEUE_WIDTH-1 downto 0);
signal CS_delay_srb_low : integer := 0; -- lowest srb for delay insertion
signal CS_axi_id_max_hi : integer := 0;
signal CS_srb_insert    : integer := 0;
signal CS_found_axi_id  : std_logic;
signal CS_din_ready     : std_logic;
signal CS_dout          : std_logic_vector(DELAY_WIDTH+INDEX_WIDTH+C_AXI_ID_WIDTH-1 downto 0);
signal CS_dout_valid    : std_logic;
signal CS_dout_ready    : std_logic;
signal CS_din           : std_logic_vector(DELAY_WIDTH+INDEX_WIDTH+C_AXI_ID_WIDTH-1 downto 0);
signal CS_din_en        : std_logic;

signal CS_dout_ready_i  : std_logic;
signal CS_din_en_i      : std_logic;
signal CS_tdiff         : std_logic_vector(DELAY_WIDTH-1 downto 0); 
signal CS_ddiff         : delay_array  := (others => (others => '0'));
signal CS_delay_reg_0   : std_logic_vector(DELAY_WIDTH-1 downto 0);
signal CS_counter_i     : std_logic_vector(DELAY_WIDTH-1 downto 0);

attribute mark_debug : string;
attribute mark_debug of CS_id_reg        : signal is "true"; 
attribute mark_debug of CS_valid_reg     : signal is "true";
attribute mark_debug of CS_delay_srb_low : signal is "true"; 
attribute mark_debug of CS_axi_id_max_hi : signal is "true"; 
attribute mark_debug of CS_srb_insert    : signal is "true"; 
attribute mark_debug of CS_found_axi_id  : signal is "true"; 
attribute mark_debug of CS_din_ready     : signal is "true";
attribute mark_debug of CS_dout          : signal is "true";
attribute mark_debug of CS_dout_valid    : signal is "true";
attribute mark_debug of CS_dout_ready    : signal is "true";
attribute mark_debug of CS_din           : signal is "true";
attribute mark_debug of CS_din_en        : signal is "true";

attribute mark_debug of CS_dout_ready_i  : signal is "true";
attribute mark_debug of CS_din_en_i      : signal is "true";
attribute mark_debug of CS_tdiff         : signal is "true";
attribute mark_debug of CS_ddiff         : signal is "true";
attribute mark_debug of CS_delay_reg_0   : signal is "true";
attribute mark_debug of CS_counter_i     : signal is "true";


--******************************************************************************
-- Connectivity and Logic
--******************************************************************************

begin

tdiff         <= std_logic_vector(unsigned(delay_reg(0)) - unsigned(counter_i));

dout_ready    <= dout_ready_i and not din_en_i and (tdiff(tdiff'high));

--dout_ready    <= '1' when (dout_ready_i = '1' and din_en_i = '0' and (delay_reg(0) = x"000000")) else
--                 '0';

GEN_shift_reg_blocks :
for i in 0 to PRIORITY_QUEUE_WIDTH-1 generate

    srb : entity axi_delay_lib.shift_reg_block
        generic map(
        C_DELAY_WIDTH     => DELAY_WIDTH,
        C_INDEX_WIDTH     => MINIBUF_IDX_WIDTH, --INDEX_WIDTH,
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
--        din_i             => din_sr_i((i+1)*(DELAY_WIDTH+C_AXI_ID_WIDTH+MINIBUF_IDX_WIDTH)-1 downto i*(DELAY_WIDTH+C_AXI_ID_WIDTH+MINIBUF_IDX_WIDTH)),
        din_i             => din_i,
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

-- NOTE (2020-0422): The timing of this path is extremly poor. Although the design works
-- in simulation, it only works in hardware at slower clock speeds. This may need fixing, and the only way 
-- is to pipeline this path. 
----------------------------------------------------------------------------------------------

delay_new  <= din_i(DELAY_WIDTH+C_AXI_ID_WIDTH+INDEX_WIDTH-1 downto C_AXI_ID_WIDTH+INDEX_WIDTH);
axi_id_new <= din_i(C_AXI_ID_WIDTH+INDEX_WIDTH-1 downto INDEX_WIDTH);

axi_id_chk_loop_proc : process (din_en_i, valid_reg, axi_id_new, id_reg) begin
    axi_id_chk_loop: for kk in (PRIORITY_QUEUE_WIDTH-1) downto 0 loop
        if (din_en_i = '1') and valid_reg(kk) = '1' and (axi_id_new = id_reg(kk)) then
            axi_id_max_hi <= kk + 1;
            found_axi_id  <= '1';
            exit axi_id_chk_loop when (din_en_i = '1') and valid_reg(kk) = '1' and (axi_id_new = id_reg(kk)); -- same as if condition
        else
            axi_id_max_hi <= 0;
            found_axi_id  <= '0';
        end if;
    end loop;
end process;

axi_id_ins_err_o <= '1' when (axi_id_max_hi = (PRIORITY_QUEUE_WIDTH-1)) else '0';

gen_diff_array_proc : process (delay_new, delay_reg) begin
    gen_diff_loop : for ii in 0 to (PRIORITY_QUEUE_WIDTH-1) loop
        ddiff(ii)     <= std_logic_vector(unsigned(delay_reg(ii)) - unsigned(delay_new));
    end loop;
end process;

ins_chk_loop_proc : process (din_en_i, valid_reg, ddiff) begin
    insert_check_loop: for jj in 0 to (PRIORITY_QUEUE_WIDTH-1) loop
        if (din_en_i = '1') and (valid_reg = C_ZERO) then
            delay_srb_low <= 0;
            exit insert_check_loop;
        elsif (din_en_i = '1') and (ddiff(jj)(DELAY_WIDTH-1) = '0') then
            delay_srb_low <= jj;
            exit insert_check_loop;
        elsif (din_en_i = '1') and (valid_reg(jj) = '0') then
            delay_srb_low <= jj;
            exit insert_check_loop;
        end if;
    end loop;
end process;

srb_insert <= (axi_id_max_hi) when (found_axi_id = '1') and (axi_id_max_hi > delay_srb_low) else delay_srb_low;

din_ready  <= '1' when (valid_reg(PRIORITY_QUEUE_WIDTH-3) = '0') else '0';

----------------------------------------------------------------------------------------------
-- Output assignments
----------------------------------------------------------------------------------------------
din_ready_o <= din_ready;

dout_o           <= m_shift_data(0)(DELAY_WIDTH+INDEX_WIDTH+C_AXI_ID_WIDTH-1 downto 0);
dout_valid_o     <= m_shift_valid(0);

----------------------------------------------------------------------------------------------
-- Global signals for Guassian Delay Table Analysis
----------------------------------------------------------------------------------------------
gen_SIMout: if (SIMULATION = '1') generate
    SIM_clk           <= clk_i;
    SIM_nreset        <= nreset_i;
    SIM_random_dly    <= din_i(DELAY_WIDTH+C_AXI_ID_WIDTH+INDEX_WIDTH-1 downto C_AXI_ID_WIDTH+INDEX_WIDTH);
    SIM_random_dly_en <= din_en_i;
end generate gen_SIMout;

----------------------------------------------------------------------------------------------
-- FOR DEBUG (CHIPSCOPE) ONLY
----------------------------------------------------------------------------------------------
CHIPSCOPE_proc : process (clk_i, nreset_i) begin
    if (nreset_i = '0') then
      CS_id_reg        <= (others => '0');
      CS_valid_reg     <= (others => '0');
      CS_delay_srb_low <= 0;
      CS_axi_id_max_hi <= 0;
      CS_srb_insert    <= 0;
      CS_found_axi_id  <= '0';
      CS_din_ready     <= '0';
      CS_dout          <= (others => '0');
      CS_dout_valid    <= '0';
      CS_dout_ready    <= '0';  
      
      CS_din           <= (others => '0');
      CS_din_en        <= '0';
      
      CS_dout_ready_i  <= '0';
      CS_din_en_i      <= '0';
      CS_tdiff         <= (others => '0');
      CS_ddiff         <= (others => (others => '0'));
      CS_delay_reg_0   <= (others => '0');
      CS_counter_i     <= (others => '0');

    elsif rising_edge(clk_i) then
      CS_id_reg        <= id_reg(0);
      CS_valid_reg     <= valid_reg;
      CS_delay_srb_low <= delay_srb_low;
      CS_axi_id_max_hi <= axi_id_max_hi;
      CS_srb_insert    <= srb_insert;
      CS_found_axi_id  <= found_axi_id;
      CS_din_ready     <= din_ready;
      CS_dout          <= m_shift_data(0)(DELAY_WIDTH+INDEX_WIDTH+C_AXI_ID_WIDTH-1 downto 0);
      CS_dout_valid    <= m_shift_valid(0);
      CS_dout_ready    <= dout_ready;
      
      CS_din           <= din_i;
      CS_din_en        <= din_en_i;

      CS_dout_ready_i  <= dout_ready_i;
      CS_din_en_i      <= din_en_i;    
      CS_tdiff         <= tdiff;       
      CS_ddiff         <= ddiff;
      CS_delay_reg_0   <= delay_reg(0); 
      CS_counter_i     <= counter_i;   

    end if;
end process;

----------------------------------------------------------------------------------------------
end behavioral;