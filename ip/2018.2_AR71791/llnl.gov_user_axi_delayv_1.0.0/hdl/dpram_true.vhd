----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 2020-0317 11:38:00 PM
-- Design Name:
-- Module Name: dpram_true - rtl
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

entity dpram_true is
  generic (
    ADDR_WIDTH       : integer := 8;
    DATA_WIDTH       : integer := 256;
    CLOCKING_MODE    : string  := "independent_clock";
    MEMORY_INIT_FILE : string  := "bram_del_table.coe"
  );
  port (
    clka  : IN  STD_LOGIC;
    rsta  : IN  STD_LOGIC;
    ena   : IN  STD_LOGIC;
    wea   : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN  STD_LOGIC_VECTOR(ADDR_WIDTH-1 DOWNTO 0);
    dina  : IN  STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
    
    clkb  : IN  STD_LOGIC;
    rstb  : IN  STD_LOGIC;
    enb   : IN  STD_LOGIC;
    web   : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);
    addrb : IN  STD_LOGIC_VECTOR(ADDR_WIDTH-1 DOWNTO 0);
    dinb  : IN  STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0)
  );
end dpram_true;

architecture rtl of dpram_true is

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

begin

xpm_memory_tdpram_inst : xpm_memory_tdpram
    generic map (
       ADDR_WIDTH_A => ADDR_WIDTH,          -- DECIMAL
       ADDR_WIDTH_B => ADDR_WIDTH,          -- DECIMAL
       AUTO_SLEEP_TIME => 0,                -- DECIMAL
       BYTE_WRITE_WIDTH_A => DATA_WIDTH,    -- DECIMAL
       BYTE_WRITE_WIDTH_B => DATA_WIDTH,    -- DECIMAL
       CLOCKING_MODE => "common_clock",     -- String
       ECC_MODE => "no_ecc",                -- String
       MEMORY_INIT_FILE => MEMORY_INIT_FILE,-- String
       MEMORY_INIT_PARAM => "0",            -- String
       MEMORY_OPTIMIZATION => "true",       -- String
       MEMORY_PRIMITIVE => "auto",          -- String
       MEMORY_SIZE => (2**ADDR_WIDTH)*DATA_WIDTH, -- DECIMAL
       MESSAGE_CONTROL => 0,                -- DECIMAL
       READ_DATA_WIDTH_A => DATA_WIDTH,     -- DECIMAL
       READ_DATA_WIDTH_B => DATA_WIDTH,     -- DECIMAL
       READ_LATENCY_A => 1,                 -- DECIMAL
       READ_LATENCY_B => 1,                 -- DECIMAL
       READ_RESET_VALUE_A => "0",           -- String
       READ_RESET_VALUE_B => "0",           -- String
       USE_EMBEDDED_CONSTRAINT => 0,        -- DECIMAL
       USE_MEM_INIT => 1,                   -- DECIMAL
       WAKEUP_TIME => "disable_sleep",      -- String
       WRITE_DATA_WIDTH_A => DATA_WIDTH,    -- DECIMAL
       WRITE_DATA_WIDTH_B => DATA_WIDTH,    -- DECIMAL
       WRITE_MODE_A => "no_change",         -- String
       WRITE_MODE_B => "no_change"          -- String
    )
    port map (
       dbiterra => OPEN,                 -- 1-bit output: Status signal to indicate double bit error occurrence
                                         -- on the data output of port A.
 
       dbiterrb => OPEN,                 -- 1-bit output: Status signal to indicate double bit error occurrence
                                         -- on the data output of port A.
 
       douta => douta,                   -- READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
       doutb => doutb,                   -- READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
       sbiterra => OPEN,                 -- 1-bit output: Status signal to indicate single bit error occurrence
                                         -- on the data output of port A.
 
       sbiterrb => OPEN,                 -- 1-bit output: Status signal to indicate single bit error occurrence
                                         -- on the data output of port B.
 
       addra => addra,                   -- ADDR_WIDTH_A-bit input: Address for port A write and read operations.
       addrb => addrb,                   -- ADDR_WIDTH_B-bit input: Address for port B write and read operations.
       clka => clka,                     -- 1-bit input: Clock signal for port A. Also clocks port B when
                                         -- parameter CLOCKING_MODE is "common_clock".
 
       clkb => clkb,                     -- 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                         -- "independent_clock". Unused when parameter CLOCKING_MODE is
                                         -- "common_clock".
 
       dina => dina,                     -- WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
       dinb => dinb,                     -- WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
       ena => ena,                       -- 1-bit input: Memory enable signal for port A. Must be high on clock
                                         -- cycles when read or write operations are initiated. Pipelined
                                         -- internally.
 
       enb => enb,                       -- 1-bit input: Memory enable signal for port B. Must be high on clock
                                         -- cycles when read or write operations are initiated. Pipelined
                                         -- internally.
 
       injectdbiterra => '0',            -- 1-bit input: Controls double bit error injection on input data when
                                         -- ECC enabled (Error injection capability is not available in
                                         -- "decode_only" mode).
 
       injectdbiterrb => '0',            -- 1-bit input: Controls double bit error injection on input data when
                                         -- ECC enabled (Error injection capability is not available in
                                         -- "decode_only" mode).
 
       injectsbiterra => '0',            -- 1-bit input: Controls single bit error injection on input data when
                                         -- ECC enabled (Error injection capability is not available in
                                         -- "decode_only" mode).
 
       injectsbiterrb => '0',            -- 1-bit input: Controls single bit error injection on input data when
                                         -- ECC enabled (Error injection capability is not available in
                                         -- "decode_only" mode).
 
       regcea => '1',                    -- 1-bit input: Clock Enable for the last register stage on the output
                                         -- data path.
 
       regceb => '1',                    -- 1-bit input: Clock Enable for the last register stage on the output
                                         -- data path.
 
       rsta => rsta,                     -- 1-bit input: Reset signal for the final port A output register
                                         -- stage. Synchronously resets output port douta to the value specified
                                         -- by parameter READ_RESET_VALUE_A.
 
       rstb => rstb,                     -- 1-bit input: Reset signal for the final port B output register
                                         -- stage. Synchronously resets output port doutb to the value specified
                                         -- by parameter READ_RESET_VALUE_B.
 
       sleep => '0',                     -- 1-bit input: sleep signal to enable the dynamic power saving feature.
       wea => wea,                       -- WRITE_DATA_WIDTH_A-bit input: Write enable vector for port A input
                                         -- data port dina. 1 bit wide when word-wide writes are used. In
                                         -- byte-wide write configurations, each bit controls the writing one
                                         -- byte of dina to address addra. For example, to synchronously write
                                         -- only bits [15-8] of dina when WRITE_DATA_WIDTH_A is 32, wea would be
                                         -- 4'b0010.
 
       web => web                        -- WRITE_DATA_WIDTH_B-bit input: Write enable vector for port B input
                                         -- data port dinb. 1 bit wide when word-wide writes are used. In
                                         -- byte-wide write configurations, each bit controls the writing one
                                         -- byte of dinb to address addrb. For example, to synchronously write
                                         -- only bits [15-8] of dinb when WRITE_DATA_WIDTH_B is 32, web would be
                                         -- 4'b0010.
 
    );
 -- End of xpm_memory_tdpram_inst instantiation
                  
end rtl;