library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all ;

library work;
use work.pkg_types.all;
use work.pkg_reg_marsupials.all; -- maybe rename to sth like pkg_axi4_<foocomponent>

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
      AxiMinionTransRec   : inout AddressBusTransactionRecType
    ) ;
  end component TestCtrl ;

  -- DUT register type
  signal regs_in  : t_registers_marsupials_in;
  signal regs_out : t_registers_marsupials_out;

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
  ins_top : entity work.top
  generic map (
                G_ADDR_W => AXI_ADDR_WIDTH
              )
  port map (
             pi_clk        => Clk,
             pi_reset      => not nReset,

             S_AXI_AWADDR  => AWAddr,
             S_AXI_AWPROT  => AWPROT,
             S_AXI_AWVALID => AWVALID,
             S_AXI_AWREADY => AWREADY,
             S_AXI_WDATA   => WDATA,
             S_AXI_WSTRB   => WSTRB,
             S_AXI_WVALID  => WVALID,
             S_AXI_WREADY  => WREADY,
             S_AXI_BRESP   => BRESP,
             S_AXI_BVALID  => BVALID,
             S_AXI_BREADY  => BREADY,
             S_AXI_ARADDR  => ARADDR,
             S_AXI_ARPROT  => ARPROT,
             S_AXI_ARVALID => ARVALID,
             S_AXI_ARREADY => ARREADY,
             S_AXI_RDATA   => RDATA,
             S_AXI_RRESP   => RRESP,
             S_AXI_RVALID  => RVALID,
             S_AXI_RREADY  => RREADY,
             pi_logic_regs => regs_in,
             po_logic_regs => regs_out
           );

  regs_in.wombat(0,0).foo.we <= '0';
  regs_in.wombat(0,0).bar.we <= '0';
  regs_in.wombat(0,0).baz.we <= '0';
  regs_in.wombat(0,0).foo.data <= (others => '0');
  regs_in.wombat(0,0).bar.data <= (others => '0');
  regs_in.wombat(0,0).baz.data <= (others => '0');

  regs_in.koala(0,0).hp.data <= x"9876";
  regs_in.koala(0,0).hp.we <= '0';

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
    AxiMinionTransRec  => AxiMinionTransRec
  ) ;

end architecture sim;
