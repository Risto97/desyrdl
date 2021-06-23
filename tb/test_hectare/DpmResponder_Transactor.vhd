library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all ;

library osvvm ;
  context osvvm.OsvvmContext ;

library osvvm_common ;
  context osvvm_common.OsvvmCommonContext ;

library osvvm_dpm;
use work.DpmInterfacePkg.all;

entity DpmResponder is
  port (
    Clk          : in std_logic;
    nReset       : in std_logic;

    DpmInterface : inout DpmRecType;
    TransRec     : inout AddressBusTransactionRecType
  );
end entity DpmResponder;

architecture TransactorResponder of DpmResponder is

  constant MODEL_INSTANCE_NAME : string :=
    PathTail(to_lower(DpmResponder'PATH_NAME));

  signal ModelId : AlertLogIDType;

  signal ReadReceiveCount  : integer := 0;
  signal WriteReceiveCount : integer := 0;

  signal WriteHappened : std_logic;
  signal WriteAddr : std_logic_vector (DpmInterface.DpmIn.Addr'length-1 downto 0);
  signal WriteData : std_logic_vector (DpmInterface.DpmIn.Data'length-1 downto 0);

begin

  -- Initialize interface
  InitDpmRec (DpmRec => DpmInterface);

  -- Handle transactions from TestCtrl
  -- expect a WRITE_OP, TestCtrl calls GetWrite (directive)
  -- expect a READ_DATA from SendReadData? Or ASYNC_READ_DATA from SendReadDataAsync? (interface)
  -- blocking, asynchronous or try: blocking is probably easiest, async needs FIFO?
  TransactionHandler : process
  begin

    -- from AddressBusTransactionPkg
    WaitForClock(Clk, 2);

    WaitForTransaction(
      Clk => Clk,
      Rdy => TransRec.Rdy,
      Ack => TransRec.Ack
    );

    case TransRec.Operation is

      when WAIT_FOR_CLOCK =>
        WaitForClock(Clk, TransRec.IntToModel) ;

      when GET_ALERTLOG_ID =>
        TransRec.IntFromModel <= integer(ModelID) ;
        wait until Clk = '1' ;

      when GET_TRANSACTION_COUNT =>
        TransRec.IntFromModel <= WriteReceiveCount + ReadReceiveCount ;
        wait until Clk = '1' ;

      when GET_WRITE_TRANSACTION_COUNT =>
        TransRec.IntFromModel <= WriteReceiveCount ;
        wait until Clk = '1' ;

      when GET_READ_TRANSACTION_COUNT =>
        TransRec.IntFromModel <= ReadReceiveCount ;
        wait until Clk = '1' ;

      when ASYNC_READ =>
        -- TODO don't directly use DpmInterface signals to catch a read
        -- transaction.
        if DpmInterface.DpmIn.Ena = '1' and DpmInterface.DpmIn.WR = '0' then
          TransRec.BoolFromModel <= TRUE;
          TransRec.Address       <= ToTransaction(WriteAddr, TransRec.Address'length);
        else
          TransRec.BoolFromModel <= FALSE;
        end if;

        wait for 0 ns;

      when READ_OP =>
        -- TODO don't directly use DpmInterface signals to catch a read
        -- transaction.
        wait on Clk until Clk = '1' and DpmInterface.DpmIn.Ena = '1' and DpmInterface.DpmIn.WR = '0';
        TransRec.BoolFromModel <= TRUE;
        TransRec.Address       <= ToTransaction(DpmInterface.DpmIn.Addr, TransRec.Address'length);

        wait for 0 ns;

      when ASYNC_WRITE =>
        if WriteHappened = '1' then
          TransRec.BoolFromModel <= TRUE;
          TransRec.Address       <= ToTransaction(WriteAddr, TransRec.Address'length);
          TransRec.DataFromModel <= ToTransaction(WriteData, TransRec.DataFromModel'length);
        else
          TransRec.BoolFromModel <= FALSE;
          TransRec.DataFromModel <= (TransRec.DataFromModel'range => '0');
        end if;

        wait for 0 ns;

      when WRITE_OP =>
        WaitForToggle(WriteReceiveCount);
        TransRec.BoolFromModel <= TRUE;
        TransRec.Address       <= ToTransaction(WriteAddr, TransRec.Address'length);
        TransRec.DataFromModel <= ToTransaction(WriteData, TransRec.DataFromModel'length);

      when GET_MODEL_OPTIONS | SET_MODEL_OPTIONS =>
        Alert(ModelID, "Model options unimplemented", FAILURE);
        wait for 0 ns;

      when others =>
        Alert(ModelID, "Transaction not implemented", FAILURE);
        wait for 0 ns;

    end case;

    wait for 0 ns;

  end process;

  -- Handle reuests ok DPM interface
  DpmHandler : process
    variable ID : AlertLogIDType;
  begin
    -- initialize
    ID := GetAlertLogID(MODEL_INSTANCE_NAME);
    ModelID <= ID;

    WaitForClock(Clk, 2);

    HandleDpm : loop
      wait on Clk until Clk = '1' and DpmInterface.DpmIn.Ena = '1';

      WriteHappened <= '0';

      if DpmInterface.DpmIn.WR = '0' then
        DpmInterface.DpmOut.Data <= FromTransaction(TransRec.DataToModel, DpmInterface.DpmOut.Data'length);
        increment(ReadReceiveCount);
        wait for 0 ns;
        Log(ModelID,
          "Read." &
          "  Addr: " & to_hstring(DpmInterface.DpmIn.Addr) &
          "  Operation# " & to_string(ReadReceiveCount),
          INFO
        );
      else

        -- increment a counter to notify the TransactionHandler and to have a
        -- metric
        increment(WriteReceiveCount);
        -- only active for once clock after a write, bit of a hack for ASYNC_WRITE
        WriteHappened <= '1';
        WriteAddr <= DpmInterface.DpmIn.Addr;
        WriteData <= DpmInterface.DpmIn.Data;
        wait for 0 ns;

        Log(ModelID,
          "Write." &
          "  Addr: " & to_hstring(DpmInterface.DpmIn.Addr) &
          "  Data: " & to_hstring(DpmInterface.DpmIn.Data) &
          "  Operation# " & to_string(WriteReceiveCount),
          INFO
        );
      end if;
    end loop;
  end process;



end TransactorResponder;
