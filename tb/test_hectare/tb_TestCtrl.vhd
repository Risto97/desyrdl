library ieee ;
  use ieee.std_logic_1164.all ;
  use ieee.numeric_std.all ;
  use ieee.numeric_std_unsigned.all ;
  
library OSVVM ; 
  context OSVVM.OsvvmContext ; 

library osvvm_Axi4 ;
  context osvvm_Axi4.Axi4LiteContext ; 

library work ;
  use work.pkg_reg_test_hectare.all;

entity TestCtrl is
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
    constant AXI_ADDR_WIDTH : integer := AxiSuperTransRec.Address'length ; 
    constant AXI_DATA_WIDTH : integer := AxiSuperTransRec.DataToModel'length ;  
end entity TestCtrl ;

architecture BasicReadWrite of TestCtrl is

  signal TestDone : integer_barrier := 1 ;
 
begin

  ------------------------------------------------------------
  -- ControlProc
  --   Set up AlertLog and wait for end of test
  ------------------------------------------------------------
  ControlProc : process
  begin
    -- Initialization of test
    SetAlertLogName("tb_TestCtrl") ;
    SetLogEnable(PASSED, TRUE) ;    -- Enable PASSED logs
    SetLogEnable(INFO, TRUE) ;    -- Enable INFO logs

    -- Wait for testbench initialization 
    wait for 0 ns ;  wait for 0 ns ;
    TranscriptOpen("tb_TestCtrl_log.txt") ;
    SetTranscriptMirror(TRUE) ; 

    -- Wait for Design Reset
    wait until nReset = '1' ;  
    ClearAlerts ;

    -- Initialize register values
    ModuleRegistersIn.iitoh(0,0).data.data <= X"1BEEF4A1";
    ModuleRegistersIn.iitoh(0,0).data.we <= '1';

    -- test ID 1
    -- WORD_HECTARE(0,0)
    MasterReadCheck(AxiSuperTransRec, std_logic_vector(to_unsigned(C_REGISTER_INFO(0).addr, AXI_ADDR_WIDTH)), X"0000_0000"); -- should be default values before any writes
    MasterWrite(    AxiSuperTransRec, std_logic_vector(to_unsigned(C_REGISTER_INFO(0).addr, AXI_ADDR_WIDTH)), X"5555_BEEF");
    WaitForClock(   AxiSuperTransRec, 2);
    MasterReadCheck(AxiSuperTransRec, std_logic_vector(to_unsigned(C_REGISTER_INFO(0).addr, AXI_ADDR_WIDTH)), X"5555_BEEF");
    assert ModuleRegistersOut.hectare(0,0).data.data = X"5555_BEEF" report "Wrong data on hectare.data.data (make me a transcation!)" severity note;

    -- test ID 0
    -- iitoh(0,0)
    WaitForClock(   AxiSuperTransRec, 2);
    MasterReadCheck(AxiSuperTransRec, std_logic_vector(to_unsigned(C_REGISTER_INFO(2).addr, AXI_ADDR_WIDTH)), X"1BEE_F4A1");

    -- Wait for test to finish
    WaitForBarrier(TestDone, 35 ms) ;
    AlertIf(now >= 35 ms, "Test finished due to timeout") ;
    AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");
    
    
    TranscriptClose ; 
    -- Printing differs in different simulators due to differences in process order execution
    -- AlertIfDiff("./results/TbAxi4_BasicReadWrite.txt", "../AXI4/Axi4/testbench/validated_results/TbAxi4_BasicReadWrite.txt", "") ; 
    
    print("") ;
    ReportAlerts ; 
    print("") ;
    std.env.stop ; 
    wait ; 
  end process ControlProc ; 

end architecture;
