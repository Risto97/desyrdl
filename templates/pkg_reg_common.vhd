-- Copyright (c) 2020-2021 Deutsches Elektronen-Synchrotron DESY.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pkg_reg_common is

  ---------------------------------------------------------------------------
  -- common type definitions
  type T_4BitArray  is array (natural range<>) of std_logic_vector( 3 downto 0) ;
  type T_32BitArray is array (natural range<>) of std_logic_vector(31 downto 0) ;
  type T_IntegerArray  is array (natural range<>) of integer ;

  ---------------------------------------------------------------------------
  -- AXI4 memory mapped interface
  type t_axi4_m2s is record
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

  end record t_axi4_s2m;

  type t_axi4_m2s_array is array (natural range<>) of t_axi4_m2s;
  type t_axi4_s2m_array is array (natural range<>) of t_axi4_s2m;

  constant  C_AXI4_S2M_DEFAULT : t_axi4_s2m := (
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
  constant  C_AXI4_M2S_DEFAULT : t_axi4_m2s := (
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


  ---------------------------------------------------------------------------
  -- Interface definitions for IBUS
  -- Internal BUS (IBUS) is the internal bus used in the applications of MSK Firmware
  -- repository.

  -- Output signals of IBUS. Through this record the application send data/commands to the bus
  type t_ibus_m2s is record
    ADDR   : std_logic_vector(31 downto 0);
    DATA   : std_logic_vector(31 downto 0);
    RENA   : std_logic;
    WENA   : std_logic;
    CLK    : std_logic;
  end record t_ibus_m2s;

  -- Output signals of IBUS. Through this record the application send data/commands to the bus
  type t_ibus_s2m is record
    CLK    : std_logic;
    DATA   : std_logic_vector(31 downto 0);
    RACK   : std_logic;
    WACK   : std_logic;
  end record t_ibus_s2m;

  -- Array of IBUS outputs
  type t_ibus_m2s_array is array (natural range<>) of t_ibus_m2s;

  -- Array of IBUS inputs
  type t_ibus_s2m_array is array (natural range<>) of t_ibus_s2m;

  -- Default IBUS connections for the output (All entries equals 0)
  constant C_IBUS_M2S_DEFAULT : t_ibus_m2s := (
    ADDR => (others => '0'),
    DATA => (others => '0'),
    RENA => '0',
    WENA => '0',
    CLK  => '0');

  -- Default IBUS connections for the input (All entries equals 0)
  constant C_IBUS_S2M_DEFAULT : t_ibus_s2m := (
    CLK  => '0',
    DATA => (others => '0'),
    RACK => '0',
    WACK => '0');


  ---------------------------------------------------------------------------
  -- SystemRDL-specific definitions

  --type t_field_access is (R, W, RW, NA);
  subtype t_field_access is integer;
  constant C_RW  : integer := 2;
  constant C_RW1 : integer := 5;
  constant C_R   : integer := 3;
  constant C_W   : integer := 4;
  constant C_W1  : integer := 6;
  constant C_NA  : integer := 1;

  type t_field_type is (STORAGE, WIRE, COUNTER, INTERRUPT);

  type t_field_info is record
    ftype : t_field_type;
    len   : integer;
    upper : integer;
    lower : integer;
    hw_we : boolean;
    sw_access : t_field_access;
    hw_access : t_field_access;
    def_val : std_logic_vector(32-1 downto 0);
    incrwidth : integer;
    decrwidth : integer;
  end record;
  type t_field_info_arr is array (integer range 31 downto 0) of t_field_info;
  constant C_FIELD_NONE : t_field_info := (WIRE, 0, 0, 0, false, C_NA, C_NA, (others => '0'), 0, 0);

  type t_reg_info is record
    addr    : integer;
    base    : integer;
    fields  : t_field_info_arr;
    N       : positive;
    M       : positive;
  end record;
  constant C_REG_NONE : t_reg_info := (0, 0, (others => C_FIELD_NONE), 1, 1);

  -- Maybe better to constrain t_reg_info_array. Vivado shows weird indices when unconstrained.
  -- Must be the number of distinct register names, not one for each 2D/3D array element!
  --type t_reg_info_array is array (0 to C_REGNAMES) of t_reg_info;
  type t_reg_info_array is array (natural range <>) of t_reg_info;


  -- We can't have VHDL-2008 at the moment but maybe at some point we will
--  type t_field_signals_in is record
--    data : std_logic_vector; -- VHDL-2008
--    we : std_logic;
--    incr : std_logic;
--    decr : std_logic;
--  end record;
--  type t_field_signals_out is record
--    data : std_logic_vector; -- VHDL-2008
--    swacc : std_logic;
--    swmod : std_logic;
--  end record;

  type t_mem_in is record
    ena  : std_logic;
    wr   : std_logic;
    addr : std_logic_vector(32-1 downto 0);
    data : std_logic_vector(32-1 downto 0);
  end record t_mem_in;
  type t_mem_in_arr is array (natural range <>) of t_mem_in;

  -- TODO make this a record as well just to stay consistent
  subtype t_mem_out is std_logic_vector(32-1 downto 0);
  type t_mem_out_arr is array (natural range <>) of t_mem_out;

  -- interface types
  type t_if_type Is (DPM, AXI4, IBUS, WISHBONE, AVALON, NONE);
  type t_if_type_array is array (natural range <>) of t_if_type;

end package pkg_reg_common;

package body pkg_reg_common is
end package body;
