-- Copyright (c) 2020-2021 Deutsches Elektronen-Synchrotron DESY.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pkg_types is
  type T_4BitArray  is array (natural range<>) of std_logic_vector( 3 downto 0) ;
  type T_32BitArray is array (natural range<>) of std_logic_vector(31 downto 0) ;
  type T_IntegerArray  is array (natural range<>) of integer ;
end package pkg_types;

