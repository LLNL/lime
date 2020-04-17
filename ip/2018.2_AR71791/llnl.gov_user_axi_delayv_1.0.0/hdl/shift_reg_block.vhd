--**********************************************************************************************************
-- Lawrence Livermore National Labs
-- 20200213 CM Initial creation, based on P.Srivastava's code
-- shift_reg_block.vhd:  Contains shift register logic.
--**********************************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.ext;

library axi_delay_lib;
use axi_delay_lib.axi_delay_pkg.all;

entity shift_reg_block is
generic (
    C_DELAY_WIDTH    : integer := 32;
    C_INDEX_WIDTH    : integer := 32;
    C_AXI_ID_WIDTH   : integer := 1;
	C_AXI_ADDR_WIDTH : integer := 32;
    C_AXI_DATA_WIDTH : integer := 32
);
port (
    clk_i           : in  std_logic;
    nreset_i        : in  std_logic;

    count_time_i    : in  std_logic_vector(31 downto 0); -- not sure what this is, all it does is count up and roll over
    index_srb_i     : in  std_logic_vector(31 downto 0);  -- this is the index (i.e. identifier) of THIS shift reg block
    delay_reg_o     : out std_logic_vector(C_DELAY_WIDTH-1 downto 0);
    id_reg_o        : out std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);
    valid_reg_o     : out std_logic;
    srb_insert_i    : in   integer;   -- lowest srb for insertion

    -- (delay & axi_id & sb_index) of the transaction (from axi_parser)
    din_i           : in  std_logic_vector(C_DELAY_WIDTH+C_INDEX_WIDTH+C_AXI_ID_WIDTH-1 downto 0);
    din_en_i        : in  std_logic;

    -- Top Channel from previous device (insertion, i.e. movement away from Priority Controller)
    s_data_i        : in  std_logic_vector(32+C_INDEX_WIDTH+C_AXI_ID_WIDTH-1 downto 0);
    s_data_en_i     : in  std_logic;

    -- Top Channel to next device (insertion, i.e. movement away from Priority Controller))
    m_data_o        : out std_logic_vector(32+C_INDEX_WIDTH+C_AXI_ID_WIDTH-1 downto 0);
    m_data_en_o     : out std_logic;

    -- Bottom Channel data from previous device (deletion, or pop, towards Priority Controller)
    s_shift_data_i  : in  std_logic_vector(32+C_INDEX_WIDTH+C_AXI_ID_WIDTH-1 downto 0);
    s_shift_valid_i : in  std_logic;
    s_shift_ready_o : out std_logic;

    -- Bottom Channel data to next device (deletion, or pop, towards Priority Controller), or output to Priority Controller
    m_shift_data_o  : out std_logic_vector(32+C_INDEX_WIDTH+C_AXI_ID_WIDTH-1 downto 0);
    m_shift_valid_o : out std_logic;
    m_shift_ready_i : in  std_logic
);
end shift_reg_block;

architecture behavioral of shift_reg_block is

--******************************************************************************
-- Constants
--******************************************************************************
constant DATA_WIDTH  : integer := C_AXI_ID_WIDTH + C_INDEX_WIDTH + 32;
constant ZEROS_ID    : std_logic_vector(31 downto C_DELAY_WIDTH) := (others => '0');

--******************************************************************************
--Signal Definitions
--******************************************************************************
signal delay_reg     : std_logic_vector(31 downto 0);
signal id_reg        : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);
signal index_reg     : std_logic_vector(C_INDEX_WIDTH-1 downto 0);
signal valid_reg     : std_logic;

signal delay_ip      : std_logic_vector(C_DELAY_WIDTH-1 downto 0);
signal id_ip         : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);
signal index_ip      : std_logic_vector(C_INDEX_WIDTH-1 downto 0);

signal debug_shift   : std_logic_vector(2 downto 0); -- for tracking "state" during simulation

--******************************************************************************
-- Connectivity and Logic
--******************************************************************************

begin

--------------------------------------------------------------------------------
-- din_i decode
--------------------------------------------------------------------------------
delay_ip <= din_i(C_DELAY_WIDTH+C_AXI_ID_WIDTH+C_INDEX_WIDTH-1 downto C_AXI_ID_WIDTH+C_INDEX_WIDTH);
id_ip    <= din_i(C_AXI_ID_WIDTH+C_INDEX_WIDTH-1               downto C_INDEX_WIDTH);
index_ip <= din_i(C_INDEX_WIDTH-1                              downto 0);

s_shift_ready_o <= m_shift_ready_i;

--------------------------------------------------------------------------------
-- Shift register
--------------------------------------------------------------------------------
shift_reg_proc : process (clk_i) begin
    if(rising_edge(clk_i)) then
       if (nreset_i = '0') then
        -- defaults
        id_reg         <= (others => '0');
        index_reg      <= (others => '0');
        delay_reg      <= (others => '1');
        valid_reg      <= '0';
        debug_shift    <= (others => '0');
        else
            debug_shift <= (others => '0');
            if (din_en_i = '1')then
                if (delay_ip < delay_reg) and (srb_insert_i < to_integer(unsigned(index_srb_i))) and s_data_en_i = '1' then
                    -- top channel receiving from left and sending right
                    -- receiving
                    if (s_data_i(32+C_AXI_ID_WIDTH+C_INDEX_WIDTH-1 downto C_AXI_ID_WIDTH+C_INDEX_WIDTH) > x"00000000") then
                        delay_reg   <= s_data_i(32+C_AXI_ID_WIDTH+C_INDEX_WIDTH-1 downto C_AXI_ID_WIDTH+C_INDEX_WIDTH) - '1';
                    else
                        delay_reg   <= (others => '0');
                    end if;
                    id_reg      <= s_data_i(C_AXI_ID_WIDTH+C_INDEX_WIDTH-1    downto C_INDEX_WIDTH);
                    index_reg   <= s_data_i(C_INDEX_WIDTH-1                   downto 0);
                    valid_reg   <= s_data_en_i;
                    debug_shift <= "001";
                elsif (delay_ip < delay_reg) and (srb_insert_i = to_integer(unsigned(index_srb_i))) then
                    -- top channel storing new information and sending right
                    -- receiving
                    if (ZEROS_ID & delay_ip) > x"00000000" then
                        delay_reg   <= (ZEROS_ID & delay_ip) - '1';
                    else
                        delay_reg   <= (others => '0');
                    end if;
                    id_reg      <= id_ip;
                    index_reg   <= index_ip;
                    valid_reg   <= din_en_i;          
                    debug_shift <= "010";
                elsif (valid_reg = '1') then
                    if (ZEROS_ID & delay_ip) > x"00000000" then
                        delay_reg   <= (ZEROS_ID & delay_ip) - '1';
                    else
                        delay_reg   <= (others => '0');
                    end if;
                end if;
            elsif (m_shift_ready_i = '1' and valid_reg = '1') then
                -- bottom channel pop and shift left
                -- shift left
                if (s_shift_data_i(32+C_AXI_ID_WIDTH+C_INDEX_WIDTH-1 downto C_AXI_ID_WIDTH+C_INDEX_WIDTH)) > x"00000000" then
                    delay_reg   <= s_shift_data_i(32+C_AXI_ID_WIDTH+C_INDEX_WIDTH-1 downto C_AXI_ID_WIDTH+C_INDEX_WIDTH) - '1';
                else 
                    delay_reg   <= (others => '0');
                end if;
                id_reg          <= s_shift_data_i(C_AXI_ID_WIDTH+C_INDEX_WIDTH-1    downto C_INDEX_WIDTH);
                index_reg       <= s_shift_data_i(C_INDEX_WIDTH-1                   downto 0);
                valid_reg       <= s_shift_valid_i;
                debug_shift     <= "100";
            else 
                -- decrement delay_reg, hold state on all other signals
                if (delay_reg > x"00000000") then
                    delay_reg <= delay_reg - '1';
                else
                    delay_reg <= (others => '0');
                end if;
            end if;
        end if;
    end if;
end process;

-- send right
m_data_o    <= delay_reg & id_reg & index_reg;
m_data_en_o <= (valid_reg and din_en_i);

-- pop or shift left
m_shift_data_o  <= delay_reg & id_reg & index_reg;
m_shift_valid_o <= (valid_reg and m_shift_ready_i);

----------------------------------------------------------------------------------------------
-- Output assignments
----------------------------------------------------------------------------------------------
delay_reg_o <= delay_reg(C_DELAY_WIDTH-1 downto 0);
id_reg_o    <= id_reg;
valid_reg_o <= valid_reg;

----------------------------------------------------------------------------------------------
end behavioral;
