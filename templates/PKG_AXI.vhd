-------------------------------------------------------------------------------
--          ____  _____________  __                                          --
--         / __ \/ ____/ ___/\ \/ /                 _   _   _                --
--        / / / / __/  \__ \  \  /                 / \ / \ / \               --
--       / /_/ / /___ ___/ /  / /               = ( M | S | K )=             --
--      /_____/_____//____/  /_/                   \_/ \_/ \_/               --
--                                                                           --
-------------------------------------------------------------------------------
-- $Header$
-------------------------------------------------------------------------------
--! @file   PKG_AXI.vhd
--! @brief  AXI4 Interface Package, definition of AXI4 data types
--! @author Holger Kay
--! @mail   holger.kay@desy.de
--! $Date$
--! $Revision$
--! $URL$
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_MISC.all;
use IEEE.NUMERIC_STD.all;


package PKG_AXI is

  ---------------------------------------------------------------------------
  -- AXI Stream Interface
  type T_AXIS_M2S is record
    TVALID    : std_logic;
    TDATA     : std_logic_vector(127 downto 0);
    TSTRB     : std_logic_vector(15 downto 0);
    TKEEP     : std_logic_vector(15 downto 0);
    TLAST     : std_logic;
    TID       : std_logic_vector(7 downto 0);
    TDEST     : std_logic_vector(3 downto 0);
    TUSER     : std_logic_vector(127 downto 0);
    -- control signals
    ACLK      : std_logic;
    ARESET_N  : std_logic;
  end record T_AXIS_M2S;

  type T_AXIS_S2M is record
    TREADY    : std_logic;
    -- control signals
    ACLK      : std_logic;
    ARESET_N  : std_logic;
  end record T_AXIS_S2M;

  type T_AXIS_M2S_ARRAY is array (natural range<>) of T_AXIS_M2S;
  type T_AXIS_S2M_ARRAY is array (natural range<>) of T_AXIS_S2M;

  constant  C_AXIS_M2S_DEFAULT : T_AXIS_M2S := (       
    TVALID    => '0',
    TDATA     => (others => '0'),
    TSTRB     => (others => '0'),
    TKEEP     => (others => '0'),
    TLAST     => '0',
    TID       => (others => '0'),
    TDEST     => (others => '0'),
    TUSER     => (others => '0'),
    ACLK      => '0',
    ARESET_N  => '0' 
  );
  constant  C_AXIS_S2M_DEFAULT : T_AXIS_S2M := (        
    TREADY    => '0',
    ACLK      => '0',
    ARESET_N  => '0' 
  );

  ---------------------------------------------------------------------------
  -- AXI4 memory mapped interface
  type T_AXI4_M2S is record
    -- Write Address Channel signals---------------------------------------------
    AWID        : std_logic_vector(15 downto 0);  -- Write Address ID
    AWADDR      : std_logic_vector(31 downto 0);  -- Write Address
    AWLEN       : std_logic_vector(7 downto 0);   -- Burst Length 
    AWSIZE      : std_logic_vector(2 downto 0);   -- Burst Size
    AWBURST     : std_logic_vector(1 downto 0);   -- Burst Type
    --AWCACHE   : std_logic_vector(3 downto 0);   -- Memory Type (Not Needed)
    --AWPROT    : std_logic_vector(2 downto 0);   -- Protection type (Not Needed)
    --AWQOS     : std_logic_vector(3 downto 0);   -- Quality of Service (Not Needed)
    --AWREGION  : std_logic_vector(3 downto 0);   -- Region Identifer
    -- AWUSER   : std_logic_vector(3 downto 0);   -- User Signal (Not Needed)
    AWVALID     : std_logic;                      -- Write Address Valid
    
    -- Write Data channel signals---------------------------------------------
    WID         : std_logic_vector(15 downto 0);  -- Write ID Tag
    WDATA       : std_logic_vector(1023 downto 0);-- Write Data
    WSTRB       : std_logic_vector(127 downto 0); -- Write Strobe
    WLAST       : std_logic;                      -- Write Last 
    --WUSER     : std_logic;                      -- (Not Needed)
    WVALID      : std_logic;                      -- Write Valid
    
    -- Write Response Channel Signals 
    BREADY      : std_logic;                      -- Response Ready            
    
    -- Read Address Channel Signals ---------------------------------------------
    ARID        : std_logic_vector(15 downto 0);  -- Read Address ID     
    ARADDR      : std_logic_vector(31 downto 0);  -- Read Address
    ARLEN       : std_logic_vector(7 downto 0);   -- Burst Length 
    ARSIZE      : std_logic_vector(2 downto 0);   -- Burst Size
    ARBURST     : std_logic_vector(1 downto 0);   -- Burst Type
    --ARLOCK    : std_logic_vector(1 downto 0);   -- Lock Type (Not supported in AXI.4)
    --ARCACHE   : std_logic_vector(3 downto 0);   -- Memory Type (Not needed)
    --ARPROT    : std_logic_vector(2 downto 0);   -- Protection Type (Not needed)
    --ARQOS     : std_logic_vector(3 downto 0);   -- Quality of Service (Not Needed)
    --ARREGION  : std_logic_vector(3 downto 0);   -- Region Identifer (Not Needed)
    --AWUSER    : std_logic_vector(3 downto 0);   -- User Signal (Not Needed)
    ARVALID     : std_logic;                      -- Read Address Valid
    ARREADY     : std_logic;
    -- Read Data Channel Signals---------------------------------------------
    RREADY      : std_logic;                      -- Read Ready
    
    -- Global signals---------------------------------------------
    ACLK        : std_logic;
    ARESET_N    : std_logic;
  end record T_AXI4_M2S;

  type T_AXI4_S2M is record

    -- Write Address Channel Signals---------------------------------------------
    AWREADY     : std_logic;                      -- Write Address Ready
    
    -- Write Data Channel Signals---------------------------------------------
    WREADY      : std_logic;                      -- Write Ready
    
    -- Write Response Channel Signals ---------------------------------------------
    BID         : std_logic_vector(15 downto 0);  -- Response ID Tag
    BRESP       : std_logic_vector(1 downto 0);
    --BUSER       : std_logic; -- Not recommeded to use this port 
    BVALID      : std_logic;
    
    -- Read Address Channel Signals---------------------------------------------
    ARREADY     : std_logic;                      -- Read Address ready
    
    -- Read Data Channel Signals---------------------------------------------
    RID         : std_logic_vector(15 downto 0);  -- Read ID Tag
    RDATA       : std_logic_vector(1023 downto 0);-- Read Data
    RRESP       : std_logic_vector(1 downto 0);   -- Read Response
    RLAST       : std_logic;                      -- Read Last 
    --RUSER    : std_logic_vector(3 downto 0);    -- User Signal (Not Needed)
    RVALID      : std_logic;                      -- Read Valid
           
    -- Global signals---------------------------------------------
    ACLK        : std_logic;
    ARESET_N    : std_logic;
      
  end record T_AXI4_S2M;


  type T_AXI4_M2S_ARRAY is array (natural range<>) of T_AXI4_M2S;
  type T_AXI4_S2M_ARRAY is array (natural range<>) of T_AXI4_S2M;

  constant  C_AXI4_S2M_DEFAULT : T_AXI4_S2M := (       
    AWREADY     => '0' ,
    WREADY      => '0' ,
    BID         => (others => '0') ,
    BVALID      => '0' ,
    BRESP       => (others => '0') ,
    ARREADY     => '0' ,
    RID         => (others => '0') ,
    RDATA       => (others => '0') ,
    RLAST       => '0' ,
    RVALID      => '0' ,
    RRESP       => (others => '0') ,
    ACLK        => '0' ,
    ARESET_N    => '0' 
  );
  constant  C_AXI4_M2S_DEFAULT : T_AXI4_M2S := (  
    AWID          => (others => '0'),
    AWADDR        => (others => '0'),
    AWLEN         => (others => '0'),
    AWSIZE        => (others => '0'), 
    AWBURST       => "01", -- INCR (AXI.4 Specs tells this)
    --AWCACHE     => (others => '0'), 
    --AWPROT      => (others => '0'), 
    --AWQOS       => (others => '0'), 
    --AWREGION    => (others => '0'),
    -- AWUSER     => (others => '0'), 
    AWVALID       => '0',  
    WID           => (others => '0'), 
    WDATA         => (others => '0'), 
    WSTRB         => (others => '0'), 
    WLAST         => '0', 
    --WUSER       => (others => '0'), 
    WVALID        => '0',  
    BREADY        => '0',
    ARID          => (others => '0'), 
    ARADDR        => (others => '0'), 
    ARLEN         => (others => '0'), 
    ARSIZE        => (others => '0'), 
    ARBURST       => (others => '0'), 
    --ARLOCK      => (others => '0'), 
    --ARCACHE     => (others => '0'), 
    --ARPROT      => (others => '0'), 
    --ARQOS       => (others => '0'), 
    --ARREGION    => (others => '0'),
    --AWUSER      => (others => '0'), 
    ARVALID       => '0',   
    ARREADY       => '0', 
    RREADY        => '0', 
    ACLK          => '0', 
    ARESET_N      => '0'  
  );


  -- Burst type (AWBURST, ARBURST)
  constant AXI4_BURST_FIXED   : std_logic_vector(1 downto 0) := "00"; -- same address for every transfer in the burst
  constant AXI4_BURST_INCR    : std_logic_vector(1 downto 0) := "01"; -- increment address for next transfer
  constant AXI4_BURST_WRAP    : std_logic_vector(1 downto 0) := "10"; -- incrementing burst, wraps around to a lower address if an upper address limit is reached.


  -- Read and write response structure (BRESP, RRESP)
  constant AXI4_RESP_OKAY     : std_logic_vector(1 downto 0) := "00"; -- Normal access success
  constant AXI4_RESP_EXOKAY   : std_logic_vector(1 downto 0) := "01"; -- Exclusive access okay
  constant AXI4_RESP_SLVERR   : std_logic_vector(1 downto 0) := "10"; -- Slave error
  constant AXI4_RESP_DECERR   : std_logic_vector(1 downto 0) := "11"; -- Decode error

  end PKG_AXI;


  package body PKG_AXI is

    -- Combine separated AXI4 Read- and Write channel signals to one T_AXI4_M2S signal.
    -- For ACLK and ARESET_N it must be selected if the Read or Write channel has to be used.
    function AXI4_M2S_COMBINE(P_I_READ : T_AXI4_M2S; P_I_WRITE : T_AXI4_M2S; G_RST_CLK_SELECT : natural)  return T_AXI4_M2S is
      variable P_O_READ_WRITE : T_AXI4_M2S;
    begin
      -- write channel signals
      P_O_READ_WRITE.AWID      :=  P_I_WRITE.AWID;
      P_O_READ_WRITE.AWADDR    :=  P_I_WRITE.AWADDR;
      P_O_READ_WRITE.AWLEN     :=  P_I_WRITE.AWLEN;
      P_O_READ_WRITE.AWSIZE    :=  P_I_WRITE.AWSIZE;
      P_O_READ_WRITE.AWBURST   :=  P_I_WRITE.AWBURST;
      P_O_READ_WRITE.AWVALID   :=  P_I_WRITE.AWVALID;
      P_O_READ_WRITE.WDATA     :=  P_I_WRITE.WDATA;
      P_O_READ_WRITE.WSTRB     :=  P_I_WRITE.WSTRB;
      P_O_READ_WRITE.WLAST     :=  P_I_WRITE.WLAST;
      P_O_READ_WRITE.WVALID    :=  P_I_WRITE.WVALID;
      P_O_READ_WRITE.BREADY    :=  P_I_WRITE.BREADY;
      -- read channel signals
      P_O_READ_WRITE.ARID      :=  P_I_READ.ARID;
      P_O_READ_WRITE.ARADDR    :=  P_I_READ.ARADDR;
      P_O_READ_WRITE.ARLEN     :=  P_I_READ.ARLEN;
      P_O_READ_WRITE.ARSIZE    :=  P_I_READ.ARSIZE;
      P_O_READ_WRITE.ARBURST   :=  P_I_READ.ARBURST;
      P_O_READ_WRITE.ARVALID   :=  P_I_READ.ARVALID;
      P_O_READ_WRITE.RREADY    :=  P_I_READ.RREADY;
      -- control signals
      if (G_RST_CLK_SELECT = 0) then
        P_O_READ_WRITE.ARESET_N  :=  P_I_READ.ARESET_N;
        P_O_READ_WRITE.ACLK      :=  P_I_READ.ACLK;
      else
        P_O_READ_WRITE.ARESET_N  :=  P_I_WRITE.ARESET_N;
        P_O_READ_WRITE.ACLK      :=  P_I_WRITE.ACLK;
      end if;
      
      return P_O_READ_WRITE;
    end function;

end PKG_AXI;
