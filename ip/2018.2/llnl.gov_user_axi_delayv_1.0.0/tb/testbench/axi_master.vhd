--**********************************************************************************************************
-- Chris Macaraeg
-- Lawrence Livermore National Labs
-- 2016-0104
-- host_rs422.vhd - Host RS422 interface

--*********************************************************************

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_textio.all;
use IEEE.numeric_std.all;
use std.textio.all;

entity axi_master is
generic (
    C_AXI_ID_WIDTH    : integer := 4;
    C_AXI_ADDR_WIDTH  : integer := 40;
    C_AXI_DATA_WIDTH  : integer := 128;
    CHANNEL_TYPE      : string := "AW"  -- valid values are:  AW, W, B, AR, R 
);
port (
    m_axi_aclk_i      : in  std_logic;
    m_axi_aresetn_i   : in  std_logic;
    
    -- Slave AXI Interface --
    m_axi_id_o        : out std_logic_vector(C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
    m_axi_addr_o      : out std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0) := (others => '0'); 
    m_axi_data_o      : out std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0) := (others => '0'); 
    m_axi_strb_o      : out std_logic_vector((C_AXI_DATA_WIDTH/8)-1 downto 0) := (others => '1');
    m_axi_len_o       : out std_logic_vector(7 downto 0) := (others => '0');
    m_axi_size_o      : out std_logic_vector(2 downto 0) := "110";
    m_axi_burst_o     : out std_logic_vector(1 downto 0) := "01";
    m_axi_lock_o      : out std_logic_vector(1 downto 0) := (others => '0');
    m_axi_cache_o     : out std_logic_vector(3 downto 0) := (others => '0');
    m_axi_prot_o      : out std_logic_vector(2 downto 0) := (others => '0'); 
    m_axi_qos_o       : out std_logic_vector(3 downto 0) := (others => '0');
    m_axi_region_o    : out std_logic_vector(3 downto 0) := (others => '0');
    m_axi_valid_o     : out std_logic;
    m_axi_ready_i     : in  std_logic;
	    	      
    m_axi_last_o      : out std_logic;
    m_axi_resp_o      : out std_logic_vector(1 downto 0);
    
    transmission_en_i : in std_logic
);

end entity axi_master;

architecture axi_master of axi_master is

file file_in      : text open read_mode is "../../../../axi_variable_delay.srcs/sim_1/data_in/axi_event.in";
file stat_out     : text open write_mode is "../../../../axi_variable_delay.srcs/sim_1/data_out/status_out.txt";

--*********************************************************************
-- Constants
--*********************************************************************
-- Note: Copied from channel_delay.vhd
signal AXI_INFO_WIDTH  : integer := 2 + C_AXI_ID_WIDTH + C_AXI_DATA_WIDTH + C_AXI_ADDR_WIDTH + C_AXI_DATA_WIDTH/8 + 
                                    8 + 3 + 2 + 2 + 4 + 3 + 4 + 4 + 1 + 1;

--*********************************************************************
--Signal Definitions
--*********************************************************************
signal ieg_cnt               : std_logic_vector(31 downto 0); -- inter-event cycle count
signal ieg_cnt_tc            : std_logic;
signal ieg_cyc               : std_logic_vector(31 downto 0);
signal valid_cycle           : std_logic;
                             
signal maxi_state_nxt        : std_logic_vector(2 downto 0);

signal axi_info_tmp          : std_logic_vector(AXI_INFO_WIDTH+31 downto 0);
signal m_axi_addr            : std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0) := (others => '0'); 

constant MAXI_SM_INIT        : std_logic_vector(2 downto 0) := "000";
constant MAXI_SM_VALID_EVENT : std_logic_vector(2 downto 0) := "001";
constant MAXI_SM_IPG         : std_logic_vector(2 downto 0) := "010";


--*********************************************************************
--Component Definitions
--*********************************************************************

--*********************************************************************
-- Connectivity and Logic
--*********************************************************************
begin

-----------------------------------------------------------------------
-- Registers
-----------------------------------------------------------------------

state_machine_reg_proc : process (m_axi_aclk_i) begin
    if rising_edge(m_axi_aclk_i) then
        if (m_axi_aresetn_i = '0') then              
            ieg_cnt        <= (others => '0');
        elsif m_axi_aclk_i'event and m_axi_aclk_i = '1' then  -- rising clock edge
                  
            if (maxi_state_nxt = MAXI_SM_VALID_EVENT) then
                if (ieg_cyc > x"000000001") then
                    ieg_cnt <= ieg_cyc - '1';
                else
                    ieg_cnt <= x"00000000";
                end if;
            elsif (ieg_cnt_tc = '1' or (ieg_cnt = x"00000000")) then
                ieg_cnt <= (others => '0');
            elsif (maxi_state_nxt = MAXI_SM_IPG) and (ieg_cnt_tc = '0') then
                ieg_cnt <= ieg_cnt - '1'; 
            end if;

        end if;
    end if;       
end process;

tc_proc : process (maxi_state_nxt, ieg_cyc, ieg_cnt) begin
    if (((maxi_state_nxt = MAXI_SM_VALID_EVENT) and (ieg_cyc <= x"00000000")) or
        ((maxi_state_nxt = MAXI_SM_IPG) and (ieg_cnt = x"00000001"))) then
        ieg_cnt_tc <= '1';
    else
        ieg_cnt_tc <= '0';
    end if;
end process;
    
-----------------------------------------------------------------------
-- State Machine
-----------------------------------------------------------------------

state_machine_proc : process (m_axi_aclk_i) 


   VARIABLE line_in   : LINE;
   VARIABLE line_out  : LINE;
   VARIABLE input_tmp : STD_LOGIC_VECTOR(AXI_INFO_WIDTH+31 downto 0);  -- add 32 for IPG

begin
    if rising_edge(m_axi_aclk_i) then
        if (m_axi_aresetn_i = '0') then
            valid_cycle   <= '0';
            ieg_cyc       <= (others => '0');
            axi_info_tmp  <= (others => '0');
            maxi_state_nxt <= MAXI_SM_INIT;
        else

            valid_cycle   <= '0';
            ieg_cyc     <= (others => '0'); 
      
      case maxi_state_nxt is
      
         when MAXI_SM_INIT  => 

            if (m_axi_aresetn_i = '0' or transmission_en_i = '0') then
               maxi_state_nxt <= MAXI_SM_INIT;
            else
               ------------------------------------------
               -- get test vector
               READLINE     (file_in, line_in);
               HREAD        (line_in, input_tmp);

               -- write status to stat_out file
               write      (line_out, string'("input from file: "));
               hwrite     (line_out, input_tmp);
               writeline  (stat_out, line_out);
               ------------------------------------------
               valid_cycle <= '1';
               ieg_cyc      <= input_tmp(32+2+C_AXI_ID_WIDTH+C_AXI_ADDR_WIDTH+C_AXI_DATA_WIDTH+(C_AXI_DATA_WIDTH/8)+31 downto
                                         2+C_AXI_ID_WIDTH+C_AXI_ADDR_WIDTH+C_AXI_DATA_WIDTH+(C_AXI_DATA_WIDTH/8)+32);
               axi_info_tmp <= input_tmp;
               ------------------------------------------
               maxi_state_nxt <= MAXI_SM_VALID_EVENT;
            end if;  
                         
         when MAXI_SM_VALID_EVENT  =>
         
            if (ieg_cyc = x"00000000") then
               ------------------------------------------
               -- get test vector
               READLINE     (file_in, line_in);
               HREAD        (line_in, input_tmp);

               -- write status to stat_out file
               write      (line_out, string'("input from file: "));
               hwrite     (line_out, input_tmp);
               writeline  (stat_out, line_out);
               ------------------------------------------
               valid_cycle <= '1';
               ieg_cyc      <= input_tmp(32+2+C_AXI_ID_WIDTH+C_AXI_ADDR_WIDTH+C_AXI_DATA_WIDTH+(C_AXI_DATA_WIDTH/8)+31 downto
                                         2+C_AXI_ID_WIDTH+C_AXI_ADDR_WIDTH+C_AXI_DATA_WIDTH+(C_AXI_DATA_WIDTH/8)+32);
               axi_info_tmp <= input_tmp;
               ------------------------------------------
               maxi_state_nxt <= MAXI_SM_VALID_EVENT;
            else
                maxi_state_nxt <= MAXI_SM_IPG;
            end if;
                 
         when MAXI_SM_IPG  =>
            if (ieg_cnt_tc = '1' or ieg_cnt = x"00000000") then
               ------------------------------------------
               -- get test vector from file_in
               READLINE     (file_in, line_in);
               HREAD        (line_in, input_tmp);

               -- write status to stat_out file (for debug only)
               write      (line_out, string'("input from file: "));
               hwrite     (line_out, input_tmp);
               writeline  (stat_out, line_out);
               ------------------------------------------
               valid_cycle <= '1';
               ieg_cyc      <= input_tmp(32+2+C_AXI_ID_WIDTH+C_AXI_ADDR_WIDTH+C_AXI_DATA_WIDTH+(C_AXI_DATA_WIDTH/8)+31 downto
                                         2+C_AXI_ID_WIDTH+C_AXI_ADDR_WIDTH+C_AXI_DATA_WIDTH+(C_AXI_DATA_WIDTH/8)+32);
               axi_info_tmp <= input_tmp;
               ------------------------------------------
               maxi_state_nxt <= MAXI_SM_VALID_EVENT;
            else
               maxi_state_nxt <= MAXI_SM_IPG;
            end if;      
                    
         when others =>
            maxi_state_nxt <= MAXI_SM_INIT;
            
      end case;
   end if;
end if;
end process state_machine_proc;

m_axi_addr   <= axi_info_tmp(C_AXI_ADDR_WIDTH+C_AXI_DATA_WIDTH+(C_AXI_DATA_WIDTH/8)+31 downto
                             C_AXI_DATA_WIDTH+(C_AXI_DATA_WIDTH/8)+32);

----------------------------------------------------------------------------------------------
-- Output assignments
----------------------------------------------------------------------------------------------
reg_out_proc : process (m_axi_aclk_i) begin
    if rising_edge(m_axi_aclk_i) then
        if (m_axi_aresetn_i = '0' or valid_cycle = '0' or m_axi_addr = x"ffffffffff") then        
            m_axi_resp_o   <= (others => '0');      
            m_axi_id_o     <= (others => '0');
            m_axi_addr_o   <= (others => '0');   
            m_axi_data_o   <= (others => '0');  
            m_axi_strb_o   <= (others => '0');
            m_axi_len_o    <= (others => '0');   
            m_axi_size_o   <= (others => '0');  
            m_axi_burst_o  <= (others => '0'); 
            m_axi_lock_o   <= (others => '0');  
            m_axi_cache_o  <= (others => '0'); 
            m_axi_prot_o   <= (others => '0');  
            m_axi_qos_o    <= (others => '0');   
            m_axi_region_o <= (others => '0');
            m_axi_valid_o  <= '0';
            m_axi_last_o   <= '0';  
        else
            m_axi_resp_o   <= axi_info_tmp(2+C_AXI_ID_WIDTH+C_AXI_ADDR_WIDTH+C_AXI_DATA_WIDTH+(C_AXI_DATA_WIDTH/8)+31 downto
                                C_AXI_ID_WIDTH+C_AXI_ADDR_WIDTH+C_AXI_DATA_WIDTH+(C_AXI_DATA_WIDTH/8)+32);
            m_axi_id_o     <= axi_info_tmp(C_AXI_ID_WIDTH+C_AXI_ADDR_WIDTH+C_AXI_DATA_WIDTH+(C_AXI_DATA_WIDTH/8)+31 downto
                                C_AXI_ADDR_WIDTH+C_AXI_DATA_WIDTH+(C_AXI_DATA_WIDTH/8)+32);
            m_axi_addr_o   <= m_axi_addr;
            m_axi_data_o   <= axi_info_tmp(C_AXI_DATA_WIDTH+(C_AXI_DATA_WIDTH/8)+31 downto
                                (C_AXI_DATA_WIDTH/8)+32);
            m_axi_strb_o   <= axi_info_tmp((C_AXI_DATA_WIDTH/8)+31 downto 32);
            m_axi_len_o    <= axi_info_tmp(31 downto 24);
            m_axi_size_o   <= axi_info_tmp(23 downto 21);
            m_axi_burst_o  <= axi_info_tmp(20 downto 19);
            m_axi_lock_o   <= axi_info_tmp(18 downto 17);
            m_axi_cache_o  <= axi_info_tmp(16 downto 13);
            m_axi_prot_o   <= axi_info_tmp(12 downto 10);
            m_axi_qos_o    <= axi_info_tmp(9 downto 6);
            m_axi_region_o <= axi_info_tmp(5 downto 2);
            m_axi_valid_o  <= axi_info_tmp(1);
            m_axi_last_o   <= axi_info_tmp(0);
        end if;
    end if;
end process;

----------------------------------------------------------------------------------------------

end axi_master;
