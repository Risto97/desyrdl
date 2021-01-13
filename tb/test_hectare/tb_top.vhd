library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all ;

library work;
use work.pkg_types.all;
use work.pkg_reg_test_hectare.all; -- maybe rename to sth like pkg_axi4_<foocomponent>
use work.pkg_axi.all;

library osvvm ;
  context osvvm.OsvvmContext ;

library osvvm_Axi4 ;
  context osvvm_Axi4.Axi4LiteContext ;

entity tb_top is
end entity;

architecture sim of tb_top is
  -- copy-pasted from OsvvmLibraries/AXI4/Axi4Lite/testbench/TbAxi4.vhd
  constant AXI_ADDR_WIDTH : integer := 16 ;
  constant AXI_DATA_WIDTH : integer := 32 ;
  constant AXI_STRB_WIDTH : integer := AXI_DATA_WIDTH/8 ;


  constant tperiod_Clk : time := 10 ns ;
  constant tpd         : time := 2 ns ;

  signal Clk         : std_logic ;
  signal nReset      : std_logic ;

--  -- Testbench Transaction Interface
--  subtype LocalTransactionRecType is AddressBusTransactionRecType(
--    Address(AXI_ADDR_WIDTH-1 downto 0),
--    DataToModel(AXI_DATA_WIDTH-1 downto 0),
--    DataFromModel(AXI_DATA_WIDTH-1 downto 0)
--  ) ;
--  signal AxiSuperTransRec   : LocalTransactionRecType ;
--  signal AxiMinionTransRec  : LocalTransactionRecType ;
  signal AxiSuperTransRec, AxiMinionTransRec  : AddressBusTransactionRecType(
          Address(AXI_ADDR_WIDTH-1 downto 0),
          DataToModel(AXI_DATA_WIDTH-1 downto 0),
          DataFromModel(AXI_DATA_WIDTH-1 downto 0)
        ) ;

--  -- AXI Master Functional Interface
  signal   AxiBus : Axi4LiteRecType(
    WriteAddress( Addr(AXI_ADDR_WIDTH-1 downto 0) ),
    WriteData   ( Data (AXI_DATA_WIDTH-1 downto 0),   Strb(AXI_STRB_WIDTH-1 downto 0) ),
    ReadAddress ( Addr(AXI_ADDR_WIDTH-1 downto 0) ),
    ReadData    ( Data (AXI_DATA_WIDTH-1 downto 0) )
  ) ;

  -- Aliases to make access to record elements convenient
  -- This is only needed for model use them
  -- Write Address
  alias  AWAddr    : std_logic_vector is AxiBus.WriteAddress.Addr ;
  alias  AWProt    : Axi4ProtType     is AxiBus.WriteAddress.Prot ;
  alias  AWValid   : std_logic        is AxiBus.WriteAddress.Valid ;
  alias  AWReady   : std_logic        is AxiBus.WriteAddress.Ready ;

  -- Write Data
  alias  WData     : std_logic_vector is AxiBus.WriteData.Data ;
  alias  WStrb     : std_logic_vector is AxiBus.WriteData.Strb ;
  alias  WValid    : std_logic        is AxiBus.WriteData.Valid ;
  alias  WReady    : std_logic        is AxiBus.WriteData.Ready ;

  -- Write Response
  alias  BResp     : Axi4RespType     is AxiBus.WriteResponse.Resp ;
  alias  BValid    : std_logic        is AxiBus.WriteResponse.Valid ;
  alias  BReady    : std_logic        is AxiBus.WriteResponse.Ready ;

  -- Read Address
  alias  ARAddr    : std_logic_vector is AxiBus.ReadAddress.Addr ;
  alias  ARProt    : Axi4ProtType     is AxiBus.ReadAddress.Prot ;
  alias  ARValid   : std_logic        is AxiBus.ReadAddress.Valid ;
  alias  ARReady   : std_logic        is AxiBus.ReadAddress.Ready ;

  -- Read Data
  alias  RData     : std_logic_vector is AxiBus.ReadData.Data ;
  alias  RResp     : Axi4RespType     is AxiBus.ReadData.Resp ;
  alias  RValid    : std_logic        is AxiBus.ReadData.Valid ;
  alias  RReady    : std_logic        is AxiBus.ReadData.Ready ;

  component TestCtrl is
    port (
      -- Global Signal Interface
      Clk                 : In    std_logic ;
      nReset              : In    std_logic ;

      -- Transaction Interfaces
      AxiSuperTransRec    : inout AddressBusTransactionRecType ;
      AxiMinionTransRec   : inout AddressBusTransactionRecType ;

      -- Register interface
      ModuleRegistersIn : out t_registers_test_hectare_in;
      ModuleRegistersOut : in t_registers_test_hectare_out
    ) ;
  end component TestCtrl ;

  -- DUT register type
  signal m2s_axi4_hectare : t_axi4_m2s;
  signal s2m_axi4_hectare : t_axi4_s2m;
  signal regs_in  : t_registers_test_hectare_in;
  signal regs_out : t_registers_test_hectare_out;

begin

  -- create Clock
  Osvvm.TbUtilPkg.CreateClock (
    Clk        => Clk,
    Period     => Tperiod_Clk
  )  ;

  -- create nReset
  Osvvm.TbUtilPkg.CreateReset (
    Reset       => nReset,
    ResetActive => '0',
    Clk         => Clk,
    Period      => 7 * tperiod_Clk,
    tpd         => tpd
  ) ;

  -- DUT

  -- M2S
  m2s_axi4_hectare.awid <= (others => '0');
  m2s_axi4_hectare.awaddr(C_ADDR_W-1 downto 0) <= AWAddr;
  --m2s_axi4_hectare.awlen <= ;
  --m2s_axi4_hectare.awsize <= ;
  --m2s_axi4_hectare.awburst <= ;
  --m2s_axi4_hectare.awprot <= ; -- not in t_axi4_m2s, unused by adapter_axi4
  m2s_axi4_hectare.awvalid <= AWValid;
  m2s_axi4_hectare.wid <= (others => '0');
  m2s_axi4_hectare.wdata(AXI_DATA_WIDTH-1 downto 0) <= WData;
  m2s_axi4_hectare.wstrb(AXI_DATA_WIDTH/8-1 downto 0) <= WStrb;
  --m2s_axi4_hectare.wlast <= ;
  m2s_axi4_hectare.wvalid <= WValid;
  m2s_axi4_hectare.bready <= BReady;
  m2s_axi4_hectare.arid <= (others => '0');
  m2s_axi4_hectare.araddr(C_ADDR_W-1 downto 0) <= ARAddr;
  --m2s_axi4_hectare.arlen <= ;
  --m2s_axi4_hectare.arsize <= ;
  --m2s_axi4_hectare.arburst <= ;
  m2s_axi4_hectare.arvalid <= ARValid;
  m2s_axi4_hectare.rready <= RReady;
  m2s_axi4_hectare.aclk <= Clk;
  m2s_axi4_hectare.areset_n <= nReset;


  -- S2M
  AWReady <= s2m_axi4_hectare.awready;
  WReady <= s2m_axi4_hectare.wready;
  -- <= s2m_axi4_hectare.bid;
  BResp <= s2m_axi4_hectare.bresp;
  BValid <= s2m_axi4_hectare.bvalid;
  ARReady <= s2m_axi4_hectare.arready;
  -- <= s2m_axi4_hectare.rid;
  RData <= s2m_axi4_hectare.rdata(AXI_DATA_WIDTH-1 downto 0);
  RResp <= s2m_axi4_hectare.rresp;
  --RLast <= s2m_axi4_hectare.rlast;
  RValid <= s2m_axi4_hectare.rvalid;
  -- <= s2m_axi4_hectare.aclk;
  -- <= s2m_axi4_hectare.areset_n;

  ins_top : entity work.test_hectare_top
  port map (
    pi_clock => Clk,
    pi_reset => not nReset,

    pi_s_axi4 => m2s_axi4_hectare,
    po_s_axi4 => s2m_axi4_hectare,

    pi_regs => regs_in,
    po_regs => regs_out
  );

  Axi4Super_1 : Axi4LiteMaster
  port map (
    -- Globals
    Clk         => Clk,
    nReset      => nReset,

    -- Testbench Transaction Interface
    TransRec    => AxiSuperTransRec,

    -- AXI Master Functional Interface
    AxiBus      => AxiBus
  ) ;


  Axi4Monitor_1 : Axi4LiteMonitor
  port map (
    -- Globals
    Clk         => Clk,
    nReset      => nReset,

    -- AXI Master Functional Interface
    AxiBus     => AxiBus
  ) ;

  -- TestCtrl
  TestCtrl_1 : TestCtrl
  port map (
    -- Globals
    Clk                => Clk,
    nReset             => nReset,

    -- Testbench Transaction Interfaces
    AxiSuperTransRec   => AxiSuperTransRec,
    AxiMinionTransRec  => AxiMinionTransRec,

    -- Register interface
    ModuleRegistersIn => regs_in,
    ModuleRegistersOut => regs_out
  ) ;

end architecture sim;
