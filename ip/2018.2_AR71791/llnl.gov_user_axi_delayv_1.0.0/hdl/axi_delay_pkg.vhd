----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 1/10/2015 08:42:30 PM
-- Design Name:
-- Module Name: axi_delay_pkg - behavioral
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
--use ieee.std_logic_arith.all;
use ieee.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;

package axi_delay_pkg is

	constant P_AXI4 : integer := 0;
	constant P_AXI3 : integer := 1;
	constant P_AXILITE : integer := 2;

	-- protocol = 0:AXI4 1:AXI3 2:AXILITE
	function axi_len_width  (constant p : in integer) return integer;
	function axi_lock_width (constant p : in integer) return integer;

	function ite(constant i : boolean; t, e : integer) return integer;

	-- return the log base 2 of the argument x rounded to plus infinity
	function log2rp (x : integer) return integer;
	function log2rp_long (x : std_logic_vector) return integer;

end axi_delay_pkg;

package body axi_delay_pkg is

	function axi_len_width (constant p : in integer) return integer is
	begin
		if (p = P_AXI3) then return 4; else return 8; end if;
	end axi_len_width;

	function axi_lock_width (constant p : in integer) return integer is
	begin
		if (p = P_AXI3) then return 2; else return 1; end if;
	end axi_lock_width;

	function ite(constant i : boolean; t, e : integer) return integer is
	begin
		if (i) then return t; else return e; end if;
	end ite;

	function log2rp (x : integer) return integer is
		variable i : integer;
	begin
		i := 0;
		while (x > 2**i) loop
			i := i + 1;
		end loop;
		return i;
	end log2rp;

	-- This was added as a modification to log2rp to handle overflow conditions
	function log2rp_long (x : std_logic_vector) return integer is
		variable i : integer;
		variable s : unsigned(63 downto 0) := x"0000000000000001";
	begin
		i := 0;
		while (x > std_logic_vector(shift_left(s,i))) loop
			i := i + 1;
		end loop;
		return i;
	end log2rp_long;

end axi_delay_pkg;
