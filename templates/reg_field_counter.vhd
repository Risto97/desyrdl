-------------------------------------------------------------------------------
--          ____  _____________  __                                          --
--         / __ \/ ____/ ___/\ \/ /                 _   _   _                --
--        / / / / __/  \__ \  \  /                 / \ / \ / \               --
--       / /_/ / /___ ___/ /  / /               = ( M | S | K )=             --
--      /_____/_____//____/  /_/                   \_/ \_/ \_/               --
--                                                                           --
-------------------------------------------------------------------------------
-- $Header: https://mskllrfredminesrv.desy.de/svn/utca_firmware_framework/branch/llrf_iq_rework/libraries/dsp/iq_slide.vhd 4109 2020-08-26 17:52:31Z mbuechl $
-------------------------------------------------------------------------------
--! @file   reg_field_counter.vhd
--! @brief  Storage type of a field. Part of MSK register generation.
--! @author Michael Buechler
--! @email  michael.buechler@desy.de
--! $Date: 2020-08-26 19:52:31 +0200 (Mi, 26 Aug 2020) $
--! $Revision: 4109 $
--! $URL: https://mskllrfredminesrv.desy.de/svn/utca_firmware_framework/branch/llrf_iq_rework/libraries/dsp/iq_slide.vhd $
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg_reg_common.all;

entity reg_field_counter is
  generic (
            -- contains an array of field info
            g_info : t_field_info
          );
  port (
         pi_clock : in std_logic;
         pi_reset : in std_logic;
         -- to/from software
         pi_sw_stb  : in std_logic;
         po_sw_data : out std_logic_vector(g_info.len-1 downto 0);
         -- to/from hardware logic
         po_hw_data : out std_logic_vector(g_info.len-1 downto 0);
         po_hw_swmod : out std_logic;
         -- counter-related
         po_hw_overflow : out std_logic;
         po_hw_underflow : out std_logic;
         pi_hw_incr : in std_logic;
         pi_hw_decr : in std_logic;
         pi_hw_decrvalue : in std_logic_vector(g_info.decrwidth-1 downto 0);
         pi_hw_incrvalue : in std_logic_vector(g_info.incrwidth-1 downto 0)
       );
end entity reg_field_counter;

architecture rtl of reg_field_counter is
  signal instruction : std_logic_vector(3 downto 0);
  signal counter : unsigned(g_info.len-1 downto 0);
  signal overflow, underflow : std_logic;
begin

  -- TODO implement clear on read using pi_sw_stb

  overflow <= '0'; -- TODO
  underflow <= '0'; -- TODO
  po_hw_overflow <= overflow;
  po_hw_underflow <= underflow;
  instruction <= overflow & underflow & pi_hw_incr & pi_hw_decr;

  prs_counter : process(pi_clock)
  begin
    if rising_edge(pi_clock) then
      if pi_reset = '1' then
          counter <= unsigned(g_info.def_val(g_info.len-1 downto 0));
      else
        case instruction is
          when "0010" =>
            counter <= counter+1;
          when "0001" =>
            counter <= counter-1;
          when others =>
            counter <= counter;
        end case;
      end if;
    end if;
  end process;

  po_hw_data <= std_logic_vector(counter);
  po_sw_data <= std_logic_vector(counter);
  po_hw_swmod <= '0';

end architecture;
