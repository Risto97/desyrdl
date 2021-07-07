-- Copyright (c) 2020-2021 Deutsches Elektronen-Synchrotron DESY.

-- Based on OSVVM's Axi4LiteInterfacePkg.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all ;

-- based on OSVVM/AXI4/common/src/Axi4LiteInterfacePkg.vhd

package DpmInterfacePkg is

  type DpmInRecType is record
    Data : std_logic_vector;
    Addr : std_logic_vector;
    Ena  : std_logic;
    WR   : std_logic;
  end record;

  type DpmOutRecType is record
    Data : std_logic_vector;
  end record;

  type DpmRecType is record
    DpmIn  : DpmInRecType;
    DpmOut : DpmOutRecType;
  end record;

  function InitDpmInRec  (AddrWidth : natural; DataWidth: natural) return DpmInRecType;
  function InitDpmOutRec (DataWidth: natural)                      return DpmOutRecType;
  function InitDpmRec    (AddrWidth : natural; DataWidth: natural) return DpmRecType;

  procedure InitDpmRec (signal DpmRec : out DpmRecType);

end package DpmInterfacePkg;

package body DpmInterfacePkg is

  function InitDpmInRec (AddrWidth : natural; DataWidth: natural) return DpmInRecType is
  begin
    return (
      Data => (DataWidth-1 downto 0 => 'Z'),
      Addr => (AddrWidth-1 downto 0 => 'Z'),
      Ena  => 'Z',
      WR   => 'Z'
    );
  end function;

  function InitDpmOutRec (DataWidth: natural) return DpmOutRecType is
  begin
    return (
      Data => (DataWidth-1 downto 0 => 'Z')
    );
  end function;

  function InitDpmRec    (AddrWidth : natural; DataWidth: natural) return DpmRecType is
  begin
    return (
      DpmIn  => InitDpmInRec(AddrWidth, DataWidth),
      DpmOut => InitDpmOutRec(DataWidth)
    );
  end function;

  procedure InitDpmRec (signal DpmRec : out DpmRecType) is
    constant ADDR_WIDTH : integer := DpmRec.DpmIn.Addr'length;
    constant DATA_WIDTH : integer := DpmRec.DpmIn.Data'length;
  begin
    DpmRec <= InitDpmRec(ADDR_WIDTH, DATA_WIDTH);
  end procedure;

end package body;
