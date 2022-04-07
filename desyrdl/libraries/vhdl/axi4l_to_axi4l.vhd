-------------------------------------------------------------------------------
--          ____  _____________  __                                          --
--         / __ \/ ____/ ___/\ \/ /                 _   _   _                --
--        / / / / __/  \__ \  \  /                 / \ / \ / \               --
--       / /_/ / /___ ___/ /  / /               = ( M | S | K )=             --
--      /_____/_____//____/  /_/                   \_/ \_/ \_/               --
--                                                                           --
-------------------------------------------------------------------------------
--! @copyright Copyright 2022 DESY
--! SPDX-License-Identifier: Apache-2.0
-------------------------------------------------------------------------------
--! @date 2021-10-12
--! @author Michael Büchler <michael.buechler@desy.de>
-------------------------------------------------------------------------------
--! @brief Dummy entity just to pass through interface, part of DesyRDL
-------------------------------------------------------------------------------

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
    pi_s_decoder : in  t_axi4l_m2s;
    po_s_decoder : out t_axi4l_s2m;
    po_m_ext     : out t_axi4l_m2s;
    pi_m_ext     : in  t_axi4l_s2m
  );
end entity axi4l_to_axi4l;

architecture behav of axi4l_to_axi4l is

begin

  po_m_ext     <= pi_s_decoder;
  po_s_decoder <= pi_m_ext;

end behav;
