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
--! @file   reg_field_storage.vhd
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

entity reg_field_storage is
  generic (
            -- contains an array of field info
            g_info : t_field_info
          );
  port (
         pi_clock : in std_logic;
         pi_reset : in std_logic;
         -- to/from software
         pi_sw_we   : in std_logic;
         pi_sw_stb  : in std_logic;
         pi_sw_data : in std_logic_vector(g_info.len-1 downto 0);
         po_sw_data : out std_logic_vector(g_info.len-1 downto 0);
         -- to/from hardware logic
         pi_hw_we    : in std_logic;
         pi_hw_data  : in std_logic_vector(g_info.len-1 downto 0);
         po_hw_data  : out std_logic_vector(g_info.len-1 downto 0);
         po_hw_swmod : out std_logic
       );
end entity reg_field_storage;

architecture rtl of reg_field_storage is
  signal field_reg : std_logic_vector(g_info.len-1 downto 0);
begin

  -- check if the hardware side (logic) has a write enable signal
  -- or has no write access to the register
  gen_hw_we : if g_info.hw_we or g_info.hw_access = C_R or g_info.hw_access = C_NA generate
    prs_write : process(pi_clock)
    begin
      if rising_edge(pi_clock) then
        if pi_reset = '1' then
          field_reg <= g_info.def_val(g_info.len-1 downto 0);
          po_hw_swmod <= '0';
        else
          -- software write has precedence FIXME
          if pi_sw_stb = '1' and pi_sw_we = '1' and (g_info.sw_access = C_W or g_info.sw_access = C_RW) then
            -- TODO handle software access side effects (rcl/rset, woclr/woset, swacc/swmod)
            field_reg <= pi_sw_data;
            -- software access side effects
            po_hw_swmod <= '1';
            --po_hw_swmod <= '1' when g_info.swmod = True else '0';
          -- hardware write might get lost FIXME
          elsif pi_hw_we = '1' and (g_info.hw_access = C_W or g_info.hw_access = C_RW) then
            field_reg <= pi_hw_data;
            -- software access side effects
            po_hw_swmod <= '0';
          else
            field_reg <= field_reg;
            -- software access side effects
            po_hw_swmod <= '0';
          end if;
        end if;
      end if;
    end process;
  end generate;

  -- write from logic continuously if there is no write enable and hW has write
  -- access. Software cannot write in this case.
  -- TODO handle C_W1 and C_RW1
  gen_hw_no_we : if not g_info.hw_we and (g_info.hw_access = C_W or g_info.hw_access = C_RW) generate
    prs_write : process(pi_clock)
    begin
      if rising_edge(pi_clock) then
        if pi_reset = '1' then
          -- doesn't make so much sense here, does it?
          field_reg <= g_info.def_val(g_info.len-1 downto 0);
        else
          -- hardware writes all the time and software can only read
          field_reg <= pi_hw_data;
        end if;
      end if;
    end process;
  end generate;

  -- check for read access properties when assigning data outputs
  with g_info.hw_access select po_hw_data <=
    field_reg       when C_R,
    field_reg       when C_RW,
    field_reg       when C_RW1,
    (others => '0') when others;
  with g_info.sw_access select po_sw_data <=
    field_reg       when C_R,
    field_reg       when C_RW,
    field_reg       when C_RW1,
    (others => '0') when others;

end architecture;
