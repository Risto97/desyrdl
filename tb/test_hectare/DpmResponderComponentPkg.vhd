library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all ;

--library osvvm ;
--  context osvvm.OsvvmContext ;

library osvvm_common ;
  context osvvm_common.OsvvmCommonContext ;

library osvvm_dpm;
use work.DpmInterfacePkg.all;

package DpmResponderComponentPkg is
  component DpmResponder is
    port (
      Clk          : in std_logic;
      nReset       : in std_logic;

      DpmInterface : inout DpmRecType;
      TransRec     : inout AddressBusTransactionRecType
    );
  end component DpmResponder;
end package;
