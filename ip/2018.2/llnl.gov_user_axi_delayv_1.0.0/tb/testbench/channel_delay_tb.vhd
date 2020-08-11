--**********************************************************************************************************
-- Lawrence Livermore National Labs
-- 202001124 CM Initial creation 
-- channel_delay_tb.vhd
--**********************************************************************************************************


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;


-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

library axi_delay_lib;
use axi_delay_lib.all;
use axi_delay_lib.axi_delay_pkg.all;

entity channel_delay_tb is
    generic (
        SIMULATION           : std_logic := '1';
        CHANNEL_TYPE         : string := "R" ; -- valid values are:  AW, W, B, AR, R
        PRIORITY_QUEUE_WIDTH : integer := 32;
        DELAY_WIDTH          : integer := 24;

        -- AXI-Full Bus Interface
        C_AXI_ID_WIDTH       : integer := 16;
        C_AXI_ADDR_WIDTH     : integer := 40;
        C_AXI_DATA_WIDTH     : integer := 128;
     
        GDT_FILENAME         : string := "../../../../data_in/bram_del_table.mem";
        GDT_ADDR_BITS        : integer := 10;
        GDT_DATA_BITS        : integer := 24;

        BYPASS_MINICAM       : integer := 1;
        CAM_DEPTH            : integer := 8;  -- depth of cam (i.e. number of entries), must be modulo 2.
        CAM_WIDTH            : integer := 16; -- maximum width of axi_id input. Requirement: CAMWIDTH <= NUM_MINI_BUFS
        NUM_EVENTS_PER_MBUF  : integer := 8;  -- maximum number of events each minibuffer can hold
        NUM_MINI_BUFS        : integer := 64  -- number of minibufs; each must be sized to hold the largest packet size supported
    );    
    Port ( 
        dummy_o : out std_logic
    );
end channel_delay_tb;

architecture channel_delay_tb of channel_delay_tb is

--******************************************************************************
-- Constants
--******************************************************************************
-- Note: Copied from channel_delay.vhd
-- Note: assuming maximum width defined by C_AXI_ID_WIDTH = 16 and C_AXI_DATA_WIDTH = 128 (C_AXI_DATA_WIDTH/8 = 16) and misc (32) = 192
constant AXI_INFO_WIDTH    : integer := C_AXI_ID_WIDTH + C_AXI_DATA_WIDTH + C_AXI_ADDR_WIDTH + C_AXI_DATA_WIDTH/8 + 
                                    8 + 3 + 2 + 2 + 4 + 3 + 4 + 4 + 1 + 1 + 2;
constant AXI_INFO_DEPTH    : integer := 64;

--******************************************************************************
--Signal Definitions
--******************************************************************************

-------------------------
-- Slave AXI Interface --
-------------------------
signal sys_clk         : std_logic := '0';
signal sys_rst         : std_logic := '1';
signal sys_rst_n       : std_logic := '0';
signal transmission_en : std_logic := '0';
signal counter         : std_logic_vector(DELAY_WIDTH-1 downto 0);

signal s_axi_lite_aclk    : std_logic := '0';
signal s_axi_lite_aresetn : std_logic := '0';

signal s_axi_id      : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
signal s_axi_addr    : std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0) := (others => '0'); 
signal s_axi_data    : std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0) := (others => '0'); 
signal s_axi_strb    : std_logic_vector((C_AXI_DATA_WIDTH/8)-1 downto 0) := (others => '1');
signal s_axi_len     : std_logic_vector(7 downto 0) := (others => '0');
signal s_axi_size    : std_logic_vector(2 downto 0) := "110";
signal s_axi_burst   : std_logic_vector(1 downto 0) := "01";
signal s_axi_lock    : std_logic_vector(1 downto 0) := (others => '0');
signal s_axi_cache   : std_logic_vector(3 downto 0) := (others => '0');
signal s_axi_prot    : std_logic_vector(2 downto 0) := (others => '0'); 
signal s_axi_qos     : std_logic_vector(3 downto 0) := (others => '0'); 
signal s_axi_region  : std_logic_vector(3 downto 0) := (others => '0');
signal s_axi_valid   : std_logic;
signal s_axi_ready   : std_logic;
 
signal s_axi_last    : std_logic;
signal s_axi_resp    : std_logic_vector(1 downto 0); 

-------------------------
-- Master AXI Interface --
-------------------------
signal m_axi_aclk    : std_logic;
signal m_axi_aresetn : std_logic;
 
signal m_axi_id      : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
signal m_axi_addr    : std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0) := (others => '0'); 
signal m_axi_data    : std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0) := (others => '0'); 
signal m_axi_strb    : std_logic_vector((C_AXI_DATA_WIDTH/8)-1 downto 0) := (others => '1'); 
signal m_axi_len     : std_logic_vector(7 downto 0) := (others => '0'); 
signal m_axi_size    : std_logic_vector(2 downto 0) := "110";
signal m_axi_burst   : std_logic_vector(1 downto 0) := "01";
signal m_axi_lock    : std_logic_vector(1 downto 0) := (others => '0');
signal m_axi_cache   : std_logic_vector(3 downto 0) := (others => '0');
signal m_axi_prot    : std_logic_vector(2 downto 0) := (others => '0');
signal m_axi_qos     : std_logic_vector(3 downto 0) := (others => '0');
signal m_axi_region  : std_logic_vector(3 downto 0) := (others => '0');
signal m_axi_valid   : std_logic;
signal m_axi_ready   : std_logic;
 
signal m_axi_last    : std_logic;
signal m_axi_resp    : std_logic_vector(1 downto 0);
 
signal aw_id         : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0); -- only for "AW" instance - open for others
signal w_last_i      : std_logic;                                   -- only for "AW" instance, '0' for others
signal w_last_o      : std_logic;                                   -- only for "W" instance - open for others
signal w_id          : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0); -- only for "W" instance - tie to zeroes for others

--******************************************************************************
--Component Definitions
--******************************************************************************

--******************************************************************************
-- Connectivity and Logic
--******************************************************************************

begin

sys_clk         <= not sys_clk after 10 ns;
sys_rst         <= '0' after 1 us;  
sys_rst_n       <= not sys_rst;
transmission_en <= '1' after  2 us;  

s_axi_lite_aclk    <= not s_axi_lite_aclk after 10 ns;
s_axi_lite_aresetn <= '1' after 1 us;  

s_counter: process(sys_clk)
begin
    if (rising_edge(sys_clk)) then
        if (sys_rst_n = '0') then
            counter <= (others => '0');
        else
            counter <= std_logic_vector(unsigned(counter) + 1);
        end if;
    end if;
end process;


---------------------------------------
-- AXI source (master)
---------------------------------------
axi_master_int : entity axi_delay_lib.axi_master
    generic map (
        C_AXI_ID_WIDTH    => C_AXI_ID_WIDTH, 
        C_AXI_ADDR_WIDTH  => C_AXI_ADDR_WIDTH,
        C_AXI_DATA_WIDTH  => C_AXI_DATA_WIDTH,
        CHANNEL_TYPE      => CHANNEL_TYPE
)
    port map (
        m_axi_aclk_i      => sys_clk,
        m_axi_aresetn_i   => sys_rst_n,
        
        -- Slave AXI Interface --
        m_axi_id_o        => s_axi_id,
        m_axi_addr_o      => s_axi_addr,
        m_axi_data_o      => s_axi_data,  
        m_axi_strb_o      => s_axi_strb,  
        m_axi_len_o       => s_axi_len,   
        m_axi_size_o      => s_axi_size,  
        m_axi_burst_o     => s_axi_burst, 
        m_axi_lock_o      => s_axi_lock,  
        m_axi_cache_o     => s_axi_cache, 
        m_axi_prot_o      => s_axi_prot,  
        m_axi_qos_o       => s_axi_qos,   
        m_axi_region_o    => s_axi_region,
        m_axi_valid_o     => s_axi_valid, 
        m_axi_ready_i     => s_axi_ready, 
	    	       	       	    
        m_axi_last_o      => s_axi_last,  
        m_axi_resp_o      => s_axi_resp,
        
        transmission_en_i => transmission_en
);

---------------------------------------
-- channel delay
---------------------------------------

channel_delay_inst : entity axi_delay_lib.chan_delay_variable
   generic map (
    SIMULATION           => SIMULATION,
    CHANNEL_TYPE         => CHANNEL_TYPE,
    PRIORITY_QUEUE_WIDTH => PRIORITY_QUEUE_WIDTH,
    DELAY_WIDTH          => DELAY_WIDTH,
    C_COUNTER_WIDTH      => DELAY_WIDTH,

    C_AXI_ID_WIDTH      => C_AXI_ID_WIDTH,
    C_AXI_ADDR_WIDTH    => C_AXI_ADDR_WIDTH,
    C_AXI_DATA_WIDTH    => C_AXI_DATA_WIDTH,

    AXI_INFO_WIDTH       => AXI_INFO_WIDTH,
    AXI_INFO_DEPTH       => AXI_INFO_DEPTH,

    GDT_FILENAME        => GDT_FILENAME,
    GDT_ADDR_BITS       => GDT_ADDR_BITS,
    GDT_DATA_BITS       => GDT_DATA_BITS,

    BYPASS_MINICAM      => BYPASS_MINICAM,
    CAM_DEPTH           => CAM_DEPTH,
    CAM_WIDTH           => CAM_WIDTH,
    NUM_EVENTS_PER_MBUF => NUM_EVENTS_PER_MBUF,
    NUM_MINI_BUFS       => NUM_MINI_BUFS
)
    port map (
        --------------------------------------------
        ----- AXI Slave Interface ---
        --------------------------------------------
        s_axi_aclk    => sys_clk,
        s_axi_aresetn => sys_rst_n,
        counter       => counter,
        
        -- Slave AXI Interface --
        s_axi_id      => s_axi_id,    
        s_axi_addr    => s_axi_addr,
        s_axi_data    => s_axi_data,  
        s_axi_strb    => s_axi_strb,  
        s_axi_len     => s_axi_len,   
        s_axi_size    => s_axi_size,  
        s_axi_burst   => s_axi_burst, 
        s_axi_lock    => s_axi_lock,  
        s_axi_cache   => s_axi_cache, 
        s_axi_prot    => s_axi_prot,  
        s_axi_qos     => s_axi_qos,   
        s_axi_region  => s_axi_region,
        s_axi_valid   => s_axi_valid, 
        s_axi_ready   => s_axi_ready, 
	    	       	     	    
        s_axi_last    => s_axi_last,  
        s_axi_resp    => s_axi_resp,  
        
        --------------------------------------------
        ----- AXI Master Interface ---
        --------------------------------------------
        m_axi_aclk    => sys_clk,
        m_axi_aresetn => sys_rst_n,
	    	     
        m_axi_id      => m_axi_id,   
        m_axi_addr    => m_axi_addr,
        m_axi_data    => m_axi_data,  
        m_axi_strb    => m_axi_strb,  
        m_axi_len     => m_axi_len,   
        m_axi_size    => m_axi_size,  
        m_axi_burst   => m_axi_burst, 
        m_axi_lock    => m_axi_lock,  
        m_axi_cache   => m_axi_cache, 
        m_axi_prot    => m_axi_prot,  
        m_axi_qos     => m_axi_qos,   
        m_axi_region  => m_axi_region,
        m_axi_valid   => m_axi_valid, 
        m_axi_ready   => m_axi_ready, 
     
        m_axi_last    => m_axi_last,  
        m_axi_resp    => m_axi_resp,  

        dclk_i        => s_axi_lite_aclk,
        dresetn_i     => s_axi_lite_aresetn,
        gdt_wren_i    => (others => '0'), --gdt_wren, 
        gdt_addr_i    => (others => '0'), --gdt_addr, 
        gdt_wdata_i   => (others => '0'), --gdt_wdata, 
        gdt_rdata_o   => OPEN             --gdt_rdata,  
);    

---------------------------------------
-- AXI sink (slave)
---------------------------------------
axi_slave_inst : entity axi_delay_lib.axi_slave
    generic map (
        C_AXI_ID_WIDTH    => C_AXI_ID_WIDTH,
        C_AXI_ADDR_WIDTH  => C_AXI_ADDR_WIDTH,
        C_AXI_DATA_WIDTH  => C_AXI_DATA_WIDTH,
        CHANNEL_TYPE      => CHANNEL_TYPE
)
    port map  (
        s_axi_aclk_i    => sys_clk,
        s_axi_aresetn_i => sys_rst_n,
        
        -- Slave AXI Interface --
        s_axi_id_i      => m_axi_id,   
        s_axi_addr_i    => m_axi_addr, 
        s_axi_data_i    => m_axi_data,  
        s_axi_strb_i    => m_axi_strb,  
        s_axi_len_i     => m_axi_len,   
        s_axi_size_i    => m_axi_size,  
        s_axi_burst_i   => m_axi_burst, 
        s_axi_lock_i    => m_axi_lock,  
        s_axi_cache_i   => m_axi_cache, 
        s_axi_prot_i    => m_axi_prot,  
        s_axi_qos_i     => m_axi_qos,   
        s_axi_region_i  => m_axi_region,
        s_axi_valid_i   => m_axi_valid, 
        s_axi_ready_o   => m_axi_ready, 
	    	       	    	    
        s_axi_last_i    => m_axi_last,  
        s_axi_resp_i    => m_axi_resp
);

---------------------------------------
-- Data Sampler
---------------------------------------
data_sampler_inst : entity axi_delay_lib.data_sampler
    port map (
        SIM_clk           => SIM_clk,          
        SIM_nreset        => SIM_nreset,       
        SIM_random_dly    => SIM_random_dly,   
        SIM_random_dly_en => SIM_random_dly_en,
        SIM_lfsr_out      => SIM_lfsr_out,
        SIM_addrb         => SIM_addrb
   );

--******************************************************************************
dummy_o <= '0';
--******************************************************************************

end architecture channel_delay_tb;
