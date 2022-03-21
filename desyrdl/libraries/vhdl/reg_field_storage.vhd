-------------------------------------------------------------------------------
--          ____  _____________  __                                          --
--         / __ \/ ____/ ___/\ \/ /                 _   _   _                --
--        / / / / __/  \__ \  \  /                 / \ / \ / \               --
--       / /_/ / /___ ___/ /  / /               = ( M | S | K )=             --
--      /_____/_____//____/  /_/                   \_/ \_/ \_/               --
--                                                                           --
-------------------------------------------------------------------------------
--! @copyright Copyright 2021 DESY
--! SPDX-License-Identifier: Apache-2.0
-------------------------------------------------------------------------------
--! @date 2021-08-04
--! @author Michael Büchler <michael.buechler@desy.de>
--! @author Lukasz Butkowski <lukasz.butkowski@desy.de>
-------------------------------------------------------------------------------
--! @brief Storage field component of DesyRDL
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library desyrdl;
use desyrdl.common.all;

entity reg_field_storage is
  generic (
    -- contains an array of field info
    g_info : t_field_info
  );
  port (
    pi_clock : in std_logic;
    pi_reset : in std_logic;
    -- to/from software
    pi_sw_rd_stb : in std_logic;
    pi_sw_wr_stb : in std_logic;
    pi_sw_data   : in std_logic_vector(g_info.len-1 downto 0);
    po_sw_data   : out std_logic_vector(g_info.len-1 downto 0);
    -- to/from hardware logic
    pi_hw_we    : in std_logic;
    pi_hw_data  : in std_logic_vector(g_info.len-1 downto 0);
    po_hw_data  : out std_logic_vector(g_info.len-1 downto 0);
    po_hw_swmod : out std_logic;
    po_hw_swacc : out std_logic
  );
end entity reg_field_storage;

architecture rtl of reg_field_storage is
  signal field_reg   : std_logic_vector(g_info.len-1 downto 0);
  signal sw_wr_stb_q : std_logic;
  signal sw_rd_stb_q : std_logic;
begin

  -- check if the hardware side (logic) has a write enable signal
  -- or has no write access to the register
  gen_hw_we : if g_info.we = 1 or g_info.hw = C_R or g_info.hw = C_NA generate
    prs_write : process(pi_clock)
    begin
      if rising_edge(pi_clock) then
        if pi_reset = '1' then
          field_reg <= std_logic_vector(to_unsigned(g_info.defval, g_info.len));
          po_hw_swmod <= '0';
          po_hw_swacc <= '0';
          sw_wr_stb_q <= '0';
          sw_rd_stb_q <= '0';
        else
          -- software write has precedence FIXME
          -- TODO handle software access side effects (rcl/rset, woclr/woset, swacc/swmod)
          if pi_sw_wr_stb = '1' and (g_info.sw = C_W or g_info.sw = C_RW) then
            field_reg <= pi_sw_data;
            -- software access side effects
            sw_wr_stb_q <= '1';
            --po_hw_swmod <= '1' when g_info.swmod = True else '0';
          -- hardware write might get lost FIXME
          elsif pi_hw_we = '1' and (g_info.hw = C_W or g_info.hw = C_RW) then
            field_reg <= pi_hw_data;
            -- software access side effects
            sw_wr_stb_q <= '0';
          else
            field_reg <= field_reg;
            -- software access side effects
            sw_wr_stb_q <= '0';
          end if;

          if pi_sw_rd_stb = '1' and (g_info.sw = C_R or g_info.sw = C_RW) then
            sw_rd_stb_q <= '1';
          else
            sw_rd_stb_q <= '0';
          end if;

          -- generate sw modified and sw accessed only for 1 clock cycle
          if sw_wr_stb_q = '0' and pi_sw_wr_stb = '1'  and (g_info.sw = C_W or g_info.sw = C_RW) then
            po_hw_swmod <= '1';
            po_hw_swacc <= '1';
          elsif sw_rd_stb_q = '0' and pi_sw_rd_stb = '1' and (g_info.sw = C_R or g_info.sw = C_RW) then
            po_hw_swmod <= '0';
            po_hw_swacc <= '1';
          else
            po_hw_swmod <= '0';
            po_hw_swacc <= '0';
          end if;

        end if;
      end if;
    end process;
  end generate;

  -- write from logic continuously if there is no write enable and hW has write
  -- access. Software cannot write in this case.
  -- TODO handle C_W1 and C_RW1
  gen_hw_no_we : if g_info.we = 0 and (g_info.hw = C_W or g_info.hw = C_RW) generate
    prs_write : process(pi_clock)
    begin
      if rising_edge(pi_clock) then
        if pi_reset = '1' then
          -- doesn't make so much sense here, does it?
          --field_reg <= std_logic_vector(to_unsigned(g_info.defval, g_info.len));
          field_reg <= (others => '0');
          po_hw_swmod <= '0';
          po_hw_swacc <= '0';
          sw_wr_stb_q <= '0';
          sw_rd_stb_q <= '0';
        else
          -- hardware writes all the time and software can only read
          field_reg <= pi_hw_data;
          -- generate sw modified and sw accessed only for 1 clock cycle
          if sw_wr_stb_q = '0' and pi_sw_wr_stb = '1'  and (g_info.sw = C_W or g_info.sw = C_RW) then
            po_hw_swmod <= '1';
            po_hw_swacc <= '1';
          elsif sw_rd_stb_q = '0' and pi_sw_rd_stb = '1' and (g_info.sw = C_R or g_info.sw = C_RW) then
            po_hw_swmod <= '0';
            po_hw_swacc <= '1';
          else
            po_hw_swmod <= '0';
            po_hw_swacc <= '0';
          end if;
        end if;
      end if;
    end process;
  end generate;

  -- check for read access properties when assigning data outputs
  with g_info.hw select po_hw_data <=
    field_reg       when C_R,
    field_reg       when C_RW,
    field_reg       when C_RW1,
    (others => '0') when others;
  with g_info.sw select po_sw_data <=
    field_reg       when C_R,
    field_reg       when C_RW,
    field_reg       when C_RW1,
    (others => '0') when others;

end architecture;
