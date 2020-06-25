----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 2020-0317 11:38:00 PM
-- Design Name:
-- Module Name: fifo_sync - rtl
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;

library xpm;
use xpm.vcomponents.all;

entity fifo_sync is
  generic (
    C_DEPTH      : integer := 16;
    C_DIN_WIDTH  : integer := 256;
    C_DOUT_WIDTH : integer := 256;
    C_THRESH     : integer := 4
  );
  port (
    wr_clk     : in  std_logic;
    rst        : in  std_logic;
    din        : in  std_logic_vector(C_DIN_WIDTH-1 downto 0);
    prog_full  : out std_logic;
    full       : out std_logic;
    wr_en      : in  std_logic;

    rd_en      : in  std_logic;
    dout       : out std_logic_vector(C_DOUT_WIDTH-1 downto 0);
    empty      : out std_logic;
    valid      : out std_logic;
    prog_empty : out std_logic
  );
end fifo_sync;

architecture rtl of fifo_sync is

	-- return the number of bits needed to represent argument x
	function nbits (x : natural) return natural is
		variable i : natural;
	begin
		i := 0;
		while (x >= 2**i) loop
			i := i + 1;
		end loop;
		return i;
	end nbits;

	function factor (a, b : positive) return positive is
	begin
	   if (b < a) then return a/b; else return 1; end if;
	end factor;

	constant C_RD_DEPTH                      : integer := C_DEPTH*factor(C_DIN_WIDTH,C_DOUT_WIDTH);
	constant C_RD_DATA_COUNT_WIDTH           : integer := nbits(C_RD_DEPTH);
	constant C_WR_DEPTH                      : integer := C_DEPTH*factor(C_DOUT_WIDTH,C_DIN_WIDTH);
	constant C_WR_DATA_COUNT_WIDTH           : integer := nbits(C_WR_DEPTH);
	constant C_PROG_EMPTY_THRESH_ASSERT_VAL  : integer := C_THRESH-1;
	constant C_PROG_FULL_THRESH_ASSERT_VAL   : integer := C_WR_DEPTH-C_THRESH;

	signal wr_rst_busy  : std_logic;
	signal rd_rst_busy  : std_logic;

	signal wr_en_i      : std_logic;
	signal rd_en_i      : std_logic;
	signal full_i       : std_logic;
	signal empty_i      : std_logic;
	signal prog_full_i  : std_logic;
	signal prog_empty_i : std_logic;

begin

	-- qualify with wr_rst_busy or rd_rst_busy
	empty      <= empty_i or rd_rst_busy;
	prog_empty <= prog_empty_i or rd_rst_busy;
	full       <= full_i or wr_rst_busy;
    prog_full  <= prog_full_i or wr_rst_busy;
    wr_en_i    <= wr_en and not (full_i or wr_rst_busy);
	rd_en_i    <= rd_en and not (empty_i or rd_rst_busy);

  xpm_fifo_sync_inst : xpm_fifo_sync
  generic map (
     DOUT_RESET_VALUE    => "0",                            -- String
     ECC_MODE            => "no_ecc",                       -- String
     FIFO_MEMORY_TYPE    => "auto",                         -- String
     FIFO_READ_LATENCY   => 1,                              -- DECIMAL
     FIFO_WRITE_DEPTH    => C_WR_DEPTH,                     -- DECIMAL
     FULL_RESET_VALUE    => 0,                              -- DECIMAL
     PROG_EMPTY_THRESH   => C_PROG_EMPTY_THRESH_ASSERT_VAL, -- DECIMAL
     PROG_FULL_THRESH    => C_PROG_FULL_THRESH_ASSERT_VAL,  -- DECIMAL
     RD_DATA_COUNT_WIDTH => 1,                              -- DECIMAL
     READ_DATA_WIDTH     => C_DOUT_WIDTH,                   -- DECIMAL
     READ_MODE           => "std",                          -- String
     USE_ADV_FEATURES    => "1202",                         -- String
     WAKEUP_TIME         => 0,                              -- DECIMAL
     WRITE_DATA_WIDTH    => C_DIN_WIDTH,                    -- DECIMAL
     WR_DATA_COUNT_WIDTH => 1                               -- DECIMAL
  )
  port map (
     almost_empty => OPEN,           -- 1-bit output: Almost Empty : When asserted, this signal indicates that
                                     -- only one more read can be performed before the FIFO goes to empty.

     almost_full => OPEN,            -- 1-bit output: Almost Full: When asserted, this signal indicates that
                                     -- only one more write can be performed before the FIFO is full.

     data_valid => valid,            -- 1-bit output: Read Data Valid: When asserted, this signal indicates
                                     -- that valid data is available on the output bus (dout).

     dbiterr => OPEN,                -- 1-bit output: Double Bit Error: Indicates that the ECC decoder
                                     -- detected a double-bit error and data in the FIFO core is corrupted.

     dout => dout,                   -- READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
                                     -- when reading the FIFO.

     empty => empty_i,               -- 1-bit output: Empty Flag: When asserted, this signal indicates that
                                     -- the FIFO is empty. Read requests are ignored when the FIFO is empty,
                                     -- initiating a read while empty is not destructive to the FIFO.

     full => full_i,                   -- 1-bit output: Full Flag: When asserted, this signal indicates that the
                                     -- FIFO is full. Write requests are ignored when the FIFO is full,
                                     -- initiating a write when the FIFO is full is not destructive to the
                                     -- contents of the FIFO.

     overflow => OPEN,               -- 1-bit output: Overflow: This signal indicates that a write request
                                     -- (wren) during the prior clock cycle was rejected, because the FIFO is
                                     -- full. Overflowing the FIFO is not destructive to the contents of the
                                     -- FIFO.

     prog_empty => prog_empty_i,     -- 1-bit output: Programmable Empty: This signal is asserted when the
                                     -- number of words in the FIFO is less than or equal to the programmable
                                     -- empty threshold value. It is de-asserted when the number of words in
                                     -- the FIFO exceeds the programmable empty threshold value.

     prog_full => prog_full_i,       -- 1-bit output: Programmable Full: This signal is asserted when the
                                     -- number of words in the FIFO is greater than or equal to the
                                     -- programmable full threshold value. It is de-asserted when the number
                                     -- of words in the FIFO is less than the programmable full threshold
                                     -- value.

     rd_data_count => OPEN,          -- RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates
                                     -- the number of words read from the FIFO.

     rd_rst_busy => rd_rst_busy,     -- 1-bit output: Read Reset Busy: Active-High indicator that the FIFO
                                     -- read domain is currently in a reset state.

     sbiterr => OPEN,                -- 1-bit output: Single Bit Error: Indicates that the ECC decoder
                                     -- detected and fixed a single-bit error.

     underflow => OPEN,              -- 1-bit output: Underflow: Indicates that the read request (rd_en)
                                     -- during the previous clock cycle was rejected because the FIFO is
                                     -- empty. Under flowing the FIFO is not destructive to the FIFO.

     wr_ack => OPEN,                 -- 1-bit output: Write Acknowledge: This signal indicates that a write
                                     -- request (wr_en) during the prior clock cycle is succeeded.

     wr_data_count => OPEN,          -- WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates
                                     -- the number of words written into the FIFO.

     wr_rst_busy => wr_rst_busy,     -- 1-bit output: Write Reset Busy: Active-High indicator that the FIFO
                                     -- write domain is currently in a reset state.

     din => din,                     -- WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
                                     -- writing the FIFO.

     injectdbiterr => '0',           -- 1-bit input: Double Bit Error Injection: Injects a double bit error if
                                     -- the ECC feature is used on block RAMs or UltraRAM macros.

     injectsbiterr => '0',           -- 1-bit input: Single Bit Error Injection: Injects a single bit error if
                                     -- the ECC feature is used on block RAMs or UltraRAM macros.

     rd_en => rd_en_i,               -- 1-bit input: Read Enable: If the FIFO is not empty, asserting this
                                     -- signal causes data (on dout) to be read from the FIFO. Must be held
                                     -- active-low when rd_rst_busy is active high. .

     rst => rst,                     -- 1-bit input: Reset: Must be synchronous to wr_clk. Must be applied
                                     -- only when wr_clk is stable and free-running.

     sleep => '0',                   -- 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo
                                     -- block is in power saving mode.

     wr_clk => wr_clk,               -- 1-bit input: Write clock: Used for write operation. wr_clk must be a
                                     -- free running clock.

     wr_en => wr_en_i                -- 1-bit input: Write Enable: If the FIFO is not full, asserting this
                                     -- signal causes data (on din) to be written to the FIFO Must be held
                                     -- active-low when rst or wr_rst_busy or rd_rst_busy is active high

  );
end rtl;