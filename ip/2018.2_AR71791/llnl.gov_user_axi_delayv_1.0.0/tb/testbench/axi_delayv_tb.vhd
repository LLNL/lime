----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/05/2020 02:08:50 PM
-- Design Name: 
-- Module Name: axi_delayv_tb - Behavioral
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


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.ext;

library xpm;
use xpm.vcomponents.all;

library axi_delay_lib;
use axi_delay_lib.axi_delay_pkg.all;

entity axi_delayv_tb is
    generic (
	C_FAMILY              : string := "rtl";
	C_AXI_PROTOCOL        : integer := P_AXI4;
	C_MEM_ADDR_WIDTH      : integer := 30;
	C_COUNTER_WIDTH       : integer := 20;
	C_FIFO_DEPTH_AW       : integer := 0;
	C_FIFO_DEPTH_W        : integer := 0;
	C_FIFO_DEPTH_B        : integer := 0;
	C_FIFO_DEPTH_AR       : integer := 0;
	C_FIFO_DEPTH_R        : integer := 0;

	-- AXI-Lite Bus Interface
	C_AXI_LITE_ADDR_WIDTH : integer := 18;
	C_AXI_LITE_DATA_WIDTH : integer := 32;

	-- AXI-Full Bus Interface
	C_AXI_ID_WIDTH        : integer := 16;
	C_AXI_ADDR_WIDTH      : integer := 40;
	C_AXI_DATA_WIDTH      : integer := 128;

        -- chan_delay_variable generics
        PRIORITY_QUEUE_WIDTH  : integer := 16;
        DELAY_WIDTH           : integer := 24;
        BYPASS_MINICAM        : integer := 1;
        CAM_DEPTH             : integer := 8;  -- depth of cam (i.e. number of entries), must be modulo 2.
        NUM_MINI_BUFS         : integer := 64; -- number of minibufs; each must be sized to hold the largest packet size supported    

        -- Test Paramters
        C_AXI_LITE_START_ADDR : std_logic_vector(31 downto 0) := x"00020000";
        C_AXI_LITE_BURST_LEN  : integer := 1;
        C_AXI_LITE_NUM_BURST  : integer := 10;
        
        C_AXI_START_ADDR      : std_logic_vector(39 downto 0) := x"0000001000";
        C_AXI_BURST_LEN       : integer := 1;  -- No. of Transfers
        C_AXI_NUM_BURST       : integer := 40 -- Total transfers = C_NUM_BURST*BURST_LENGTH
    );   
    Port (
        clk_i : in std_logic
    );
end axi_delayv_tb;

architecture Behavioral of axi_delayv_tb is


COMPONENT axi_bram_8Kx128
  PORT (
    s_axi_aclk : IN STD_LOGIC;
    s_axi_aresetn : IN STD_LOGIC;
    s_axi_awid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    s_axi_awaddr : IN STD_LOGIC_VECTOR(16 DOWNTO 0);
    s_axi_awlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    s_axi_awsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    s_axi_awburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_awlock : IN STD_LOGIC;
    s_axi_awcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    s_axi_awprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    s_axi_awvalid : IN STD_LOGIC;
    s_axi_awready : OUT STD_LOGIC;
    s_axi_wdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    s_axi_wstrb : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    s_axi_wlast : IN STD_LOGIC;
    s_axi_wvalid : IN STD_LOGIC;
    s_axi_wready : OUT STD_LOGIC;
    s_axi_bid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    s_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_bvalid : OUT STD_LOGIC;
    s_axi_bready : IN STD_LOGIC;
    s_axi_arid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    s_axi_araddr : IN STD_LOGIC_VECTOR(16 DOWNTO 0);
    s_axi_arlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    s_axi_arsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    s_axi_arburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_arlock : IN STD_LOGIC;
    s_axi_arcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    s_axi_arprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    s_axi_arvalid : IN STD_LOGIC;
    s_axi_arready : OUT STD_LOGIC;
    s_axi_rid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    s_axi_rdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
    s_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_rlast : OUT STD_LOGIC;
    s_axi_rvalid : OUT STD_LOGIC;
    s_axi_rready : IN STD_LOGIC
  );
END COMPONENT;

--******************************************************************************
--Signal Definitions
--******************************************************************************
-- AXI-Lite Slave Bus Interface S_AXI_LITE
signal s_axi_lite_aclk    : std_logic := '0';
signal s_axi_lite_aresetn : std_logic := '0';

signal s_axi_lite_awaddr  : std_logic_vector(31 downto 0) := (others => '0');
signal s_axi_lite_awprot  : std_logic_vector(2 downto 0) := (others => '0');
signal s_axi_lite_awvalid : std_logic;
signal s_axi_lite_awready : std_logic;

signal s_axi_lite_wdata   : std_logic_vector(C_AXI_LITE_DATA_WIDTH-1 downto 0) := (others => '0');
signal s_axi_lite_wstrb   : std_logic_vector((C_AXI_LITE_DATA_WIDTH/8)-1 downto 0) := (others => '1');
signal s_axi_lite_wvalid  : std_logic;
signal s_axi_lite_wready  : std_logic;

signal s_axi_lite_bresp   : std_logic_vector(1 downto 0);
signal s_axi_lite_bvalid  : std_logic;
signal s_axi_lite_bready  : std_logic;

signal s_axi_lite_araddr  : std_logic_vector(31 downto 0) := (others => '0');
signal s_axi_lite_arprot  : std_logic_vector(2 downto 0) := (others => '0');
signal s_axi_lite_arvalid : std_logic;
signal s_axi_lite_arready : std_logic;

signal s_axi_lite_rdata   : std_logic_vector(C_AXI_LITE_DATA_WIDTH-1 downto 0);
signal s_axi_lite_rresp   : std_logic_vector(1 downto 0);
signal s_axi_lite_rvalid  : std_logic;
signal s_axi_lite_rready  : std_logic;

----- AXI-Full Slave Bus Interface S_AXI -----
signal s_axi_aclk     : std_logic := '0';
signal s_axi_aresetn  : std_logic := '0';

----- Slave Port: Write Address -----
signal s_axi_awid     : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
signal s_axi_awaddr   : std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0) := (others => '0'); -- AXILITE
signal s_axi_awlen    : std_logic_vector(AXI_LEN_WIDTH(C_AXI_PROTOCOL)-1 downto 0) := (others => '0'); -- AXI3 (3 downto 0), AXI4 (7 downto 0)
signal s_axi_awsize   : std_logic_vector(2 downto 0) := std_logic_vector(to_unsigned(log2rp(C_AXI_DATA_WIDTH/8),3));
signal s_axi_awburst  : std_logic_vector(1 downto 0) := (0 => '1', others => '0');
signal s_axi_awlock   : std_logic_vector(AXI_LOCK_WIDTH(C_AXI_PROTOCOL)-1 downto 0) := (others => '0'); -- AXI3 (1 downto 0), AXI4 (0 downto 0)
signal s_axi_awcache  : std_logic_vector(3 downto 0) := (others => '0');
signal s_axi_awprot   : std_logic_vector(2 downto 0) := (others => '0'); -- AXILITE
signal s_axi_awqos    : std_logic_vector(3 downto 0) := (others => '0'); -- AXI4
signal s_axi_awregion : std_logic_vector(3 downto 0) := (others => '0'); -- AXI4
signal s_axi_awvalid  : std_logic;
signal s_axi_awready  : std_logic;

----- Slave Port:  Data -----
signal s_axi_wid      : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0) := (others => '0'); -- AXI3
signal s_axi_wdata    : std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0) := (others => '0'); -- AXILITE
signal s_axi_wstrb    : std_logic_vector((C_AXI_DATA_WIDTH/8)-1 downto 0) := (others => '1'); -- AXILITE
signal s_axi_wlast    : std_logic := '1';
signal s_axi_wvalid   : std_logic;
signal s_axi_wready   : std_logic;

----- Slave Port: Write Response -----
signal s_axi_bid      : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);
signal s_axi_bresp    : std_logic_vector(1 downto 0); -- AXILITE
signal s_axi_bvalid   : std_logic;
signal s_axi_bready   : std_logic;

----- Slave Port: Read Adress -----
signal s_axi_arid     : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
signal s_axi_araddr   : std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0) := (others => '0'); -- AXILITE
signal s_axi_arlen    : std_logic_vector(AXI_LEN_WIDTH(C_AXI_PROTOCOL)-1 downto 0) := (others => '0'); -- AXI3 (3 downto 0), AXI4 (7 downto 0)
signal s_axi_arsize   : std_logic_vector(2 downto 0) := std_logic_vector(to_unsigned(log2rp(C_AXI_DATA_WIDTH/8),3));
signal s_axi_arburst  : std_logic_vector(1 downto 0) := (0 => '1', others => '0');
signal s_axi_arlock   : std_logic_vector(AXI_LOCK_WIDTH(C_AXI_PROTOCOL)-1 downto 0) := (others => '0'); -- AXI3 (1 downto 0), AXI4 (0 downto 0)
signal s_axi_arcache  : std_logic_vector(3 downto 0) := (others => '0');
signal s_axi_arprot   : std_logic_vector(2 downto 0) := (others => '0'); -- AXILITE
signal s_axi_arqos    : std_logic_vector(3 downto 0) := (others => '0'); -- AXI4
signal s_axi_arregion : std_logic_vector(3 downto 0) := (others => '0'); -- AXI4
signal s_axi_arvalid  : std_logic;
signal s_axi_arready  : std_logic;

----- Slave Port:  Data -----
signal s_axi_rid      : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);
signal s_axi_rdata    : std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0); -- AXILITE
signal s_axi_rresp    : std_logic_vector(1 downto 0); -- AXILITE
signal s_axi_rlast    : std_logic;
signal s_axi_rvalid   : std_logic;
signal s_axi_rready   : std_logic;

----- AXI-Full Master Bus Interface M_AXI -----
signal m_axi_aclk     : std_logic := '0';
signal m_axi_aresetn  : std_logic := '0';

----- Master Port: Write Adress -----
signal m_axi_awid     : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);
signal m_axi_awaddr   : std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0); -- AXILITE
signal m_axi_awlen    : std_logic_vector(AXI_LEN_WIDTH(C_AXI_PROTOCOL)-1 downto 0); -- AXI3 (3 downto 0), AXI4 (7 downto 0)
signal m_axi_awsize   : std_logic_vector(2 downto 0);
signal m_axi_awburst  : std_logic_vector(1 downto 0);
signal m_axi_awlock   : std_logic_vector(AXI_LOCK_WIDTH(C_AXI_PROTOCOL)-1 downto 0); -- AXI3 (1 downto 0), AXI4 (0 downto 0)
signal m_axi_awcache  : std_logic_vector(3 downto 0);
signal m_axi_awprot   : std_logic_vector(2 downto 0); -- AXILITE
signal m_axi_awqos    : std_logic_vector(3 downto 0); -- AXI4
signal m_axi_awregion : std_logic_vector(3 downto 0); -- AXI4
signal m_axi_awvalid  : std_logic;
signal m_axi_awready  : std_logic;

----- Master Port: Write Data -----
signal m_axi_wid      : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0); -- AXI3
signal m_axi_wdata    : std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0); -- AXILITE
signal m_axi_wstrb    : std_logic_vector(C_AXI_DATA_WIDTH/8-1 downto 0); -- AXILITE
signal m_axi_wlast    : std_logic;
signal m_axi_wvalid   : std_logic;
signal m_axi_wready   : std_logic;

----- Master Port: Write Response -----
signal m_axi_bid      : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
signal m_axi_bresp    : std_logic_vector(1 downto 0) := (others => '0'); -- AXILITE
signal m_axi_bvalid   : std_logic;
signal m_axi_bready   : std_logic;

----- Master Port: Read Data -----
signal m_axi_arid     : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);
signal m_axi_araddr   : std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0); -- AXILITE
signal m_axi_arlen    : std_logic_vector(AXI_LEN_WIDTH(C_AXI_PROTOCOL)-1 downto 0); -- AXI3 (3 downto 0), AXI4 (7 downto 0)
signal m_axi_arsize   : std_logic_vector(2 downto 0);
signal m_axi_arburst  : std_logic_vector(1 downto 0);
signal m_axi_arlock   : std_logic_vector(AXI_LOCK_WIDTH(C_AXI_PROTOCOL)-1 downto 0); -- AXI3 (1 downto 0), AXI4 (0 downto 0)
signal m_axi_arcache  : std_logic_vector(3 downto 0);
signal m_axi_arprot   : std_logic_vector(2 downto 0); -- AXILITE
signal m_axi_arqos    : std_logic_vector(3 downto 0); -- AXI4
signal m_axi_arregion : std_logic_vector(3 downto 0); -- AXI4
signal m_axi_arvalid  : std_logic;
signal m_axi_arready  : std_logic;

----- Master Port: Read Data -----
signal m_axi_rid      : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
signal m_axi_rdata    : std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0) := (others => '0'); -- AXILITE
signal m_axi_rresp    : std_logic_vector(1 downto 0) := (others => '0'); -- AXILITE
signal m_axi_rlast    : std_logic := '1';
signal m_axi_rvalid   : std_logic;
signal m_axi_rready   : std_logic;

signal done_write_success : std_logic;
signal done_read_success  : std_logic;
signal done_master_writes : std_logic;
signal done_master_reads  : std_logic;
signal transmission_en    : std_logic := '0';

--******************************************************************************
-- Connectivity and Logic
--******************************************************************************

begin

s_axi_lite_aclk    <= not s_axi_lite_aclk after 10 ns;
s_axi_lite_aresetn <= '1' after 1 us;  
transmission_en    <= '1' after 2 us;

s_axi_aclk     	   <= not s_axi_aclk after 8 ns;
s_axi_aresetn  	   <= '1' after 1 us; 

m_axi_aclk     	   <= not m_axi_aclk after 8 ns;
m_axi_aresetn  	   <= '1' after 1 us; 

---------------------------------------
-- axi_lite write interface (uses axi_4_write_master.vhd module)
---------------------------------------

axi_lite_write_master_inst : entity axi_delay_lib.axi4_write_master
    generic map (
        MEM_DATA_WIDTH  => C_AXI_LITE_DATA_WIDTH, --: integer range 32 to 1024 := 64;
        BURST_LENGTH    => C_AXI_LITE_BURST_LEN,  --: integer range 1  to 256 := 16; -- No. of Transfers
        C_NUM_BURST     => C_AXI_LITE_NUM_BURST,  --: integer range 1  to 1024 := 2 -- Total transfers = C_NUM_BURST*BURST_LENGTH
        C_START_ADDR    => C_AXI_LITE_START_ADDR
    )
    port map (

        clock           => s_axi_lite_aclk,    --: in  std_logic           		:= '0' ;       
        resetn          => s_axi_lite_aresetn, --: in  std_logic          		:= '1' ;       

        -- Write Address Channel                                        
        awaddr          => s_axi_lite_awaddr,  --: out std_logic_vector(31 downto 0);         
        awlen           => OPEN,               --: out std_logic_vector(7 downto 0);      
        awsize          => OPEN,               --: out std_logic_vector(2 downto 0);      
        awburst         => OPEN,               --: out std_logic_vector(1 downto 0);      
        awprot          => s_axi_lite_awprot,  --: out std_logic_vector(2 downto 0);      
        awcache         => OPEN,               --: out std_logic_vector(3 downto 0);      
        awvalid         => s_axi_lite_awvalid, --: out std_logic;      
        awready         => s_axi_lite_awready, --: in  std_logic := '1';
                                                                        
        -- Write Data Channel                                           
        wdata           => s_axi_lite_wdata,   --: out std_logic_vector(MEM_DATA_WIDTH-1 downto 0);               
        wstrb           => s_axi_lite_wstrb,   --: out std_logic_vector((MEM_DATA_WIDTH/8)-1 downto 0);           
        wlast           => OPEN,               --: out std_logic;      
        wvalid          => s_axi_lite_wvalid,  --: out std_logic;      
        wready          => s_axi_lite_wready,  --: in  std_logic := '1';
                                                                        
        -- Write Response Channel                                       
        bresp           => s_axi_lite_bresp,   --: in  std_logic_vector(1 downto 0) := (others => '0');
        bvalid          => s_axi_lite_bvalid,  --: in  std_logic := '0';             
        bready          => s_axi_lite_bready,  --: out std_logic;                   
                                                                                     
        -- Stream to Memory Map Steam Interface                                      
        done_write_success => done_write_success --: out std_logic                                       
    );

---------------------------------------
-- axi_lite write interface (uses axi_4_write_master.vhd module)
---------------------------------------

axi_lite_read_master_inst : entity axi_delay_lib.axi4_write_master
    generic map (
        MEM_DATA_WIDTH  => C_AXI_LITE_DATA_WIDTH, --: integer range 32 to 1024 := 64;
        BURST_LENGTH    => C_AXI_LITE_BURST_LEN,  --: integer range 1  to 256 := 16; -- No. of Transfers
        C_NUM_BURST     => C_AXI_LITE_NUM_BURST,  --: integer range 1  to 1024 := 2 -- Total transfers = C_NUM_BURST*BURST_LENGTH
        C_START_ADDR    => C_AXI_LITE_START_ADDR
    )
    port map (

        clock           => s_axi_lite_aclk,        
        resetn          => done_write_success,     

        -- READ Address Channel              
        awaddr          => s_axi_lite_araddr, 
        awlen           => OPEN,              
        awsize          => OPEN,              
        awburst         => OPEN,              
        awprot          => s_axi_lite_arprot, 
        awcache         => OPEN,              
        awvalid         => s_axi_lite_arvalid,
        awready         => s_axi_lite_arready,
                                                                        
        -- Write Data Channel  (Unused)                                          
        wdata           => OPEN,      
        wstrb           => OPEN,      
        wlast           => OPEN,
        wvalid          => OPEN,
        wready          => '1', 
                                                                        
        -- Read Data Channel                                       
        bresp           => s_axi_lite_rresp, 
        bvalid          => s_axi_lite_rvalid,
        bready          => s_axi_lite_rready,                 
                                                                                     
        -- Stream to Memory Map Steam Interface                                      
        done_write_success => done_read_success                                    
    );

---------------------------------------
-- axi master write interface (uses axi_4_write_master.vhd module)
---------------------------------------

axi_master_write_inst : entity axi_delay_lib.axi4_write_master
    generic map (
        MEM_DATA_WIDTH  => C_AXI_DATA_WIDTH, --: integer range 32 to 1024 := 64;
        BURST_LENGTH    => C_AXI_BURST_LEN,  --: integer range 1  to 256 := 16; -- No. of Transfers
        C_NUM_BURST     => C_AXI_NUM_BURST,  --: integer range 1  to 1024 := 2 -- Total transfers = C_NUM_BURST*BURST_LENGTH
        C_START_ADDR    => C_AXI_START_ADDR(31 downto 0)
    )
    port map (

        clock           => s_axi_aclk,        
        resetn          => done_read_success,     

        -- Write Address Channel - Unused: s_axi_awid, s_axi_awlock, s_axi_awqos,s_axi_awregion,s_axi_awuser             
        awaddr          => s_axi_awaddr(31 downto 0),
        awlen           => s_axi_awlen,              
        awsize          => s_axi_awsize,   
        awburst         => s_axi_awburst,  
        awprot          => s_axi_awprot, 
        awcache         => s_axi_awcache,  
        awvalid         => s_axi_awvalid,
        awready         => s_axi_awready,
                                           
        -- Write Data Channel - Unused: s_axi_wid, s_axi_wuser  
        wdata           => s_axi_wdata,      	
        wstrb           => s_axi_wstrb,      	
        wlast           => s_axi_wlast,		
        wvalid          => s_axi_wvalid,	
        wready          => s_axi_wready, 	
                   				
        -- Write Response Channel - Unused Ports: s_axi_bid, s_axi_buser
        bresp           => s_axi_bresp,    
        bvalid          => s_axi_bvalid,
        bready          => s_axi_bready,    
                                                                       
        -- Stream to Memory Map Steam Interface                               
        done_write_success => done_master_writes                                    
    );

    -- fill out bus width mismatches
    s_axi_awaddr(C_AXI_ADDR_WIDTH-1 downto 32) <= (others => '0');

---------------------------------------
-- axi master read interface (uses axi_4_write_master.vhd module)
---------------------------------------

axi_master_read_inst : entity axi_delay_lib.axi4_write_master
    generic map (
        MEM_DATA_WIDTH  => C_AXI_DATA_WIDTH, --: integer range 32 to 1024 := 64;
        BURST_LENGTH    => C_AXI_BURST_LEN,  --: integer range 1  to 256 := 16; -- No. of Transfers
        C_NUM_BURST     => C_AXI_NUM_BURST,  --: integer range 1  to 1024 := 2 -- Total transfers = C_NUM_BURST*BURST_LENGTH
        C_START_ADDR    => C_AXI_START_ADDR(31 downto 0)
    )
    port map (

        clock           => s_axi_aclk,
        resetn          => done_master_writes,

        -- Read Address Channel - Unused Ports: s_axi_arid, s_axi_arlock, s_axi_arqos, s_axi_arregion, s_axi_aruser
        awaddr          => s_axi_araddr(31 downto 0),
        awlen           => s_axi_arlen,
        awsize          => s_axi_arsize,
        awburst         => s_axi_arburst,
        awprot          => s_axi_arprot,
        awcache         => s_axi_arcache,
        awvalid         => s_axi_arvalid,
        awready         => s_axi_arready,
                                           	
        -- Read Data Channel (unused)		
        wdata           => OPEN, 				 
        wstrb           => OPEN, 				 
        wlast           => OPEN, 
        wvalid          => OPEN,
        wready          => OPEN,

        -- Read Response Channel - Unused: s_axi_rid, s_axi_rdata, s_axi_rlast,s_axi_ruser
        bresp           => s_axi_rresp,
        bvalid          => s_axi_rvalid,
        bready          => s_axi_rready,

        -- Stream to Memory Map Steam Interface
        done_write_success => done_master_reads
    );

---------------------------------------		
-- axi_delayv					
---------------------------------------		
						
axi_delayv_int : entity axi_delay_lib.axi_delayv
    generic map (				
        C_FAMILY              => C_FAMILY,      
        C_AXI_PROTOCOL        => C_AXI_PROTOCOL,
        C_MEM_ADDR_WIDTH      => C_MEM_ADDR_WIDTH,
        C_COUNTER_WIDTH       => C_COUNTER_WIDTH, 
        C_FIFO_DEPTH_AW       => C_FIFO_DEPTH_AW, 
        C_FIFO_DEPTH_W        => C_FIFO_DEPTH_W,  
        C_FIFO_DEPTH_B        => C_FIFO_DEPTH_B,  
        C_FIFO_DEPTH_AR       => C_FIFO_DEPTH_AR, 
        C_FIFO_DEPTH_R        => C_FIFO_DEPTH_R,  
        
        -- AXI-Lite Bus Interface
        C_AXI_LITE_ADDR_WIDTH => C_AXI_LITE_ADDR_WIDTH,
        C_AXI_LITE_DATA_WIDTH => C_AXI_LITE_DATA_WIDTH,
        
        -- AXI-Full Bus Interface
        C_AXI_ID_WIDTH        => C_AXI_ID_WIDTH,  
        C_AXI_ADDR_WIDTH      => C_AXI_ADDR_WIDTH,
        C_AXI_DATA_WIDTH      => C_AXI_DATA_WIDTH,
        
        -- chan_delay_variable
        PRIORITY_QUEUE_WIDTH  => PRIORITY_QUEUE_WIDTH,
        DELAY_WIDTH           => DELAY_WIDTH,         
        BYPASS_MINICAM        => BYPASS_MINICAM,      
        CAM_DEPTH             => CAM_DEPTH,           
        NUM_MINI_BUFS         => NUM_MINI_BUFS       
    )
    port map (
	-- AXI-Lite Slave Bus Interface S_AXI_LITE
	s_axi_lite_aclk    => s_axi_lite_aclk,                                                                                    
	s_axi_lite_aresetn => s_axi_lite_aresetn,                                                                                 
		                                                                                
	s_axi_lite_awaddr  => s_axi_lite_awaddr(C_AXI_LITE_ADDR_WIDTH-1 downto 0),                                                                                  
	s_axi_lite_awprot  => s_axi_lite_awprot,                                                                                  
	s_axi_lite_awvalid => s_axi_lite_awvalid,                                                                                 
	s_axi_lite_awready => s_axi_lite_awready,                                                                                 
	--		      --		                                                                                
	s_axi_lite_wdata   => s_axi_lite_wdata,                                                                                   
	s_axi_lite_wstrb   => s_axi_lite_wstrb,                                                                                   
	s_axi_lite_wvalid  => s_axi_lite_wvalid,                                                                                  
	s_axi_lite_wready  => s_axi_lite_wready,                                                                                  
	--		      --		                                                                                
	s_axi_lite_bresp   => s_axi_lite_bresp,                                                                                   
	s_axi_lite_bvalid  => s_axi_lite_bvalid,                                                                                  
	s_axi_lite_bready  => s_axi_lite_bready,                                                                                  
	--		      --		                                                                                
	s_axi_lite_araddr  => s_axi_lite_araddr(C_AXI_LITE_ADDR_WIDTH-1 downto 0),                                                                                  
	s_axi_lite_arprot  => s_axi_lite_arprot,                                                                                  
	s_axi_lite_arvalid => s_axi_lite_arvalid,                                                                                 
	s_axi_lite_arready => s_axi_lite_arready,                                                                                 
	--		      --		                                                                                
	s_axi_lite_rdata   => s_axi_lite_rdata,                                                                                   
	s_axi_lite_rresp   => s_axi_lite_rresp,                                                                                   
	s_axi_lite_rvalid  => s_axi_lite_rvalid,                                                                                  
	s_axi_lite_rready  => s_axi_lite_rready,                                                                                  

	----- AXI-Full Slave Bus Interface S_AXI -----
	s_axi_aclk     	  => s_axi_aclk,   
	s_axi_aresetn  	  => s_axi_aresetn,

	----- Slave Port: Write Address -----
	s_axi_awid     	  => s_axi_awid,    
	s_axi_awaddr   	  => s_axi_awaddr,  
	s_axi_awlen    	  => s_axi_awlen,   
	s_axi_awsize   	  => s_axi_awsize,  
	s_axi_awburst  	  => s_axi_awburst, 
	s_axi_awlock   	  => s_axi_awlock,  
	s_axi_awcache  	  => s_axi_awcache, 
	s_axi_awprot   	  => s_axi_awprot,  
	s_axi_awqos    	  => s_axi_awqos,   
	s_axi_awregion 	  => s_axi_awregion,
--	s_axi_awuser   	  => s_axi_awuser,  
	s_axi_awvalid  	  => s_axi_awvalid, 
	s_axi_awready  	  => s_axi_awready, 
			  
	----- Slave Port:  Data -----
	s_axi_wid     	  => s_axi_wid,   
	s_axi_wdata   	  => s_axi_wdata, 
	s_axi_wstrb   	  => s_axi_wstrb, 
	s_axi_wlast   	  => s_axi_wlast, 
--	s_axi_wuser   	  => s_axi_wuser, 
	s_axi_wvalid  	  => s_axi_wvalid,
	s_axi_wready  	  => s_axi_wready,
			  
	----- Slave Port: Write Response -----
	s_axi_bid      	  => s_axi_bid,   
	s_axi_bresp    	  => s_axi_bresp, 
--	s_axi_buser    	  => s_axi_buser, 
	s_axi_bvalid   	  => s_axi_bvalid,
	s_axi_bready   	  => s_axi_bready,
			  
	----- Slave Port: Read Adress -----
	s_axi_arid     	  => s_axi_arid,    
	s_axi_araddr   	  => s_axi_araddr,  
	s_axi_arlen    	  => s_axi_arlen,   
	s_axi_arsize   	  => s_axi_arsize,  
	s_axi_arburst  	  => s_axi_arburst, 
	s_axi_arlock   	  => s_axi_arlock,  
	s_axi_arcache  	  => s_axi_arcache, 
	s_axi_arprot   	  => s_axi_arprot,  
	s_axi_arqos    	  => s_axi_arqos,   
	s_axi_arregion 	  => s_axi_arregion,
--	s_axi_aruser   	  => s_axi_aruser,  
	s_axi_arvalid  	  => s_axi_arvalid, 
	s_axi_arready  	  => s_axi_arready, 
			  
	----- Slave Port:  Data -----
	s_axi_rid      	  => s_axi_rid,   
	s_axi_rdata    	  => s_axi_rdata, 
	s_axi_rresp    	  => s_axi_rresp, 
	s_axi_rlast    	  => s_axi_rlast, 
--	s_axi_ruser    	  => s_axi_ruser, 
	s_axi_rvalid   	  => s_axi_rvalid,
	s_axi_rready   	  => s_axi_rready,
			  
	----- AXI-Full Master Bus Interface M_AXI -----
	m_axi_aclk     	  => m_axi_aclk,  
	m_axi_aresetn  	  => m_axi_aresetn,
			  
	----- Master Port: Write Adress -----
	m_axi_awid     	  => m_axi_awid,    
	m_axi_awaddr   	  => m_axi_awaddr,  
	m_axi_awlen    	  => m_axi_awlen,   
	m_axi_awsize   	  => m_axi_awsize,  
	m_axi_awburst  	  => m_axi_awburst, 
	m_axi_awlock   	  => m_axi_awlock,  
	m_axi_awcache  	  => m_axi_awcache, 
	m_axi_awprot   	  => m_axi_awprot,  
	m_axi_awqos    	  => m_axi_awqos,   
	m_axi_awregion 	  => m_axi_awregion,
--	m_axi_awuser   	  => m_axi_awuser,  
	m_axi_awvalid  	  => m_axi_awvalid, 
	m_axi_awready  	  => m_axi_awready, 
			  
	----- Master Port: Write Data -----
	m_axi_wid      	  => m_axi_wid,     
	m_axi_wdata    	  => m_axi_wdata,   
	m_axi_wstrb    	  => m_axi_wstrb,   
	m_axi_wlast    	  => m_axi_wlast,   
--	m_axi_wuser    	  => m_axi_wuser,   
	m_axi_wvalid   	  => m_axi_wvalid,  
	m_axi_wready   	  => m_axi_wready,  
			  		
	----- Master Port: Write Response -----
	m_axi_bid      	  => m_axi_bid,     
	m_axi_bresp    	  => m_axi_bresp,   
--	m_axi_buser    	  => m_axi_buser,   
	m_axi_bvalid   	  => m_axi_bvalid,  
	m_axi_bready   	  => m_axi_bready,  
	
	----- Master Port: Read Address -----
	m_axi_arid     	  => m_axi_arid,    
	m_axi_araddr   	  => m_axi_araddr,  
	m_axi_arlen    	  => m_axi_arlen,   
	m_axi_arsize   	  => m_axi_arsize,  
	m_axi_arburst  	  => m_axi_arburst, 
	m_axi_arlock   	  => m_axi_arlock,  
	m_axi_arcache  	  => m_axi_arcache, 
	m_axi_arprot   	  => m_axi_arprot,  
	m_axi_arqos    	  => m_axi_arqos,   
	m_axi_arregion 	  => m_axi_arregion,
--	m_axi_aruser   	  => m_axi_aruser,  
	m_axi_arvalid  	  => m_axi_arvalid, 
	m_axi_arready  	  => m_axi_arready, 
			  		
	----- Master Port: Read Data -----
	m_axi_rid      	  => m_axi_rid,     
	m_axi_rdata    	  => m_axi_rdata,   
	m_axi_rresp    	  => m_axi_rresp,   
	m_axi_rlast    	  => m_axi_rlast,   
--	m_axi_ruser    	  => m_axi_ruser,   
	m_axi_rvalid   	  => m_axi_rvalid,  
	m_axi_rready   	  => m_axi_rready           
);    						    
						    
------------- Begin Cut here for INSTANTIATION Template ----- INST_TAG
axi_slave_mem : axi_bram_8Kx128
  PORT MAP (
    s_axi_aclk    => m_axi_aclk,
    s_axi_aresetn => m_axi_aresetn,
       
    s_axi_awid    => s_axi_awid,
    s_axi_awaddr  => m_axi_awaddr(16 downto 0), 				      
    s_axi_awlen   => m_axi_awlen,  				      
    s_axi_awsize  => m_axi_awsize, 				      
    s_axi_awburst => m_axi_awburst,				      
    s_axi_awlock  => m_axi_awlock(0), 				      
    s_axi_awcache => m_axi_awcache,				      
    s_axi_awprot  => m_axi_awprot, 				      
    s_axi_awvalid => m_axi_awvalid,
    s_axi_awready => m_axi_awready,
    				
    s_axi_wdata   => m_axi_wdata,   -- UNUSED: m_axi_wid, m_axi_wuser		      
    s_axi_wstrb   => m_axi_wstrb,  
    s_axi_wlast   => m_axi_wlast,
    s_axi_wvalid  => m_axi_wvalid,
    s_axi_wready  => m_axi_wready,
				
    s_axi_bid     => m_axi_bid,     -- UNUSED: m_axi_buser	
    s_axi_bresp   => m_axi_bresp,		
    s_axi_bvalid  => m_axi_bvalid,
    s_axi_bready  => m_axi_bready,    
						       
    s_axi_arid    => m_axi_arid,    -- UNUSED: m_axi_arqos, m_axi_arregion, m_axi_aruser
    s_axi_araddr  => m_axi_araddr(16 downto 0), 
    s_axi_arlen   => m_axi_arlen,  
    s_axi_arsize  => m_axi_arsize, 
    s_axi_arburst => m_axi_arburst,
    s_axi_arlock  => m_axi_arlock(0), 
    s_axi_arcache => m_axi_arcache,
    s_axi_arprot  => m_axi_arprot, 
    s_axi_arvalid => m_axi_arvalid,
    s_axi_arready => m_axi_arready,	
					
    s_axi_rid     => m_axi_rid,   -- UNUSED: m_axi_ruser
    s_axi_rdata   => m_axi_rdata,
    s_axi_rresp   => m_axi_rresp,
    s_axi_rlast   => m_axi_rlast,
    s_axi_rvalid  => m_axi_rvalid,
    s_axi_rready  => m_axi_rready
  );					
					
---------------------------------------	
					
end Behavioral;				
