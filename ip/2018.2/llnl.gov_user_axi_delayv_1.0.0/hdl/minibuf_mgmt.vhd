--**********************************************************************************************************
-- Lawrence Livermore National Labs
-- 20191213 CM Initial creation 
-- minibuf_mgmt.vhd:  This module implements the minibuffer management function. It manages assignment of
--                    minibuffer pointers.
--                    The Packet Buffer is comprised of n minibuffers, each minibuffer shall store one packet,
--                    and is sized to fit the largest possible packet.
--                    At initialization, it will store all the empty minibuffer cntr_ptr values not pre-assigned
--                    within the minicam at init. When a minicam location is retired (i.e. it becomes invalid), its
--                    corresponding cntr_ptr is freed up, and is stored in the minibuf_fifo.
--**********************************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;

library axi_delay_lib;
use axi_delay_lib.all;
use work.axi_delay_pkg.all;

entity minibuf_mgmt is

generic (
    CAM_DEPTH           : integer := 8; -- depth of cam (i.e. number of entried), must be modulo 2
    CTR_PTR_WIDTH       : integer := 5; -- width of counter/pointer, which is the index to the Packet Buffer (start of mini-buffer)
    NUM_EVENTS_PER_MBUF : integer := 8; -- maximum number of events each minibuffer can hold
    NUM_MINI_BUFS       : integer := 32 -- number of minibufs; each must be sized to hold the largest packet size supported
);
port (
    clk_i               : in  std_logic;
    rst_i               : in  std_logic;

    minibuf_wr_i        : in  std_logic; -- write enable for minibuf FIFO
    minibuf_rd_i        : in  std_logic; -- read enable for minibuf FIFO
    minibuf_af_o        : out std_logic; -- almost full for minibuf FIFO
    minibuf_ae_o        : out std_logic; -- almost empty for minibuf FIFO
    minibuf_fe_o        : out std_logic; -- empty flag for minibuf FIFO
    minibuf_rdy_o       : out std_logic; -- when '1', indicates that minibuf FIFO has been initialized and is ready for operation
    minibuf_valid_o     : out std_logic;
    minibuf_wdata_i     : in  std_logic_vector(CTR_PTR_WIDTH-1 downto 0); -- free minibuffer to add to minibuf_fifo
    minibuf_rdata_o     : out std_logic_vector(CTR_PTR_WIDTH-1 downto 0) -- fresh (unused) minibuffer, ready for use
);
end minibuf_mgmt;

architecture minibuf_mgmt of minibuf_mgmt is

--******************************************************************************
-- Constants
--******************************************************************************
constant C_ZERO : std_logic_vector(15 downto 0) := (others => '0'); -- create std_logic_vector for FIFO i/p leading zeros

--******************************************************************************
-- Components
--******************************************************************************

--******************************************************************************
--Signal Definitions
--******************************************************************************
signal minibuf_init      : std_logic; -- it takes 2 or 3 clocks for ff/af flags to deassert after reset

signal minibuf_ff        : std_logic;
signal minibuf_init_wren : std_logic;
signal minibuf_wr        : std_logic;
signal minibuf_wdata     : std_logic_vector(CTR_PTR_WIDTH-1 downto 0);
signal minibuf_wdata_ext : std_logic_vector(15 downto 0);
signal minibuf_rd_init   : std_logic; -- first read after initialization; ensures that rdata is available immediately
signal minibuf_rd_init_q : std_logic; -- first read after initialization; ensures that rdata is available immediately
signal minibuf_fe        : std_logic;
signal minibuf_rd        : std_logic;
signal minibuf_rdata     : std_logic_vector(15 downto 0);

signal ctr_ptr_init      : integer;
signal ctr_ptr_init_sl2  : std_logic_vector(CTR_PTR_WIDTH-1 downto 0);
constant ISM_IDLE        : std_logic_vector(1 downto 0) := "00";
constant ISM_INIT        : std_logic_vector(1 downto 0) := "01";
constant ISM_HOLD        : std_logic_vector(1 downto 0) := "10";
signal initfifo_state    : std_logic_vector(1 downto 0) := "00";

--******************************************************************************
-- Connectivity and Logic
--******************************************************************************

begin

minibuf_init <= minibuf_fe and not minibuf_ff;

---------------------------------------
-- Minibuffer Management FIFO Initialization State Machine
-- This state machine will initialize the minibuf FIFO with valid cntr_ptr values. Note that it starts its 
-- initialization at n = CAM_DEPTH. This is because the minicam self-initializes the pointers in all of its
-- locations (and there are CAM_DEPTH locations).
---------------------------------------
wfifo_sm_proc : process (clk_i) begin
    if rising_edge(clk_i) then  
        if (rst_i = '1') then
            ctr_ptr_init      <= 0;
            minibuf_init_wren <= '0';
            minibuf_rdy_o     <= '0';
            minibuf_rd_init   <= '0';
            minibuf_rd_init_q <= '0';
            initfifo_state    <= ISM_IDLE;   
        else                              
            minibuf_rdy_o     <= '0';   
            minibuf_rd_init   <= '0';   
            minibuf_rd_init_q <= minibuf_rd_init;   

            case initfifo_state is                                        
                when ISM_IDLE =>
                    if (minibuf_init = '1') then
                        ctr_ptr_init      <= 0; -- initialize ctr_ptr_init with the value following last minicam init value
                        minibuf_init_wren <= '1';
                        initfifo_state    <= ISM_INIT;
                    end if;
                
                when ISM_INIT =>
                    if (ctr_ptr_init >= (NUM_MINI_BUFS-1)) then
                        ctr_ptr_init      <= CAM_DEPTH;
                        minibuf_init_wren <= '0';
                        minibuf_rd_init   <= '1';
                        initfifo_state    <= ISM_HOLD;
                    else
                        ctr_ptr_init      <= ctr_ptr_init + 1;
                        minibuf_init_wren <= '1';
                        initfifo_state    <= ISM_INIT;
                    end if;
                
                when ISM_HOLD =>
                    ctr_ptr_init      <= CAM_DEPTH;
                    minibuf_init_wren <= '0';
                    minibuf_rdy_o     <= '1';
                    initfifo_state    <= ISM_HOLD;
                
                when others => 
                    initfifo_state <= ISM_IDLE;
                   
            end case;
        end if;
    end if;
end process;

ctr_ptr_init_sl2 <= std_logic_vector(shift_left(to_unsigned(ctr_ptr_init,CTR_PTR_WIDTH),log2rp(NUM_EVENTS_PER_MBUF)));

minibuf_wr    <= minibuf_init_wren or minibuf_wr_i;
minibuf_wdata <= ctr_ptr_init_sl2 when (minibuf_init_wren = '1') else minibuf_wdata_i;
--minibuf_wdata <= std_logic_vector(to_unsigned(ctr_ptr_init, minibuf_wdata'length)) when (minibuf_init_wren = '1') else minibuf_wdata_i;

-- minibuf_fifo stores valid ctr_ptr values.
-- Initializing the minibuf_fifo: This is done via the initfifo_state state machine. After initialization, the initfifo_state
-- process becomes inactive.
-- Storing freed ctr_ptr into the minibuf_fifo:  When a packet is read from the packet buffer in its entirety and leaves
-- the channel_delay block, the corresonding ctr_ptr is freed and is written back into the minibuf_fifo.
-- Reading a ctr_ptr from the minibuf_fifo:  When a minicam location's ACTIVE bit is '0' and VALID bit is '0', a new ctr_ptr 
-- is read from the minibuf_fifo and stored in the minicam, and the minicam's VALID bit is set to '1'.

--minibuf_wdata_ext <= C_ZERO(15 downto CTR_PTR_WIDTH) & std_logic_vector(shift_left(unsigned(minibuf_wdata),2));
minibuf_wdata_ext <= C_ZERO(15 downto CTR_PTR_WIDTH) & minibuf_wdata;
--minibuf_rd        <= minibuf_rd_i;
minibuf_rd        <= minibuf_rd_init or minibuf_rd_init_q or minibuf_rd_i;

minibuf_fifo : entity fifo_sync
    GENERIC MAP (
        C_DEPTH      => NUM_EVENTS_PER_MBUF * NUM_MINI_BUFS,
        C_DIN_WIDTH  => 16, --CTR_PTR_WIDTH,
        C_DOUT_WIDTH => 16, --CTR_PTR_WIDTH,
        C_THRESH     => 4
    )
    PORT MAP (
        wr_clk      => clk_i,
        rst         => rst_i,
        din         => minibuf_wdata_ext, --minibuf_wdata,
        prog_full   => minibuf_af_o,
        full        => minibuf_ff,
        wr_en       => minibuf_wr,

        dout        => minibuf_rdata, --minibuf_rdata_o,
        prog_empty  => minibuf_ae_o,
        empty       => minibuf_fe,
        valid       => minibuf_valid_o,
        rd_en       => minibuf_rd
    );

minibuf_rdata_o <= minibuf_rdata(CTR_PTR_WIDTH-1 downto 0);

----------------------------------------------------------------------------------------------
-- Output assignments
----------------------------------------------------------------------------------------------
minibuf_fe_o <= minibuf_fe;

----------------------------------------------------------------------------------------------
end minibuf_mgmt;
