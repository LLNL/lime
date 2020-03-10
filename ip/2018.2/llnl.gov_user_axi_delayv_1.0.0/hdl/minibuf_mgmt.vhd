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
--use work.axi_delay_pkg.all;

entity minibuf_mgmt is

generic (
    CAM_DEPTH       : integer := 8;   -- depth of cam (i.e. number of entried), must be modulo 2
    CTR_PTR_WIDTH   : integer := 5;   -- width of counter/pointer, which is the index to the Packet Buffer (start of mini-buffer)
    NUM_MINI_BUFS   : integer := 32   -- number of minibufs; each must be sized to hold the largest packet size supported
);
port (
    clk_i               : in  std_logic;
    rst_i               : in  std_logic;

    minibuf_wr_i        : in  std_logic; -- write enable for minibuf FIFO
    minibuf_rd_i        : in  std_logic; -- read enable for minibuf FIFO
    minibuf_af_o        : out std_logic; -- almost fuill for minibuf FIFO
    minibuf_fe_o        : out std_logic; -- empty flag for minibuf FIFO
    minibuf_rdy_o       : out std_logic; -- when '1', indicates that minibuf FIFO has been initialized and is ready for operation
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
COMPONENT fifo_512x16_1clk
  PORT (
    clk         : IN STD_LOGIC;
    srst        : IN STD_LOGIC;
    din         : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    wr_en       : IN STD_LOGIC;
    rd_en       : IN STD_LOGIC;
    dout        : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    full        : OUT STD_LOGIC;
    empty       : OUT STD_LOGIC;
    prog_full   : OUT STD_LOGIC;
    prog_empty  : OUT STD_LOGIC;
    wr_rst_busy : OUT STD_LOGIC;
    rd_rst_busy : OUT STD_LOGIC
  );
END COMPONENT;

--******************************************************************************
--Signal Definitions
--******************************************************************************

--signal valid             : std_logic_vector((CAM_DEPTH-1) downto 0);
--signal present           : std_logic;  -- indicates that the incoming data_i is present in the CAM
--signal minibuf_rden      : std_logic;
signal minibuf_rdata     : std_logic_vector(15 downto 0);
signal minibuf_ff        : std_logic;
signal minibuf_init_wren : std_logic;
signal minibuf_wr        : std_logic;
signal minibuf_wdata     : std_logic_vector(CTR_PTR_WIDTH-1 downto 0);
signal minibuf_wdata_ext : std_logic_vector(15 downto 0);
signal minibuf_rd_init   : std_logic; -- first read after initialization; ensures that rdata is available immediately
signal minibuf_rd        : std_logic;

signal ctr_ptr_init      : integer;
constant ISM_IDLE        : std_logic_vector(1 downto 0) := "00";
constant ISM_INIT        : std_logic_vector(1 downto 0) := "01";
constant ISM_HOLD        : std_logic_vector(1 downto 0) := "10";
signal initfifo_state    : std_logic_vector(1 downto 0) := "00";

--******************************************************************************
-- Connectivity and Logic
--******************************************************************************

begin

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
            initfifo_state    <= ISM_IDLE;   
        else                              
            minibuf_rdy_o     <= '0';   
            minibuf_rd_init   <= '0';   

            case initfifo_state is                                        
                when ISM_IDLE =>
                    ctr_ptr_init      <= 0; -- initialize ctr_ptr_init with the value following last minicam init value
                    minibuf_init_wren <= '1';
                    initfifo_state    <= ISM_INIT;
                
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

minibuf_wr    <= minibuf_init_wren or minibuf_wr_i;
minibuf_wdata <= std_logic_vector(to_unsigned(ctr_ptr_init, minibuf_wdata'length)) when (minibuf_init_wren = '1') else minibuf_wdata_i;

-- minibuf_fifo stores valid ctr_ptr values. It is a first-word fall-through FIFO, i.e. data is available prior to rd_en asserted, and assertion
-- of rd_en will result in the NEXT data location presented after the clock edge.

-- Initializing the minibuf_fifo: This is done via the initfifo_state state machine. After initialization, the initfifo_state
-- process becomes inactive.
-- Storing freed ctr_ptr into the minibuf_fifo:  When a packet is read from the packet buffer in its entirety and leaves
-- the channel_delay block, the corresonding ctr_ptr is freed and is written back into the minibuf_fifo.
-- Reading a ctr_ptr from the minibuf_fifo:  When a minicam location's ACTIVE bit is '0' and VALID bit is '0', a new ctr_ptr 
-- is read from the minibuf_fifo and stored in the minicam, and the minicam's VALID bit is set to '1'.

minibuf_wdata_ext <= C_ZERO(15 downto CTR_PTR_WIDTH) & std_logic_vector(shift_left(unsigned(minibuf_wdata),2));
minibuf_rd        <= minibuf_rd_init or minibuf_rd_i;

minibuf_fifo : fifo_512x16_1clk
    PORT MAP (
      clk         => clk_i,
      srst        => rst_i,
      din         => minibuf_wdata_ext,
      prog_full   => minibuf_af_o,
      full        => minibuf_ff,
      wr_en       => minibuf_wr,

      dout        => minibuf_rdata,
      prog_empty  => OPEN,
      empty       => minibuf_fe_o,
      rd_en       => minibuf_rd,

      wr_rst_busy => OPEN,
      rd_rst_busy => OPEN
    );

minibuf_rdata_o <= minibuf_rdata(CTR_PTR_WIDTH-1 downto 0);

----------------------------------------------------------------------------------------------
-- Output assignments
----------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------
end minibuf_mgmt;
