-- Copyright (c) 2020-2021 Deutsches Elektronen-Synchrotron DESY.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

package pkg_reg_common is
  -----------------------------------------------
  -- below: common declarations
  -----------------------------------------------

  --type t_field_access is (R, W, RW, NA);
  subtype t_field_access is integer;
  constant C_RW  : integer := 2;
  constant C_RW1 : integer := 5;
  constant C_R   : integer := 3;
  constant C_W   : integer := 4;
  constant C_W1  : integer := 6;
  constant C_NA  : integer := 1;

  type t_field_type is (STORAGE, WIRE, COUNTER, INTERRUPT);

  type t_field_info is record
    ftype : t_field_type;
    len   : integer;
    upper : integer;
    lower : integer;
    hw_we : boolean;
    sw_access : t_field_access;
    hw_access : t_field_access;
    def_val : std_logic_vector(32-1 downto 0);
    incrwidth : integer;
    decrwidth : integer;
  end record;
  type t_field_info_arr is array (integer range 31 downto 0) of t_field_info;
  constant C_FIELD_NONE : t_field_info := (WIRE, 0, 0, 0, false, C_NA, C_NA, (others => '0'), 0, 0);

  type t_reg_info is record
    addr    : integer;
    base    : integer;
    fields  : t_field_info_arr;
    N       : positive;
    M       : positive;
  end record;
  constant C_REG_NONE : t_reg_info := (0, 0, (others => C_FIELD_NONE), 1, 1);

  -- Maybe better to constrain t_reg_info_array. Vivado shows weird indices when unconstrained.
  -- Must be the number of distinct register names, not one for each 2D/3D array element!
  --type t_reg_info_array is array (0 to C_REGNAMES) of t_reg_info;
  type t_reg_info_array is array (natural range <>) of t_reg_info;


  -- We can't have VHDL-2008 at the moment but maybe at some point we will
--  type t_field_signals_in is record
--    data : std_logic_vector; -- VHDL-2008
--    we : std_logic;
--    incr : std_logic;
--    decr : std_logic;
--  end record;
--  type t_field_signals_out is record
--    data : std_logic_vector; -- VHDL-2008
--    swacc : std_logic;
--    swmod : std_logic;
--  end record;

  constant C_ADDR_W : integer := 32;

  type t_mem_in is record
    ena  : std_logic;
    wr   : std_logic;
    addr : std_logic_vector(C_ADDR_W-2-1 downto 0);
    data : std_logic_vector(32-1 downto 0);
  end record t_mem_in;
  type t_mem_in_arr is array (natural range <>) of t_mem_in;

  -- TODO make this a record as well just to stay consistent
  subtype t_mem_out is std_logic_vector(32-1 downto 0);
  type t_mem_out_arr is array (natural range <>) of t_mem_out;

end package pkg_reg_common;

package body pkg_reg_common is
end package body;
