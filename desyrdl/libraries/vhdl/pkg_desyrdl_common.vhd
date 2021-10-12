-- Copyright (c) 2020-2021 Deutsches Elektronen-Synchrotron DESY.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package common is

  constant C_AXI4L_ADDR_WIDTH : natural := 32;
  constant C_AXI4L_DATA_WIDTH : natural := 32;

  ---------------------------------------------------------------------------
  -- common type definitions
  type t_4b_slv_array  is array (natural range<>) of std_logic_vector( 3 downto 0) ;
  type t_32b_slv_array is array (natural range<>) of std_logic_vector(31 downto 0) ;
  type t_integer_array is array (natural range<>) of integer ;

  --============================================================================
  -- AXI4-Lite
  --============================================================================
  type tif_axi4l_m2s is record
    -- write address channel signals---------------------------------------------
    awaddr      : std_logic_vector(C_AXI4L_ADDR_WIDTH-1 downto 0);
    awprot      : std_logic_vector(2 downto 0);
    awvalid     : std_logic;
    -- write data channel signals---------------------------------------------
    wdata       : std_logic_vector(C_AXI4L_DATA_WIDTH-1 downto 0);
    wstrb       : std_logic_vector(C_AXI4L_DATA_WIDTH/8-1 downto 0);
    wvalid      : std_logic;
    -- write response channel signals
    bready      : std_logic;
    -- read address channel signals ---------------------------------------------
    araddr      : std_logic_vector(C_AXI4L_ADDR_WIDTH-1 downto 0);
    arprot      : std_logic_vector(2 downto 0);
    arvalid     : std_logic;
    -- read data channel signals---------------------------------------------
    rready      : std_logic;
  end record tif_axi4l_m2s;

  type tif_axi4l_s2m is record
    -- write address channel signals---------------------------------------------
    awready     : std_logic;
    -- write data channel signals---------------------------------------------
    wready      : std_logic;
    -- write response channel signals ---------------------------------------------
    bresp       : std_logic_vector(1 downto 0);
    bvalid      : std_logic;
    -- read address channel signals---------------------------------------------
    arready     : std_logic;
    -- read data channel signals---------------------------------------------
    rdata       : std_logic_vector(C_AXI4L_DATA_WIDTH-1 downto 0);
    rresp       : std_logic_vector(1 downto 0);
    rvalid      : std_logic;
  end record tif_axi4l_s2m;

  type tif_axi4l_m2s_array is array (natural range <>) of tif_axi4l_m2s;
  type tif_axi4l_s2m_array is array (natural range <>) of tif_axi4l_s2m;

  constant  C_AXI4L_S2M_DEFAULT : tif_axi4l_s2m := (
    awready     => '0',
    wready      => '0',
    bresp       => (others => '0'),
    bvalid      => '0',
    arready     => '0' ,
    rdata       => (others => '0'),
    rresp       => (others => '0'),
    rvalid      => '0'
  );
  constant  C_AXI4L_M2S_DEFAULT : tif_axi4l_m2s := (
    awaddr        => (others => '0'),
    awprot        => (others => '0'),
    awvalid       => '0',
    wdata         => (others => '0'),
    wstrb         => (others => '0'),
    wvalid        => '0',
    bready        => '0',
    araddr        => (others => '0'),
    arprot        => (others => '0'),
    arvalid       => '0',
    rready        => '0'
  );

  ---------------------------------------------------------------------------
  -- Interface definitions for IBUS
  -- Internal BUS (IBUS) is the internal bus used in the applications of MSK Firmware
  -- repository.

  -- Output signals of IBUS. Through this record the application send data/commands to the bus
  type t_ibus_m2s is record
    addr   : std_logic_vector(31 downto 0);
    data   : std_logic_vector(31 downto 0);
    rena   : std_logic;
    wena   : std_logic;
    clk    : std_logic;
  end record t_ibus_m2s;

  -- Output signals of IBUS. Through this record the application send data/commands to the bus
  type t_ibus_s2m is record
    clk    : std_logic;
    data   : std_logic_vector(31 downto 0);
    rack   : std_logic;
    wack   : std_logic;
  end record t_ibus_s2m;

  -- Array of IBUS outputs
  type t_ibus_m2s_array is array (natural range<>) of t_ibus_m2s;

  -- Array of IBUS inputs
  type t_ibus_s2m_array is array (natural range<>) of t_ibus_s2m;

  -- Default IBUS connections for the output (All entries equals 0)
  constant C_IBUS_M2S_DEFAULT : t_ibus_m2s := (
    addr => (others => '0'),
    data => (others => '0'),
    rena => '0',
    wena => '0',
    clk  => '0'
  );
  -- Default IBUS connections for the input (All entries equals 0)
  constant C_IBUS_S2M_DEFAULT : t_ibus_s2m := (
    clk  => '0',
    data => (others => '0'),
    rack => '0',
    wack => '0'
  );


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
    ftype     : t_field_type;
    len       : integer;
    upper     : integer;
    lower     : integer;
    hw_we     : boolean;
    sw_access : t_field_access;
    hw_access : t_field_access;
    def_val   : std_logic_vector(32-1 downto 0);
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

  type tif_mem_in is record
    ena  : std_logic;
    wr   : std_logic;
    addr : std_logic_vector(32-1 downto 0);
    data : std_logic_vector(32-1 downto 0);
  end record tif_mem_in;
  type tif_mem_in_arr is array (natural range <>) of tif_mem_in;

  -- TODO make this a record as well just to stay consistent
  subtype tif_mem_out is std_logic_vector(32-1 downto 0);
  type tif_mem_out_arr is array (natural range <>) of tif_mem_out;

  -- interface types
  type t_if_type Is (DPM, AXI4, AXI4L, IBUS, WISHBONE, AVALON, NONE);
  type t_if_type_array is array (natural range <>) of t_if_type;

end package common;

package body common is
end package body;
