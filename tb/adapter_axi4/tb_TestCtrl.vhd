library ieee ;
  use ieee.std_logic_1164.all ;
  use ieee.numeric_std.all ;
  use ieee.numeric_std_unsigned.all ;
  
library OSVVM ; 
  context OSVVM.OsvvmContext ; 

library osvvm_Axi4 ;
  context osvvm_Axi4.Axi4LiteContext ; 

entity TestCtrl is
  port (
    -- Global Signal Interface
    Clk                 : In    std_logic ;
    nReset              : In    std_logic ;

    -- Transaction Interfaces
    AxiSuperTransRec    : inout AddressBusTransactionRecType ;
    AxiMinionTransRec   : inout AddressBusTransactionRecType 

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

    MasterWrite(    AxiSuperTransRec, X"0010", X"FEED_BEEF");
    WaitForClock(   AxiSuperTransRec, 2);
    MasterReadCheck(AxiSuperTransRec, X"0010", X"FEED_FFEF");

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
