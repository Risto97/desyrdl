-------------------------------------------------------------------------------
--          ____  _____________  __                                          --
--         / __ \/ ____/ ___/\ \/ /                 _   _   _                --
--        / / / / __/  \__ \  \  /                 / \ / \ / \               --
--       / /_/ / /___ ___/ /  / /               = ( M | S | K )=             --
--      /_____/_____//____/  /_/                   \_/ \_/ \_/               --
--                                                                           --
-------------------------------------------------------------------------------
-- $Header$
-------------------------------------------------------------------------------
--! @file   PKG_II.vhd
--! @brief  Internal Interface Package
--! @author Wojciech Jalmuzna
--! @author Lukasz Butkowski
--! @author Radoslaw Rybaniec
--! @author Andrea Bellandi
--! $Date$
--! $Revision$
--! $URL$
--! main II BASE with II ITEMS, added II ADAPTER for IBUS support with acknowledge
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

--! Basic definitions of IBUS

--! Internal BUS (IBUS) is the internal bus used in the applications of MSK Firmware
--! repository.
package PKG_II is

  --! Output signals of IBUS. Through this record the application send data/commands to the bus
  type t_ibus_m2s is record
    ADDR   : std_logic_vector(31 downto 0);
    DATA   : std_logic_vector(31 downto 0);
    RENA   : std_logic;
    WENA   : std_logic;
    CLK    : std_logic;
  end record t_ibus_m2s;

  --! Output signals of IBUS. Through this record the application send data/commands to the bus
  type t_ibus_s2m is record
    CLK    : std_logic;
    DATA   : std_logic_vector(31 downto 0);
    RACK   : std_logic;
    WACK   : std_logic;
  end record t_ibus_s2m;

  --! Array of IBUS outputs
  type t_ibus_m2s_ARRAY is array (natural range<>) of t_ibus_m2s;

  --! Array of IBUS inputs
  type t_ibus_s2m_ARRAY is array (natural range<>) of t_ibus_s2m;

  --! Default IBUS connections for the output (All entries equals 0)
  constant C_IBUS_M2S_DEFAULT : t_ibus_m2s := (ADDR => (others => '0'),
                                             DATA => (others => '0'),
                                             RENA => '0',
                                             WENA => '0',
                                             CLK  => '0');

  --! Default IBUS connections for the input (All entries equals 0)
  constant C_IBUS_S2M_DEFAULT : t_ibus_s2m := (CLK  => '0',
                                             DATA => (others => '0'),
                                             RACK => '0',
                                             WACK => '0');

end PKG_II;
