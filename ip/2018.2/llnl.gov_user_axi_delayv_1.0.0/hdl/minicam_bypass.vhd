--**********************************************************************************************************
-- Lawrence Livermore National Labs
-- 20200409 CM Initial creation 
-- minicam_bypass.vhd:  This module bypasses the CAM function.
--**********************************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library axi_delay_lib;
use axi_delay_lib.all;

entity minicam_bypass is
generic (
    CAM_WIDTH           : integer := 16; -- maximum width of axi_id input. Requirement: CAMWIDTH <= NUM_MINI_BUFS
    CTR_PTR_WIDTH       : integer := 5;  -- width of counter/pointer, which is the index to the Packet Buffer (start of mini-buffer)
    NUM_EVENTS_PER_MBUF : integer := 8;  -- maximum number of events each minibuffer can hold
    NUM_MINI_BUFS       : integer := 32  -- number of minibufs; each must be sized to hold the largest packet size supported
);
port (
    clk_i               : in  std_logic;
    rst_i               : in  std_logic;

    -- CAM I/O
    data_valid_i        : in  std_logic;
    data_i              : in  std_logic_vector(CAM_WIDTH-1 downto 0);

    tlast_i             : in  std_logic;                                 -- from the AXI downstream device, indicates that packet is completely stored in Mini buffer
    ctr_ptr_o           : out std_logic_vector(CTR_PTR_WIDTH-1 downto 0);-- counter/pointer to Packet Buffer
    ctr_ptr_wr_o        : out std_logic;
    minicam_full_o      : out std_logic; -- there are no inactive and valid locations in minicam
    available_ctrptr_o  : out std_logic; -- there is at least one inactive and valid location in the minicam
    minicam_err_o       : out std_logic; -- (asserted if a packet arrives) AND (it doesn't hit) AND (there are no empty locations in the minicam)

    minibuf_fe_o        : out std_logic;
    minibuf_wr_i        : in  std_logic;
    minibuf_wdata_i     : in  std_logic_vector(CTR_PTR_WIDTH-1 downto 0)
);
end minicam_bypass;

architecture minicam_bypass of minicam_bypass is

--******************************************************************************
-- Constants
--******************************************************************************
constant C_LSB_WIDTH :  integer := 2;

--******************************************************************************
--Signal Definitions
--******************************************************************************
signal ctr_ptr_lsb       : std_logic_vector(C_LSB_WIDTH-1 downto 0);
signal ctr_ptr_msb       : std_logic_vector((CTR_PTR_WIDTH - 1 - C_LSB_WIDTH) downto 0);
signal ctr_ptr           : std_logic_vector((CTR_PTR_WIDTH-1) downto 0);
signal ctr_ptr_wr        : std_logic;

signal minibuf_af        : std_logic;
signal minibuf_ae        : std_logic;
signal minibuf_fe        : std_logic;
signal minibuf_valid     : std_logic;
signal minibuf_rdata     : std_logic_vector(CTR_PTR_WIDTH-1 downto 0);
signal minibuf_rd        : std_logic;

--******************************************************************************
-- Connectivity and Logic
--******************************************************************************

begin

ctr_ptr_proc: process(clk_i) begin
    if rising_edge(clk_i) then
        if (rst_i = '1') then
            ctr_ptr_msb <= (others => '0');
            ctr_ptr_lsb <= (others => '0');
            ctr_ptr     <= (others => '0');
        else
            -- when data_valid_i and tlast_i and ctr_ptr = "last minibuf", then reset ctr_ptr to "0"
            -- when data_valid_i and tlast_i, increment to next mini buffer
            -- when data_valid_i and !tlast_i, increment by '1'
            
            if (data_valid_i = '1' and tlast_i = '1') then
--                if ((ctr_ptr_msb & "00") = std_logic_vector(to_unsigned(NUM_MINI_BUFS-1, ctr_ptr'length))) then
--                    ctr_ptr_msb <= (others => '0');
--                else
--                    ctr_ptr_msb <= ctr_ptr_msb + '1';
--                end if;
                ctr_ptr_msb <= minibuf_rdata(CTR_PTR_WIDTH-1 downto 2);
                
                ctr_ptr_lsb <= (others => '0');

            elsif (data_valid_i = '1') then
                ctr_ptr_lsb <= ctr_ptr_lsb + '1';
            end if;
            
            ctr_ptr <= ctr_ptr_msb & ctr_ptr_lsb;
            
            if (data_valid_i = '1') then
                ctr_ptr_wr <= '1';
            else
                ctr_ptr_wr <= '0';
            end if;
        end if;
    end if;
end process;

minibuf_rd <= data_valid_i and tlast_i;

minibuf_mgmt_inst : entity axi_delay_lib.minibuf_mgmt
    generic map (
        CAM_DEPTH           => 0,                   -- No CAM
        CTR_PTR_WIDTH       => CTR_PTR_WIDTH,       -- width of counter/pointer, which is the index to the Packet Buffer (start of mini-buffer)
        NUM_EVENTS_PER_MBUF => NUM_EVENTS_PER_MBUF, -- maximum number of events each minibuffer can hold
        NUM_MINI_BUFS       => NUM_MINI_BUFS        -- number of minibufs; each must be sized to hold the largest packet size supported
    )
    port map (
        clk_i               => clk_i,
        rst_i               => rst_i,
        minibuf_wdata_i     => minibuf_wdata_i,
        minibuf_af_o        => minibuf_af,
        minibuf_wr_i        => minibuf_wr_i,
        minibuf_rdata_o     => minibuf_rdata,
        minibuf_fe_o        => minibuf_fe,
        minibuf_ae_o        => minibuf_ae,
        minibuf_valid_o     => OPEN,
        minibuf_rd_i        => minibuf_rd,
        minibuf_rdy_o       => OPEN
    );

----------------------------------------------------------------------------------------------
-- Output assignments
----------------------------------------------------------------------------------------------
available_ctrptr_o <= not minibuf_ae; --'1'; -- there is always a counter/pointer avialble
minicam_full_o     <= '0'; -- never full for this bypass module
minicam_err_o      <= '0'; -- no minicam, no errors
minibuf_fe_o       <= minibuf_fe;     --'0'; -- never empty for this bypass module

ctr_ptr_o          <= ctr_ptr;
ctr_ptr_wr_o       <= ctr_ptr_wr;

----------------------------------------------------------------------------------------------
end minicam_bypass;
