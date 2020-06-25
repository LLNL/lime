library ieee;
use ieee.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.ext;

use IEEE.std_logic_textio.all;
use std.textio.all;

library axi_delay_lib;
use axi_delay_lib.axi_delay_pkg.all;

entity data_sampler is
    port (
        signal SIM_clk           : in  std_logic;
        signal SIM_nreset        : in  std_logic;
        signal SIM_random_dly    : in  std_logic_vector(23 downto 0);
        signal SIM_random_dly_en : in  std_logic;
        signal SIM_lfsr_out      : in  std_logic_vector(9 downto 0);
        signal SIM_addrb         : in  std_logic_vector(9 downto 0)
   );
end entity data_sampler;

architecture data_sampler of data_sampler is

file gdt_outfile : TEXT open write_mode is "../../../../data_out/gdtout.txt";

--------------------------------------------------------------------------------
-- Component Declarations (needed for verilog modules, which are not entities)
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------
signal lfsr_q  : std_logic_vector(9 downto 0); -- aligns lfsr with SIM_random_dly, for the out file
signal addrb_q : std_logic_vector(9 downto 0);  -- aligns addrb with SIM_random_dly, for the out file


--------------------------------------------------------------------------------
-- Signal Definitions
--------------------------------------------------------------------------------

--random_dly_int <= to_integer(unsigned(SIM_random_dly)));

--------------------------------------------------------------------------------
begin

grab_gdt_proc : process(SIM_clk)

VARIABLE line_out   : LINE;

begin
   if (SIM_nreset = '1') then 
         
      if rising_edge(SIM_clk) then
      
         lfsr_q  <= SIM_lfsr_out; 
         addrb_q <= SIM_addrb;
      
         if (SIM_random_dly_en = '1' ) then
            write     (line_out, to_integer(unsigned(SIM_random_dly)));
            write     (line_out, string'(","));
            write     (line_out, to_integer(unsigned(lfsr_q)));
            write     (line_out, string'(","));
            write     (line_out, to_integer(unsigned(addrb_q)));
            writeline (gdt_outfile, line_out);
                        
         end if;

      end if;
      
   end if;
   
end process;   

-------------------------------------------------------------------------------

end architecture data_sampler;

