--**********************************************************************************************************
-- Lawrence Livermore National Labs
-- 20191119 CM Initial creation 
-- minicam.vhd:  This module implements the MiniCAM function, which is a very small content-addressable memory.
--               An AXI ID (axi_id) is presented at the input, and a counter/pointer (cntr_pntr) to the Packet Buffer
--               is returned.
--**********************************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library axi_delay_lib;
use axi_delay_lib.all;

entity minicam is
generic (
    CAM_DEPTH           : integer := 8;  -- depth of cam (i.e. number of entries), must be modulo 2
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
end minicam;

architecture minicam of minicam is

--******************************************************************************
-- Constants
--******************************************************************************

--******************************************************************************
--Signal Definitions
--******************************************************************************
signal ZEROS             : std_logic_vector(CAM_WIDTH-1 downto CTR_PTR_WIDTH) := (others => '0');
type cam_array is array (0 to (CAM_DEPTH-1)) of std_logic_vector((CAM_WIDTH-1) downto 0);
signal cam_memory        : cam_array; 

type ctr_ptr_array is array (0 to (CAM_DEPTH-1)) of std_logic_vector((CTR_PTR_WIDTH-1) downto 0);
signal ctr_ptr_start     : ctr_ptr_array; -- start (initial) ctr_ptr
signal ctr_ptr           : ctr_ptr_array; -- incremented ctr_ptr, to be used directly by packet_buffer
signal ctr_ptr_l         : integer;-- counter/pointer to Packet Buffer
signal available_ctrptr  : std_logic;

signal active            : std_logic_vector((CAM_DEPTH-1) downto 0); -- location is still active (busy)
signal valid             : std_logic_vector((CAM_DEPTH-1) downto 0); -- location contains a valid counter/pointer
signal available         : std_logic_vector((CAM_DEPTH-1) downto 0); -- available location (!active && valid)
signal minibuf_rdata     : std_logic_vector(CTR_PTR_WIDTH-1 downto 0);
signal minibuf_rd        : std_logic;
signal minibuf_rd_q      : std_logic;
signal minibuf_af        : std_logic;
signal minibuf_fe        : std_logic;
signal minibuf_ctr_cs    : integer range 0 to (CAM_DEPTH-1);
signal minibuf_ctr_ns    : integer range 0 to (CAM_DEPTH-1);
signal minibuf_rdy       : std_logic;
signal minicam_hit_slv   : std_logic_vector(CAM_DEPTH-1 downto 0);
signal minicam_hit       : std_logic;
signal debug_code        : integer := 0;

constant VCPSM_IDLE      : std_logic_vector(1 downto 0) := "00";
constant VCPSM_INIT      : std_logic_vector(1 downto 0) := "01"; -- read new ctr_ptr, assert VALID and store ctr_ptr
constant VCPSM_NORMAL_OP : std_logic_vector(1 downto 0) := "10"; -- wait for new value from minibuf_fifo 
signal valid_ctrptr_cs   : std_logic_vector(1 downto 0) := "00";
signal valid_ctrptr_ns   : std_logic_vector(1 downto 0) := "00";

--******************************************************************************
-- Connectivity and Logic
--******************************************************************************

begin

minibuf_mgmt_inst : entity axi_delay_lib.minibuf_mgmt
    generic map (
        CAM_DEPTH           => CAM_DEPTH,           -- depth of cam (i.e. number of entried), must be modulo 2
        CTR_PTR_WIDTH       => CTR_PTR_WIDTH,       -- width of counter/pointer, which is the index to the Packet Buffer (start of mini-buffer)
        NUM_EVENTS_PER_MBUF => NUM_EVENTS_PER_MBUF, -- maximum number of events each minibuffer can hold
        NUM_MINI_BUFS       => NUM_MINI_BUFS        -- number of minibufs; each must be sized to hold the largest packet size supported
    )
    port map (
        clk_i               => clk_i,
        rst_i               => rst_i,
        minibuf_wr_i        => minibuf_wr_i,
        minibuf_rd_i        => minibuf_rd,
        minibuf_af_o        => minibuf_af,
        minibuf_fe_o        => minibuf_fe,
        minibuf_rdy_o       => minibuf_rdy,
        minibuf_wdata_i     => minibuf_wdata_i,
        minibuf_rdata_o     => minibuf_rdata
    );

compare_proc : process (cam_memory, data_i, minicam_hit_slv, active) begin
    comp_loop : for m in 0 to (CAM_DEPTH-1) loop
        if (cam_memory(m) = data_i and active(m) = '1') then
            minicam_hit_slv(m) <= '1';
        else
            minicam_hit_slv(m) <= '0';
        end if;
    end loop;
    
    minicam_hit <= or_reduce (minicam_hit_slv);

end process;

cam_proc: process(clk_i) begin
    if rising_edge(clk_i) then
        if (rst_i = '1') then
            ctr_ptr_wr_o    <= '0';
            ctr_ptr_o       <= (others => '0');
            minicam_err_o   <= '0';
            ctr_ptr_l       <= 0;
            debug_code      <= 0;

            for i in 0 to (CAM_DEPTH-1) loop
                cam_memory(i) <= (others => '0');
                ctr_ptr(i)    <= (others => '0');
                active(i)     <= '0';
            end loop;
        else
            ctr_ptr_wr_o    <= '0';
            ctr_ptr_o       <= (others => '0');
            minicam_err_o   <= '0';

            if (data_valid_i = '1') then
                search_loop : for j in 0 to (CAM_DEPTH-1) loop
                    if (minicam_hit = '0') then
                        if ((valid(j) = '1') and (active(j) = '0') and tlast_i = '0') then  -- no hit, empty location found, store data here
                            cam_memory(j) <= data_i;
                            ctr_ptr(j)    <= minibuf_rdata + '1';
                            ctr_ptr_o     <= minibuf_rdata;
                            ctr_ptr_l     <= j;
                            ctr_ptr_wr_o  <= '1';
                            active(j)     <= '1';
                            debug_code    <= 1;
                            exit search_loop when ((valid(j) = '1') and (active(j) = '0')); -- same as if condition      
                        elsif ((valid(j) = '1') and (active(j) = '0') and tlast_i = '1') then  -- no hit, empty location found, single-event packet
                            cam_memory(j) <= ZEROS & minibuf_rdata;
                            ctr_ptr(j)    <= (others => '0');  -- initialize with pointer to free minibuffer
                            ctr_ptr_o     <= minibuf_rdata;
                            ctr_ptr_l     <= j;
                            ctr_ptr_wr_o  <= '1';
                            active(j)     <= '0';
                            debug_code    <= 2;
                            exit search_loop when ((cam_memory(j) = data_i) and (active(j) = '1') and (valid(j) = '1') and (tlast_i = '1')); -- same as if condition
                        end if;                   
                    elsif ((minicam_hit = '1') and (active(j) = '1') and (valid(j) = '1') and (tlast_i = '1')) then -- hit on active/valid location, last event of packet
                        cam_memory(j)     <= (others => '0');
                        ctr_ptr(j)        <= (others => '0');  -- initialize with pointer to free minibuffer
                        ctr_ptr_o         <= ctr_ptr(j);
                        ctr_ptr_wr_o      <= '1';
                        active(j)         <= '0';
                        debug_code        <= 3;
                        exit search_loop when ((cam_memory(j) = data_i) and (active(j) = '1') and (valid(j) = '1') and (tlast_i = '1')); -- same as if condition
                    elsif ((minicam_hit = '1') and (active(j) = '1') and (valid(j) = '1')) then  -- hit on valid location, not the last event of packet
                        if (cam_memory(j) = data_i) then
                            cam_memory(j) <= cam_memory(j);
                            ctr_ptr(j)    <= ctr_ptr(j) + '1';
                            ctr_ptr_o     <= ctr_ptr(j);
                            ctr_ptr_wr_o  <= '1';
                            active(j)     <= active(j);
                            debug_code    <= 4;
                            exit search_loop;
                        else
                            cam_memory(j) <= cam_memory(j);
                            ctr_ptr(j)    <= ctr_ptr(j);
                            ctr_ptr_o     <= ctr_ptr(j);
                            ctr_ptr_wr_o  <= '1';
                            active(j)     <= active(j);
                            debug_code    <= 5;
                        end if;
                    else
                        debug_code <= 6;
                    end if;

                end loop search_loop;
            end if;
        end if;
    end if;
end process;

----------------------------------------------------------------------------------------------
-- State machine for minicam VALID bit and ctr_ptr management
-- this state machine controls the valid bits. a VALID bit is deasserted at the same time its corresonding active is deasserted.
-- VALID is asserted AND ctr_ptr is updated at initilization when a ctr_ptr is pulled from the minibuf_fifo
-- VALID is deasserted after its ACTIVE bit is high, and TLAST arrives
-- VALID is asserted during normal operation when it becomes deasserted (under the same conditions as ACTIVE), minibuf_fe = 0, this state 
-- machine reads a new value from minibuf_fifo, and it is stored in the corresponding ctr_ptr location
----------------------------------------------------------------------------------------------
vcpsm_reg_proc: process(clk_i) begin
    if rising_edge(clk_i) then
        if (rst_i = '1') then
            minibuf_rd_q   <= '0';
            minibuf_ctr_ns <= 0;
            valid_ctrptr_ns   <= VCPSM_IDLE;
        else
            minibuf_rd_q   <= minibuf_rd;
            minibuf_ctr_ns <= minibuf_ctr_cs;
            valid_ctrptr_ns   <= valid_ctrptr_cs;
        end if;
    end if;
end process;

vcpsm_proc : process(valid_ctrptr_ns, minibuf_rdy, minibuf_ctr_ns, valid, active, minibuf_fe)
begin
    case valid_ctrptr_ns is                                        
        when VCPSM_IDLE =>
            minibuf_ctr_cs        <= 0;
            if (minibuf_rdy = '1') then
                valid_ctrptr_cs    <= VCPSM_INIT;
            else
                valid_ctrptr_cs    <= VCPSM_IDLE;
            end if;

        when VCPSM_INIT =>  -- initialize the valid bits and ctr_ptrs in the minicam
            if (minibuf_ctr_ns < (CAM_DEPTH-1)) then
                minibuf_ctr_cs    <= minibuf_ctr_ns + 1;
                valid_ctrptr_cs   <= VCPSM_INIT;
            else
                minibuf_ctr_cs    <= 0;
                valid_ctrptr_cs   <= VCPSM_NORMAL_OP;
            end if;

        when VCPSM_NORMAL_OP =>
            minibuf_rd_loop: for jj in 0 to (CAM_DEPTH-1) loop
                if (valid(jj) = '0' and active(jj) = '0' and minibuf_fe = '0') then -- populate minicam with ctr_ptr, assert valid
                    exit minibuf_rd_loop when (valid(jj) = '0' and active(jj) = '0' and minibuf_fe = '0'); -- same as if condition
                end if;
            end loop;    
            valid_ctrptr_cs    <= VCPSM_NORMAL_OP;

    when others => 
        valid_ctrptr_cs <= VCPSM_IDLE;
    
    end case;
end process;

--minibuf_rd <= tlast_i and data_valid_i;
minibuf_rd <= not minicam_hit and data_valid_i;

ctrptr_proc: process(clk_i) begin
    if rising_edge(clk_i) then
        if (rst_i = '1') then
            for i in 0 to (CAM_DEPTH-1) loop
                ctr_ptr_start(i) <=  (others => '0');
                valid(i)         <= '0';
            end loop;
        else
            if (valid_ctrptr_ns = VCPSM_INIT) then  -- assert valid and load ctr_ptr during initialization
                valid(minibuf_ctr_ns)         <= '1';
                ctr_ptr_start(minibuf_ctr_ns) <= minibuf_rdata;
            elsif (valid_ctrptr_cs = VCPSM_NORMAL_OP) then
                if (minibuf_rd_q = '1') then
                    valid(ctr_ptr_l) <= '1';
                    ctr_ptr_start(ctr_ptr_l) <= minibuf_rdata;
                end if;
            end if;
        end if;
    end if;
end process;

----------------------------------------------------------------------------------------------
-- available location check - this logic checks if ANY minicam location is availble, which is defined
-- by (active = '0' and valid = '1')
----------------------------------------------------------------------------------------------
available_gen : for kk in 0 to 7 generate
    available(kk) <= '1' when ((valid(kk) = '1') and (active(kk) = '0')) else '0';
end generate; 

available_ctrptr   <= or_reduce (available); -- there is at least one availble (i.e. valid but not active) ctr_ptr
available_ctrptr_o <= available_ctrptr; -- there is at least one availble (i.e. valid but not active) ctr_ptr

----------------------------------------------------------------------------------------------
-- Output assignments
----------------------------------------------------------------------------------------------
minicam_full_o     <= not available_ctrptr; -- error condition, indicates that there is no empty CAM location available
minibuf_fe_o       <= minibuf_fe;

----------------------------------------------------------------------------------------------
end minicam;
