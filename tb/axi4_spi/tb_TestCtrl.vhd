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
    ModuleRegistersOut : in t_registers_test_hectare_out;
    ModuleMemoriesIn : out t_memories_test_hectare_in;
    ModuleMemoriesOut : in t_memories_test_hectare_out

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
    assert ModuleRegistersOut.hectare(0,0).data.data = X"5555_BEEF" report "Wrong data on hectare.data.data (TODO make me a transcation!)" severity note;

    -- test ID 0
    -- iitoh(0,0)
    WaitForClock(   AxiSuperTransRec, 2);
    MasterReadCheck(AxiSuperTransRec, std_logic_vector(to_unsigned(C_REGISTER_INFO(2).addr, AXI_ADDR_WIDTH)), X"1BEE_F4A1");

    -- memory test 1: write from user logic, read from AXI
    WaitForClock(   AxiSuperTransRec, 2);
    -- let the module put something at offset 12 and try reading that from AXI4
    ModuleMemoriesIn.coolmem.ena <= '1';
    ModuleMemoriesIn.coolmem.wr  <= '1';
    ModuleMemoriesIn.coolmem.addr(C_MEM_AW(0)-1 downto 0) <= std_logic_vector(to_unsigned(12, C_MEM_AW(0)));
    ModuleMemoriesIn.coolmem.data <= x"0000_00AA";
    WaitForClock(   AxiSuperTransRec, 1);
    ModuleMemoriesIn.coolmem.ena <= '0';
    ModuleMemoriesIn.coolmem.wr  <= '0';
    WaitForClock(   AxiSuperTransRec, 1);
    MasterReadCheck(AxiSuperTransRec, std_logic_vector(to_unsigned(C_MEM_START(0)+12*4, AXI_ADDR_WIDTH)), X"0000_00AA");

    -- memory test 2: write from AXI, read from user logic
    -- write mem from AXI
    WaitForClock(   AxiSuperTransRec, 2);
    MasterWrite(AxiSuperTransRec, std_logic_vector(to_unsigned(C_MEM_START(0)+3*4, AXI_ADDR_WIDTH)), X"BB");
    -- read from user logic
    WaitForClock(   AxiSuperTransRec, 2);
    ModuleMemoriesIn.coolmem.ena <= '1';
    ModuleMemoriesIn.coolmem.wr  <= '0';
    ModuleMemoriesIn.coolmem.addr(C_MEM_AW(0)-1 downto 0) <= std_logic_vector(to_unsigned(3, C_MEM_AW(0)));
    WaitForClock(   AxiSuperTransRec, 1);
    ModuleMemoriesIn.coolmem.ena <= '0';
    WaitForClock(   AxiSuperTransRec, 1);
    assert ModuleMemoriesOut.coolmem(7 downto 0) = X"BB" report "Wrong data on memory (TODO make me a transcation!)" severity note;

    -- SPI transactions take too long for the default timeout
    SetModelOptions(AxiSuperTransRec, WRITE_RESPONSE_VALID_TIME_OUT, 125);
    SetModelOptions(AxiSuperTransRec, READ_DATA_VALID_TIME_OUT, 125);
    -- The second transaction from the AXI4 Super will fail if the peripheral
    -- is not ready while the first transaction is handled.
    SetModelOptions(AxiSuperTransRec, WRITE_ADDRESS_READY_TIME_OUT, 125);
    SetModelOptions(AxiSuperTransRec, WRITE_DATA_READY_TIME_OUT, 125);
    SetModelOptions(AxiSuperTransRec, READ_ADDRESS_READY_TIME_OUT, 125);

    --MasterReadCheck(AxiSuperTransRec, 0x48, X"0000_0000"); -- should be default values before any writes
    WaitForClock(   AxiSuperTransRec, 2);
    Write(    AxiSuperTransRec, X"0001_0048", X"0000_0055");

    -- SPI transactions take long, wait for many clocks
    WaitForClock(   AxiSuperTransRec, 100);
    ReadCheck(AxiSuperTransRec, X"0001_0048", X"0000_0055"); -- should be default values before any writes


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
