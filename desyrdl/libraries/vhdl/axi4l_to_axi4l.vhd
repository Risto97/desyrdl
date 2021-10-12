-- Copyright (c) 2020-2021 Deutsches Elektronen-Synchrotron DESY.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library desyrdl;
use desyrdl.common.all;
-- library desy;
-- use desy.common_axi.all;

entity axi4l_to_axi4l is
  port (
    pi_reset       : in  std_logic;
    pi_clock       : in  std_logic;
    pifi_s_decoder : in  tif_axi4l_m2s;
    pifo_s_decoder : out tif_axi4l_s2m;
    pifo_m_ext     : out tif_axi4l_m2s;
    pifi_m_ext     : in  tif_axi4l_s2m
  );
end entity axi4l_to_axi4l;

architecture behav of axi4l_to_axi4l is

begin

  pifo_m_ext     <= pifi_s_decoder;
  pifo_s_decoder <= pifi_m_ext;

end behav;
