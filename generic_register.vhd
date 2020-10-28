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
--! @file   generic_register.vhd
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
use work.pkg_types.all;
use work.pkg_reg_marsupials.all; -- maybe rename to sth like pkg_axi4_<foocomponent>
--use work.pkg_registers_common.all;

entity generic_register is
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
         pi_logic_we   : in std_logic_vector(32-1 downto 0);
         pi_logic_data : in std_logic_vector(32-1 downto 0);
         po_logic_data : out std_logic_vector(32-1 downto 0)
       );
end entity generic_register;

architecture rtl of generic_register is
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
                 pi_hw_we   => pi_logic_we(f), -- TODO wrong?
                 pi_hw_data => pi_logic_data(field.upper downto field.lower),
                 po_hw_data => po_logic_data(field.upper downto field.lower)
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
--    -- counter type fields
--    for f in C_REGNAME_FIELDS_COUNTER'range generate
--      constant field : t_field_counter := C_REGNAME_FIELDS_COUNTER(f);
--    begin
--      ins_field_counter : entity work.reg_field_counter
--      generic map(
--                   g_info => field.info
--                 )
--      port map (
--                 pi_clock   => pi_clock,
--                 pi_reset   => pi_reset,
--                 pi_sw_stb  => pi_adapter_stb,
--                 po_sw_data => po_adapter_data(field.upper downto field.lower),
--                 po_hw_data => po_logic_data.data(field.upper downto field.lower),
--                 pi_hw_incr => pi_logic_data(field.incr)
--               );
--    end generate;
  end generate gen_fields;
end architecture;
