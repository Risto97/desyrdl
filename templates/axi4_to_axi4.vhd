-- Copyright (c) 2020-2021 Deutsches Elektronen-Synchrotron DESY.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg_reg_common.all;

entity axi4_to_axi4 is
  port (
    pi_reset       : in  std_logic;
    pi_clock       : in  std_logic;
    pi_adapter_m2s : in  t_axi4_m2s;
    po_adapter_s2m : out t_axi4_s2m;
    po_ext_m2s     : out t_axi4_m2s;
    pi_ext_s2m     : in  t_axi4_s2m
  );
end entity axi4_to_axi4;

architecture behav of axi4_to_axi4 is

begin

  po_ext_m2s     <= pi_adapter_m2s;
  po_adapter_s2m <= pi_ext_s2m;

end behav;
