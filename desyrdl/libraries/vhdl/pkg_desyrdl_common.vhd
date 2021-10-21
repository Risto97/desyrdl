-------------------------------------------------------------------------------
--          ____  _____________  __                                          --
--         / __ \/ ____/ ___/\ \/ /                 _   _   _                --
--        / / / / __/  \__ \  \  /                 / \ / \ / \               --
--       / /_/ / /___ ___/ /  / /               = ( M | S | K )=             --
--      /_____/_____//____/  /_/                   \_/ \_/ \_/               --
--                                                                           --
-------------------------------------------------------------------------------
--! @copyright  (c) 2021 DESY
--! @license    SPDX-License-Identifier: Apache-2.0
-------------------------------------------------------------------------------
--! @file pkg_desyrdl_common.vhd
--! @brief package with common DesyRdl components
-------------------------------------------------------------------------------
--! @author Michael Büchler <michael.buechler@desy.de>
--! @author Lukasz Butkowski <lukasz.butkowski@desy.de>
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- library desy;
-- use desy.common_types.all;
-- use desy.common_axi.all;

package common is

  constant C_AXI4L_ADDR_WIDTH : natural := 32;
  constant C_AXI4L_DATA_WIDTH : natural := 32;

  ---------------------------------------------------------------------------
  -- common type definitions
  -- type t_4b_slv_array  is array (natural range<>) of std_logic_vector( 3 downto 0) ;
  -- type t_32b_slv_array is array (natural range<>) of std_logic_vector(31 downto 0) ;
  -- type t_integer_array is array (natural range<>) of integer ;

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
  type tif_ibus_m2s is record
    addr   : std_logic_vector(31 downto 0);
    data   : std_logic_vector(31 downto 0);
    rena   : std_logic;
    wena   : std_logic;
    clk    : std_logic;
  end record tif_ibus_m2s;

  -- Output signals of IBUS. Through this record the application send data/commands to the bus
  type tif_ibus_s2m is record
    clk    : std_logic;
    data   : std_logic_vector(31 downto 0);
    rack   : std_logic;
    wack   : std_logic;
  end record tif_ibus_s2m;

  -- Array of IBUS outputs
  type tif_ibus_m2s_array is array (natural range<>) of tif_ibus_m2s;

  -- Array of IBUS inputs
  type tif_ibus_s2m_array is array (natural range<>) of tif_ibus_s2m;

  -- Default IBUS connections for the output (All entries equals 0)
  constant C_IBUS_M2S_DEFAULT : tif_ibus_m2s := (
    addr => (others => '0'),
    data => (others => '0'),
    rena => '0',
    wena => '0',
    clk  => '0'
  );
  -- Default IBUS connections for the input (All entries equals 0)
  constant C_IBUS_S2M_DEFAULT : tif_ibus_s2m := (
    clk  => '0',
    data => (others => '0'),
    rack => '0',
    wack => '0'
  );


  ---------------------------------------------------------------------------
  -- SystemRDL-specific definitions
  --type t_field_access is (R, W, RW, NA);
  subtype t_access_type is integer;
  constant C_NA  : integer := 1;
  constant C_RW  : integer := 2;
  constant C_R   : integer := 3;
  constant C_W   : integer := 4;
  constant C_RW1 : integer := 5;
  constant C_W1  : integer := 6;

  type t_field_type is (STORAGE, WIRE, COUNTER, INTERRUPT);

  type t_field_info is record
    ftype     : t_field_type;
    len       : integer;
    upper     : integer;
    lower     : integer;
    sw        : t_access_type;
    hw        : t_access_type;
    we        : integer;
    incrwidth : integer;
    decrwidth : integer;
    defval    : integer;
  end record;

  type t_field_info_array is array (natural range <>) of t_field_info;

  constant C_FIELD_NONE : t_field_info := (WIRE, 0, 0, 0, C_NA, C_NA, 0, 0, 0, 0);

  type t_reg_info is record
    -- index    : integer;
    address  : integer;
    elements : integer;
    index    : integer;
    fields   : t_field_info_array(31 downto 0);
    --dim         : natural;
    dim_n    : positive;
    dim_m    : positive;
  end record;

  type t_reg_info_array is array (natural range <>) of t_reg_info;

  constant C_REG_NONE : t_reg_info := (0, 0, 0,(others => C_FIELD_NONE),1,1);

  type t_mem_info is record
    -- index      : integer;
    address    : integer;
    addrwidth  : integer;
    datawidth  : integer;
    entries    : integer;
    sw         : t_access_type;
  end record;

  type t_mem_info_array is array (natural range <>) of t_mem_info;

  constant C_MEM_NONE : t_mem_info := (0, 0, 0, 0, C_NA);

  type t_ext_info is record
    -- index      : integer;
    address    : integer;
    addrwidth  : integer;
    size       : integer;
  end record;

  type t_ext_info_array is array (natural range <>) of t_ext_info;

  constant C_EXT_NONE : t_ext_info := (0, 0, 0);

  -- interface types
  type t_if_type Is (DPM, AXI4, AXI4L, IBUS, WISHBONE, AVALON, NONE);
  type t_if_type_array is array (natural range <>) of t_if_type;


  -- components
  component decoder_axi4l is
    generic (
      g_addr_width    : integer;
      g_data_width    : integer;
      g_register_info : t_reg_info_array;
      g_regitems      : integer;
      g_regcount      : integer;
      g_mem_info      : t_mem_info_array;
      g_memitems      : integer;
      g_memcount      : integer;
      g_ext_info      : t_ext_info_array;
      g_extitems      : integer;
      g_extcount      : integer);
    port (
      pi_clock      : in  std_logic;
      pi_reset      : in  std_logic;
      po_reg_rd_stb : out std_logic_vector(g_regcount-1 downto 0);
      po_reg_wr_stb : out std_logic_vector(g_regcount-1 downto 0);
      po_reg_data   : out std_logic_vector(g_data_width-1 downto 0);
      pi_reg_data   : in  std_logic_vector(g_data_width-1 downto 0);
      po_mem_stb    : out std_logic_vector(g_memcount-1 downto 0);
      po_mem_we     : out std_logic;
      po_mem_addr   : out std_logic_vector(g_addr_width-1 downto 0);
      po_mem_data   : out std_logic_vector(g_data_width-1 downto 0);
      pi_mem_data   : in  std_logic_vector(g_data_width-1 downto 0);
      pi_mem_ack    : in  std_logic;
      pifi_ext      : in  tif_axi4l_s2m_array(G_EXTCOUNT downto 0);
      pifo_ext      : out tif_axi4l_m2s_array(G_EXTCOUNT downto 0);
      pifi_s_top    : in  tif_axi4l_m2s;
      pifo_s_top    : out tif_axi4l_s2m);
  end component decoder_axi4l;

  component reg_field_storage is
    generic (
      g_info : t_field_info);
    port (
      pi_clock     : in  std_logic;
      pi_reset     : in  std_logic;
      pi_sw_rd_stb : in  std_logic;
      pi_sw_wr_stb : in  std_logic;
      pi_sw_data   : in  std_logic_vector(g_info.len-1 downto 0);
      po_sw_data   : out std_logic_vector(g_info.len-1 downto 0);
      pi_hw_we     : in  std_logic;
      pi_hw_data   : in  std_logic_vector(g_info.len-1 downto 0);
      po_hw_data   : out std_logic_vector(g_info.len-1 downto 0);
      po_hw_swmod  : out std_logic;
      po_hw_swacc  : out std_logic);
  end component reg_field_storage;

  component axi4l_to_axi4l is
    port (
      pi_reset       : in  std_logic;
      pi_clock       : in  std_logic;
      pifi_s_decoder : in  tif_axi4l_m2s;
      pifo_s_decoder : out tif_axi4l_s2m;
      pifo_m_ext     : out tif_axi4l_m2s;
      pifi_m_ext     : in  tif_axi4l_s2m);
  end component axi4l_to_axi4l;

  component axi4l_to_ibus is
    port (
      pi_reset       : in  std_logic;
      pi_clock       : in  std_logic;
      pifi_s_decoder : in  tif_axi4l_m2s;
      pifo_s_decoder : out tif_axi4l_s2m;
      pifo_m_ext     : out tif_ibus_m2s;
      pifi_m_ext     : in  tif_ibus_s2m);
  end component axi4l_to_ibus;
end package common;

package body common is
end package body;
