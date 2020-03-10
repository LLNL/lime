library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;

entity axi_slave is
    generic (
        C_AXI_ID_WIDTH    : integer := 4;
        C_AXI_ADDR_WIDTH  : integer := 40;
        C_AXI_DATA_WIDTH  : integer := 128;
        CHANNEL_TYPE      : string := "AW"  -- valid values are:  AW, W, B, AR, R
    );    
   port (
        s_axi_aclk_i    : in  std_logic;
        s_axi_aresetn_i : in  std_logic;
        
        s_axi_id_i      : in  std_logic_vector(C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
        s_axi_addr_i    : in  std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0) := (others => '0'); 
        s_axi_data_i    : in  std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0) := (others => '0'); 
        s_axi_strb_i    : in  std_logic_vector((C_AXI_DATA_WIDTH/8)-1 downto 0) := (others => '1'); 
        s_axi_len_i     : in  std_logic_vector(7 downto 0) := (others => '0'); 
        s_axi_size_i    : in  std_logic_vector(2 downto 0) := "110";
        s_axi_burst_i   : in  std_logic_vector(1 downto 0) := "01";
        s_axi_lock_i    : in  std_logic_vector(1 downto 0) := (others => '0');
        s_axi_cache_i   : in  std_logic_vector(3 downto 0) := (others => '0');
        s_axi_prot_i    : in  std_logic_vector(2 downto 0) := (others => '0');
        s_axi_qos_i     : in  std_logic_vector(3 downto 0) := (others => '0');
        s_axi_region_i  : in  std_logic_vector(3 downto 0) := (others => '0');
        s_axi_valid_i   : in  std_logic;
        s_axi_ready_o   : out std_logic;
	    	       	
        s_axi_last_i    : in  std_logic;
        s_axi_resp_i    : in  std_logic_vector(1 downto 0)
   );
end entity axi_slave;

architecture arch_axi_slave of axi_slave is

file maxi_out : TEXT open write_mode is "../../../../axi_variable_delay.srcs/sim_1/data_out/maxi_out.txt";

--------------------------------------------------------------------------------
-- Component Declarations (needed for verilog modules, which are not entities)
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Signal Definitions
--------------------------------------------------------------------------------
signal s_axi_ready       : std_logic;

signal data_xfer_in_prog : std_logic;
signal timer             : std_logic_vector(31 downto 0);

signal addr_resp_flag    : std_logic; -- asserted for either address cycle or response cycle
signal first_data_flag   : std_logic; -- asserted for first event of data sequence
signal mid_data_flag     : std_logic; -- asserted for all data sequences between the first and last
signal last_data_flag    : std_logic; -- asserted for last event of data sequence
signal first_data        : std_logic; -- asserted for first event of data sequence
signal mid_data          : std_logic; -- asserted for all data sequences between the first and last
signal last_data         : std_logic; -- asserted for last event of data sequence

signal s_axi_resp        : std_logic_vector(1 downto 0);
signal s_axi_id          : std_logic_vector(C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
signal s_axi_addr        : std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0) := (others => '0'); 
signal s_axi_data        : std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0) := (others => '0'); 
signal s_axi_strb        :  std_logic_vector((C_AXI_DATA_WIDTH/8)-1 downto 0) := (others => '1'); 
signal s_axi_len         : std_logic_vector(7 downto 0) := (others => '0'); 
signal s_axi_size        : std_logic_vector(2 downto 0) := "110";
signal s_axi_burst       : std_logic_vector(1 downto 0) := "01";
signal s_axi_lock        : std_logic_vector(1 downto 0) := (others => '0');
signal s_axi_cache       : std_logic_vector(3 downto 0) := (others => '0');
signal s_axi_prot        : std_logic_vector(2 downto 0) := (others => '0');
signal s_axi_qos         : std_logic_vector(3 downto 0) := (others => '0');
signal s_axi_region      : std_logic_vector(3 downto 0) := (others => '0');
signal s_axi_valid       : std_logic;    	       	
signal s_axi_last        : std_logic;
--------------------------------------------------------------------------------
begin

-- randomize this later

--******* CHECK THE TIMING AND FIX!!!!!!***************************************************************
s_axi_ready <= '1';  --******* CHECK THE TIMING AND FIX!!!!!!***************************************************************
--******* CHECK THE TIMING AND FIX!!!!!!***************************************************************

---------------------------------------
-- generate event identification flags for write address, read address, or write response bus types
---------------------------------------
addr_flag_gen : if (CHANNEL_TYPE = "AW" or CHANNEL_TYPE = "AR" or CHANNEL_TYPE = "B") generate
    data_xfer_in_prog <= '0';
    addr_resp_flag    <= s_axi_ready and s_axi_valid_i;
    first_data_flag   <= '0';
    mid_data_flag     <= '0'; 
    last_data_flag    <= '0'; 
end generate; 

---------------------------------------
-- generate event identification flags for read or write data bus types
---------------------------------------
data_flag_gen : if (CHANNEL_TYPE = "W" or CHANNEL_TYPE = "R") generate

    arbitration_pr : process(s_axi_aclk_i) begin
        if rising_edge(s_axi_aclk_i) then
            if (s_axi_aresetn_i = '0') then
                data_xfer_in_prog <= '0';
                addr_resp_flag  <= '0';
                first_data_flag <= '0';
                mid_data_flag   <= '0';
                last_data_flag  <= '0';
            else
                if (last_data = '1') then
                    data_xfer_in_prog <= '0';
                elsif (first_data = '1') then
                    data_xfer_in_prog <= '1';
                else
                    data_xfer_in_prog <= data_xfer_in_prog;
                end if;

                addr_resp_flag  <= '0';
                first_data_flag <= first_data;
                mid_data_flag   <= mid_data;
                last_data_flag  <= last_data;

            end if;
        end if;
    end process;

end generate;   

first_data <= s_axi_valid_i and s_axi_ready and (not data_xfer_in_prog);
mid_data   <= s_axi_valid_i and s_axi_ready and data_xfer_in_prog and not s_axi_last_i;
last_data  <= s_axi_valid_i and s_axi_ready and s_axi_last_i;

---------------------------------------
-- Register the inputs
---------------------------------------
arbitration_pr : process(s_axi_aclk_i) begin
    if rising_edge(s_axi_aclk_i) then
        if (s_axi_aresetn_i = '0') then
            s_axi_resp   <= (others => '0');
            s_axi_id     <= (others => '0');
            s_axi_addr   <= (others => '0');
            s_axi_data   <= (others => '0');
            s_axi_strb   <= (others => '0');
            s_axi_len    <= (others => '0');
            s_axi_size   <= (others => '0');
            s_axi_burst  <= (others => '0');
            s_axi_lock   <= (others => '0');
            s_axi_cache  <= (others => '0');
            s_axi_prot   <= (others => '0');
            s_axi_qos    <= (others => '0');
            s_axi_region <= (others => '0');
            s_axi_valid  <= '0';
            s_axi_last   <= '0';
            s_axi_resp   <= (others => '0');
            
            timer        <= (others => '0');
        else
            s_axi_resp   <= s_axi_resp_i;
            s_axi_id     <= s_axi_id_i;
            s_axi_data   <= s_axi_data_i;  
            s_axi_addr   <= s_axi_addr_i;
            s_axi_strb   <= s_axi_strb_i;
            s_axi_len    <= s_axi_len_i;   
            s_axi_size   <= s_axi_size_i;  
            s_axi_burst  <= s_axi_burst_i; 
            s_axi_lock   <= s_axi_lock_i;  
            s_axi_cache  <= s_axi_cache_i; 
            s_axi_prot   <= s_axi_prot_i;  
            s_axi_qos    <= s_axi_qos_i;   
            s_axi_region <= s_axi_region_i;
            s_axi_valid  <= s_axi_valid_i; 
            s_axi_last   <= s_axi_last_i;
            s_axi_resp   <= s_axi_resp_i;
            
            timer        <= timer + '1';
        end if;		        	      
    end if;		   
end process;		      
			 
---------------------------------------
-- Write to File
---------------------------------------

file_write_proc :  process (s_axi_aclk_i) is

VARIABLE line_out   : LINE;

begin
    if rising_edge(s_axi_aclk_i) then
        if (s_axi_aresetn_i = '1') then 
              
            if (addr_resp_flag = '1') then
                write      (line_out, string'(CHANNEL_TYPE));
                write      (line_out, string'(","));
                hwrite     (line_out, s_axi_addr);
                write      (line_out, string'(","));
                hwrite     (line_out, s_axi_len);
                write      (line_out, string'(","));
                hwrite     (line_out, s_axi_id);
                write      (line_out, string'(","));
                hwrite     (line_out, timer);
                writeline  (maxi_out, line_out);
            end if;
	    
            if (first_data_flag = '1' or mid_data_flag = '1' or last_data_flag = '1') then
                -- write the data indicator (first, mid, last)
                if (first_data_flag = '1') then
                    write      (line_out, string'("F"));
                end if;
                if (mid_data_flag = '1') then
                    write      (line_out, string'("M"));
                end if;
                if (last_data_flag = '1') then
                    write      (line_out, string'("L"));
                end if;
            
                write      (line_out, string'(CHANNEL_TYPE));               
                write      (line_out, string'(","));
                hwrite     (line_out, s_axi_data);
                write      (line_out, string'(","));
                hwrite     (line_out, s_axi_id);
                write      (line_out, string'(","));
                hwrite     (line_out, timer);
                writeline  (maxi_out, line_out);
            end if;

      end if;
      
   end if;
   
end process;   

-------------------------------------------------------------------------------
-- output signals
-------------------------------------------------------------------------------

s_axi_ready_o <= s_axi_ready;

-------------------------------------------------------------------------------

end architecture arch_axi_slave;

