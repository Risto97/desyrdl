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
--! @file   register32.vhd
--! @brief  Generic register component
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
use work.common.all;

entity desy_register is
  generic (
            g_fields : t_field_info_arr
          );
  port (
         pi_clock : in std_logic;
         pi_reset : in std_logic;
         -- to/from adapter
         pi_adapter_stb : in std_logic;
         pi_adapter_we  : in std_logic;
         po_adapter_err : out std_logic;
         pi_adapter_data : in std_logic_vector(32-1 downto 0);
         po_adapter_data : out std_logic_vector(32-1 downto 0);

         -- to/from our IP
         pi_logic_incr : in std_logic_vector(32-1 downto 0);
         pi_logic_decr : in std_logic_vector(32-1 downto 0);
         pi_logic_we   : in std_logic_vector(32-1 downto 0);
         pi_logic_data : in std_logic_vector(32-1 downto 0);
         -- TODO add swmod/swacc signals
         po_logic_data : out std_logic_vector(32-1 downto 0);
         po_logic_swmod : out std_logic_vector(32-1 downto 0)
       );
end entity desy_register;

architecture rtl of desy_register is
begin

  -- on a strobe, write to all fields --> one signal for the register (storage)
  -- but respect the write mask (generate for each bit)

  -- TODO implement in fields
  po_adapter_err <= '0';

  gen_fields : for f in g_fields'range generate
    constant field : t_field_info := g_fields(f);
  begin
    -- storage type fields
    gen_storage : if field.ftype = STORAGE generate
      ins_field_storage : entity work.reg_field_storage
      generic map(
                   g_info => field
                 )
      port map (
                 pi_clock   => pi_clock,
                 pi_reset   => pi_reset,
                 pi_sw_stb  => pi_adapter_stb,
                 pi_sw_we   => pi_adapter_we,
                 pi_sw_data => pi_adapter_data(field.upper downto field.lower),
                 po_sw_data => po_adapter_data(field.upper downto field.lower),
                 pi_hw_we   => pi_logic_we(f),
                 pi_hw_data => pi_logic_data(field.upper downto field.lower),
                 po_hw_data => po_logic_data(field.upper downto field.lower),
                 po_hw_swmod => po_logic_swmod(f)
               );
    end generate;

--    -- wire type fields
--    for f in C_REGNAME_FIELDS_WIRE generate
--      constant field : t_field_wire := C_REGNAME_FIELDS_WIRE(f);
--    begin
--      ins_field_wire : entity work.reg_field_wire
--      generic map(
--                   g_info => field.info
--                 )
--      port map (
--                 po_sw_data => po_adapter_data(field.upper downto field.lower),
--                 pi_hw_data => pi_logic_data.data(field.upper downto field.lower),
--                 po_hw_data => po_logic_data.data(field.upper downto field.lower)
--               );
--    end generate;
--
    -- counter type fields
    gen_counter : if field.ftype = COUNTER generate
    begin
      ins_field_counter : entity work.reg_field_counter
      generic map(
                   g_info => field
                 )
      port map (
                 pi_clock   => pi_clock,
                 pi_reset   => pi_reset,
                 pi_sw_stb  => pi_adapter_stb,
                 po_sw_data => po_adapter_data(field.upper downto field.lower),
                 po_hw_data => po_logic_data(field.upper downto field.lower),
                 po_hw_swmod => po_logic_swmod(f),
                 po_hw_overflow => open,
                 po_hw_underflow => open,
                 pi_hw_incr => pi_logic_incr(f),
                 pi_hw_decr => pi_logic_decr(f),
                 pi_hw_incrvalue => (others => '1'),
                 pi_hw_decrvalue => (others => '1')
               );
    end generate;
  end generate gen_fields;
end architecture;
