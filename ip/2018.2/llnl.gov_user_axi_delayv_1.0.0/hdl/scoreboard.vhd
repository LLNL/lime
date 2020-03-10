--**********************************************************************************************************
-- Lawrence Livermore National Labs
-- 20200122 CM Initial creation 
-- scoreboard.vhd:  This module implements the scoreboard function. It defines which of the minibuffers contain
--                  a complete packet, ready to be read out of the Packet Buffer/MiniBuffer. When a complete packet
--                  has been received, the associated scoreboard_valid bit will be asserted.
--                  When a packet has been completely read out of the associated MiniBuffer, its scoreboard_valid bit 
--                  will be reset.
--**********************************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;

library axi_delay_lib;
use axi_delay_lib.all;
use work.axi_delay_pkg.all;

entity scoreboard is

generic (
    NUM_MINI_BUFS     : integer := 32;   -- number of minibufs; each must be sized to hold the largest packet size supported
    MINIBUF_IDX_WIDTH : integer := 5    -- width of the MiniBuffer index 
);
port (
	s_clk_i             : in  std_logic;  -- "write" side clock
	s_rst_i             : in  std_logic;  -- "write" side reset

	m_clk_i             : in  std_logic; -- "read" side clock
	m_rst_i             : in  std_logic; -- "read" side reset

	scoreboard_wr_i     : in  std_logic;  -- write enable
	scoreboard_wr_idx_i : in  integer;    -- write index (for write)

	scoreboard_valid_o  : out std_logic_vector(NUM_MINI_BUFS-1 downto 0);     -- read valid output
	scoreboard_rd_idx_i : in  integer;                                        -- read index (for clear)
	scoreboard_rd_clr_i : in  std_logic                                       -- read clear
);
end scoreboard;

architecture behavioral of scoreboard is

--******************************************************************************
-- Constants
--******************************************************************************

--******************************************************************************
--Signal Definitions
--******************************************************************************
signal scoreboard_valid : std_logic_vector(NUM_MINI_BUFS-1 downto 0); -- scoreboard valid storage (s_clk domain)

--******************************************************************************
-- Connectivity and Logic
--******************************************************************************

begin

---------------------------------------
-- Scoreboard storage (s_clk_i) - assert sbvalid bit if scoreboard_wr_i = '1', deassert if scoreboard_clr_s = '1'
-- scoreboard_clr_s must be synchronized to s_clk_i and timed to concide with a synchronized scoreboard_rd_idx
---------------------------------------
sb_write_proc: process(s_clk_i) begin
    if rising_edge(s_clk_i) then
        if (s_rst_i = '1') then
            scoreboard_valid <= (others => '0');
        else
            if (scoreboard_wr_i = '1' and scoreboard_rd_clr_i = '1') then
                scoreboard_valid(scoreboard_wr_idx_i) <= '1';
                scoreboard_valid(scoreboard_rd_idx_i) <= '0';
            elsif (scoreboard_wr_i = '1') then
                scoreboard_valid(scoreboard_wr_idx_i) <= '1';
            elsif (scoreboard_rd_clr_i = '1') then
                scoreboard_valid(scoreboard_rd_idx_i) <= '0';
            end if;
        end if;
    end if;
end process;

----------------------------------------------------------------------------------------------
-- Output assignments
----------------------------------------------------------------------------------------------
scoreboard_valid_o <= scoreboard_valid;

----------------------------------------------------------------------------------------------
end behavioral;
