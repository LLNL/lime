--**********************************************************************************************************
-- Lawrence Livermore National Labs
-- 20191119 CM Initial creation 
-- random_dly.vhd: This module uses a 16-bit lfsr (from http://emmanuel.pouly.free.fr/fibo.html) to create a 
--                 random delay funtion.  The number of output bits is determined by the 
--**********************************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;

library axi_delay_lib;
use axi_delay_lib.all;

entity random_dly is

generic(
    LFSR_BITS        : integer := 16
);
port (
    clk_i            : in  std_logic;
    rst_i            : in  std_logic;

	dclk_i           : in  std_logic;
	dresetn_i        : in  std_logic;
    gdt_wren_i       : in  std_logic_vector(0 downto 0);
    gdt_addr_i       : in  std_logic_vector(15 downto 0); 
    gdt_wdata_i      : in  std_logic_vector(23 downto 0);
    gdt_rdata_o      : out std_logic_vector(23 downto 0);

    random_dly_req_i : in  std_logic;
    random_dly_o     : out std_logic_vector(23 downto 0)
);
end random_dly;

architecture behavioral of random_dly is

--******************************************************************************
-- Constants
--******************************************************************************
constant polynome		:std_logic_vector (LFSR_BITS-1 downto 0):= "1011010000000000";

--******************************************************************************
--Signal Definitions
--******************************************************************************
signal dreset       : std_logic;
signal lfsr_tmp     :std_logic_vector (LFSR_BITS-1 downto 0):= (0=>'1',others=>'0');
signal rst_1q       : std_logic;
signal rst_2q       : std_logic;
signal rst_3q       : std_logic;

signal gdt_wren     : std_logic_vector(0 downto 0);
--******************************************************************************
--Component Definitions
--******************************************************************************

--******************************************************************************
-- Connectivity and Logic
--******************************************************************************

begin

dreset <= not dresetn_i;
    
    gauss_delay_table : entity dpram_true
GENERIC MAP (
    ADDR_WIDTH       => 16,
    DATA_WIDTH       => 24,
    CLOCKING_MODE    => "independent_clock",
    MEMORY_INIT_FILE => "bram_del_table.mem"
)
PORT MAP (
    clka  => dclk_i,
    rsta  => rst_i,
    ena   => '1',
    wea   => gdt_wren_i,
    addra => gdt_addr_i,
    dina  => gdt_wdata_i, 
    douta => gdt_rdata_o,
    
    clkb  => clk_i,
    rstb  => dreset,
    enb   => '1',
    web   => (others => '0'),
    addrb => lfsr_tmp,
    dinb  => (others => '0'),
    doutb => random_dly_o
);

-- gauss_delay_table : entity dpram_64Kx24
--     PORT MAP (
--         clka  => dclk_i,
--         wea   => gdt_wren_i,
--         addra => gdt_addr_i,
--         dina  => gdt_wdata_i,
--         douta => gdt_rdata_o,
        
--         clkb  => clk_i,
--         web   => (others => '0'),
--         addrb => lfsr_tmp,
--         dinb  => (others => '0'),
--         doutb => random_dly_o
--     );    

process (clk_i, rst_i) 
    variable lsb       :std_logic;	 
    variable ext_inbit :std_logic_vector (LFSR_BITS-1 downto 0) ;

begin 
    lsb := lfsr_tmp(0);

    for i in 0 to LFSR_BITS-1 loop	 
        ext_inbit(i):= lsb;	 
    end loop;

    if (rst_i = '1') then
        rst_1q   <= '1';
        rst_2q   <= '1';
        rst_3q   <= '1';
        lfsr_tmp <= (0=>'1', others=>'0');
    elsif (rising_edge(clk_i)) then
        rst_1q   <= rst_i;
        rst_2q   <= rst_1q;
        rst_3q   <= rst_2q;
        if (random_dly_req_i = '1' or (rst_2q = '0' and rst_3q = '1')) then
            lfsr_tmp <= ( '0' & lfsr_tmp(LFSR_BITS-1 downto 1) ) xor ( ext_inbit and polynome );
        end if;
    end if;

end process;

----------------------------------------------------------------------------------------------
-- Output assignments
----------------------------------------------------------------------------------------------
--random_dly_o <= lfsr_tmp & lfsr_tmp(11 downto 4);

----------------------------------------------------------------------------------------------
end behavioral;
