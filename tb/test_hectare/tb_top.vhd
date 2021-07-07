-- Copyright (c) 2020-2021 Deutsches Elektronen-Synchrotron DESY.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all ;

library work;
use work.pkg_types.all;
use work.pkg_reg_common.all; -- maybe rename to sth like pkg_axi4_<foocomponent>
use work.pkg_reg_test_hectare.all; -- maybe rename to sth like pkg_axi4_<foocomponent>
use work.pkg_axi.all;

library osvvm ;
  context osvvm.OsvvmContext ;

library osvvm_Axi4 ;
  context osvvm_Axi4.Axi4LiteContext ;

library osvvm_dpm;
use osvvm_dpm.DpmInterfacePkg.all;
use osvvm_dpm.DpmResponderComponentPkg.all;

entity tb_top is
end entity;

architecture sim of tb_top is
  -- copy-pasted from OsvvmLibraries/AXI4/Axi4Lite/testbench/TbAxi4.vhd
  constant AXI_ADDR_WIDTH : integer := C_ADDR_W ;
  constant AXI_DATA_WIDTH : integer := 32 ;
  constant AXI_STRB_WIDTH : integer := AXI_DATA_WIDTH/8 ;


  constant tperiod_Clk : time := 10 ns ;
  constant tpd         : time := 2 ns ;

  signal Clk         : std_logic ;
  signal nReset      : std_logic ;

  -- Testbench Transaction Interface
  signal AxiSuperTransRec  : AddressBusRecType(
          Address(AXI_ADDR_WIDTH-1 downto 0),
          DataToModel(AXI_DATA_WIDTH-1 downto 0),
          DataFromModel(AXI_DATA_WIDTH-1 downto 0)
        ) ;

  -- AXI Master Functional Interface
  signal   AxiBus : Axi4LiteRecType(
    WriteAddress( Addr(AXI_ADDR_WIDTH-1 downto 0) ),
    WriteData   ( Data (AXI_DATA_WIDTH-1 downto 0),   Strb(AXI_STRB_WIDTH-1 downto 0) ),
    ReadAddress ( Addr(AXI_ADDR_WIDTH-1 downto 0) ),
    ReadData    ( Data (AXI_DATA_WIDTH-1 downto 0) )
  ) ;


  signal AxiMinionTransRec_spi_ad9510_a  : AddressBusRecType(
          Address(C_EXT_AW(0)-1 downto 0),
          DataToModel(AXI_DATA_WIDTH-1 downto 0),
          DataFromModel(AXI_DATA_WIDTH-1 downto 0)
        ) ;

  -- AXI Minion Functional Interface
  signal AxiBus_spi_ad9510_a : Axi4LiteRecType(
    WriteAddress( Addr(C_EXT_AW(0)-1 downto 0) ),
    WriteData   ( Data (AXI_DATA_WIDTH-1 downto 0),   Strb(AXI_STRB_WIDTH-1 downto 0) ),
    ReadAddress ( Addr(C_EXT_AW(0)-1 downto 0) ),
    ReadData    ( Data (AXI_DATA_WIDTH-1 downto 0) )
  ) ;

  -- DPM Responder transaction interface
  signal DpmTransRec_coolmem : AddressBusRecType(
    Address(C_MEM_AW(0)-1 downto 0), -- TODO get C_MEM_AW(coolmem)
    DataToModel(32-1 downto 0),
    DataFromModel(32-1 downto 0)
  );

  -- DPM Responder functional interface
  signal DpmInterface_coolmem : DpmRecType(
    DpmIn(Addr(C_MEM_AW(0)-1 downto 0), Data(32-1 downto 0)),
    DpmOut(Data(32-1 downto 0))
  );

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
      AxiSuperTransRec               : inout AddressBusRecType ;
      AxiMinionTransRec_spi_ad9510_a : inout AddressBusRecType ;
      DpmTransRec_coolmem            : inout AddressBusRecType ;

      -- Register interface
      ModuleAddrmapIn : out t_addrmap_test_hectare_in;
      ModuleAddrmapOut : in t_addrmap_test_hectare_out
    ) ;
  end component TestCtrl ;

  -- DUT register type
  signal m2s_axi4_hectare : t_axi4_m2s;
  signal s2m_axi4_hectare : t_axi4_s2m;
  signal addrmap_in : t_addrmap_test_hectare_in;
  signal addrmap_out : t_addrmap_test_hectare_out;

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

  ins_dut : entity work.top_reg_test_hectare
  port map (
    pi_clock => Clk,
    pi_reset => not nReset,

    pi_s_axi4 => m2s_axi4_hectare,
    po_s_axi4 => s2m_axi4_hectare,

    pi_addrmap => addrmap_in,
    po_addrmap => addrmap_out
  );

  -- Downstream AXI4

  -- M2S
  --addrmap_out.spi_ad9510_a.awid 
  AxiBus_spi_ad9510_a.WriteAddress.Addr <= addrmap_out.spi_ad9510_a.awaddr(C_EXT_AW(0)-1 downto 0);
  --addrmap_out.spi_ad9510_a.awlen;
  --addrmap_out.spi_ad9510_a.awsize;
  --addrmap_out.spi_ad9510_a.awburst;

  --AxiBus_spi_ad9510_a.WriteAddress.Prot <= addrmap_out.spi_ad9510_a.awprot;
  AxiBus_spi_ad9510_a.WriteAddress.Prot <= (others => '0');
  AxiBus_spi_ad9510_a.WriteAddress.Valid <= addrmap_out.spi_ad9510_a.awvalid;

  --addrmap_out.spi_ad9510_a.wid;
  AxiBus_spi_ad9510_a.WriteData.Data <= addrmap_out.spi_ad9510_a.wdata(AXI_DATA_WIDTH-1 downto 0);
  AxiBus_spi_ad9510_a.WriteData.Strb <= addrmap_out.spi_ad9510_a.wstrb(AXI_DATA_WIDTH/8-1 downto 0);
  --addrmap_out.spi_ad9510_a.wlast;
  AxiBus_spi_ad9510_a.WriteData.Valid <= addrmap_out.spi_ad9510_a.wvalid;

  AxiBus_spi_ad9510_a.WriteResponse.Ready <= addrmap_out.spi_ad9510_a.bready;

  --addrmap_out.spi_ad9510_a.arid;
  AxiBus_spi_ad9510_a.ReadAddress.Addr <= addrmap_out.spi_ad9510_a.araddr(C_EXT_AW(0)-1 downto 0);
  --addrmap_out.spi_ad9510_a.arlen;
  --addrmap_out.spi_ad9510_a.arsize;
  --addrmap_out.spi_ad9510_a.arburst;
  AxiBus_spi_ad9510_a.ReadAddress.Valid <= addrmap_out.spi_ad9510_a.arvalid;
  --AxiBus_spi_ad9510_a.ReadAddress.Prot <= addrmap_out.spi_ad9510_a.arprot;
  AxiBus_spi_ad9510_a.ReadAddress.Prot <= (others => '0');

  AxiBus_spi_ad9510_a.ReadData.Ready <= addrmap_out.spi_ad9510_a.rready;

  --addrmap_out.spi_ad9510_a.aclk 
  --addrmap_out.spi_ad9510_a.areset_n 

  -- S2M
  addrmap_in.spi_ad9510_a.awready <= AxiBus_spi_ad9510_a.WriteAddress.Ready;
  addrmap_in.spi_ad9510_a.wready <= AxiBus_spi_ad9510_a.WriteData.Ready;
  -- <= addrmap_in.spi_ad9510_a.bid;
  addrmap_in.spi_ad9510_a.bresp <= AxiBus_spi_ad9510_a.WriteResponse.Resp;
  addrmap_in.spi_ad9510_a.bvalid <= AxiBus_spi_ad9510_a.WriteResponse.Valid;

  addrmap_in.spi_ad9510_a.arready <= AxiBus_spi_ad9510_a.ReadAddress.Ready;

  -- <= addrmap_in.spi_ad9510_a.rid;
  addrmap_in.spi_ad9510_a.rdata(AXI_DATA_WIDTH-1 downto 0) <= AxiBus_spi_ad9510_a.ReadData.Data;
  addrmap_in.spi_ad9510_a.rresp <= AxiBus_spi_ad9510_a.ReadData.Resp;
  --RLast <= addrmap_in.spi_ad9510_a.rlast;
  addrmap_in.spi_ad9510_a.rvalid <= AxiBus_spi_ad9510_a.ReadData.Valid;

  -- DPM coolmem
  DpmInterface_coolmem.DpmIn.Addr <= addrmap_out.coolmem.addr;
  DpmInterface_coolmem.DpmIn.Data <= addrmap_out.coolmem.data;
  DpmInterface_coolmem.DpmIn.Ena  <= addrmap_out.coolmem.ena;
  DpmInterface_coolmem.DpmIn.WR   <= addrmap_out.coolmem.wr;
  addrmap_in.coolmem <= DpmInterface_coolmem.DpmOut.Data;

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

  Responder_spi_ad9510_a : Axi4LiteResponder
  port map (
    -- Globals
    Clk         => Clk,
    nReset      => nReset,

    -- AXI Master Functional Interface
    AxiBus  => AxiBus_spi_ad9510_a,

    -- Testbench Transaction Interface
    TransRec    => AxiMinionTransRec_spi_ad9510_a
  ) ;

  Axi4Monitor_1 : Axi4LiteMonitor
  port map (
    -- Globals
    Clk         => Clk,
    nReset      => nReset,

    -- AXI Master Functional Interface
    AxiBus     => AxiBus
  ) ;

  Responder_coolmem : entity osvvm_dpm.DpmResponder(TransactorResponder)
  port map(
    Clk => Clk,
    nReset => nReset,

    TransRec => DpmTransRec_coolmem,

    DpmInterface => DpmInterface_coolmem
  );

  -- TestCtrl
  TestCtrl_1 : TestCtrl
  port map (
    -- Globals
    Clk                => Clk,
    nReset             => nReset,

    -- Testbench Transaction Interfaces
    AxiSuperTransRec   => AxiSuperTransRec,
    AxiMinionTransRec_spi_ad9510_a  => AxiMinionTransRec_spi_ad9510_a,
    DpmTransRec_coolmem => DpmTransRec_coolmem,

    -- Register interface
    ModuleAddrmapIn => addrmap_in,
    ModuleAddrmapOut => addrmap_out
  ) ;

end architecture sim;
