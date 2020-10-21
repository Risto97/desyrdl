library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.types.all;

package pkg_axi4 is
  constant C_ADDR_W : integer := 8;

  constant C_REGISTERS : integer := 1;

  -- address constants
  constant C_ADDR_WORD_FIRMWARE : integer := 0;
  constant C_ADDR_WORD_REVISION : integer := 1;
  constant C_ADDR_WORD_STATUS : integer := 2;

  constant C_ADDR_ARRAY : t_IntegerArray := (
    C_ADDR_WORD_FIRMWARE,
    C_ADDR_WORD_REVISION,
    C_ADDR_WORD_STATUS
  );

  -- field ranges constants
  constant C_FIELD_WORD_FIRMWARE_DATA_MSB : integer := 31;
  constant C_FIELD_WORD_FIRMWARE_DATA_LSB : integer := 0;
  constant C_FIELD_WORD_REVISION_DATA_MSB : integer := 31;
  constant C_FIELD_WORD_REVISION_DATA_LSB : integer := 0;
  constant C_FIELD_WORD_AMP_LIMIT_ACTIVE_DATA_MSB : integer := 4;
  constant C_FIELD_WORD_AMP_LIMIT_ACTIVE_DATA_LSB : integer := 0;
  constant C_FIELD_WORD_AMP_LIMIT_PRE_ACTIVE_DATA_MSB : integer := 4;
  constant C_FIELD_WORD_AMP_LIMIT_PRE_ACTIVE_DATA_LSB : integer := 0;
  constant C_FIELD_WORD_AMP_LIMIT_TRG_ACTIVE_DATA_MSB : integer := 4;
  constant C_FIELD_WORD_AMP_LIMIT_TRG_ACTIVE_DATA_LSB : integer := 0;

--  type t_dpm_list is record
--    base_array : t_IntegerArray(0 to C_MEMORIES-1);
--    width_array : t_IntegerArray(0 to C_MEMORIES-1);
--  end record t_dpm_list;
--
--  constant C_DPM_ARRAY : t_dpm_list := (
--    (C_ADDR_AREA_SIN, C_ADDR_AREA_COS),
--    (C_WIDTH_AREA_SIN, C_WIDTH_AREA_COS)
--  );
--
--  type t_dpm_array_i is record
--    ena  : std_logic;
--    wr   : std_logic;
--    addr : std_logic_vector(C_ADDR_W-1 downto 0);
--    data : std_logic_vector(32-1 downto 0);
--  end record t_dpm_array;

  type t_register_word_firmware is record
    data : std_logic_vector(C_FIELD_WORD_FIRMWARE_DATA_MSB downto C_FIELD_WORD_FIRMWARE_DATA_LSB);
  end record;
  type t_register_word_revision is record
    data : std_logic_vector(C_FIELD_WORD_REVISION_DATA_MSB downto C_FIELD_WORD_REVISION_DATA_LSB);
  end record;
  type t_register_word_amp_limit_active is record
    data : std_logic_vector(C_FIELD_WORD_AMP_LIMIT_ACTIVE_DATA_MSB downto C_FIELD_WORD_AMP_LIMIT_ACTIVE_DATA_LSB);
  end record;

  type t_register_arr is record
    WORD_FIRMWARE : t_register_word_firmware;
    WORD_REVISION : t_register_word_revision;
    WORD_AMP_LIMIT_ACTIVE : t_register_word_amp_limit_active;
  end record;

  --type t_field_access is (R, W, RW, NA);
  subtype t_field_access is std_logic_vector(1 downto 0);
  constant C_RW : std_logic_vector(1 downto 0) := "11";
  constant C_R  : std_logic_vector(1 downto 0) := "10";
  constant C_W  : std_logic_vector(1 downto 0) := "01";
  constant C_NA : std_logic_vector(1 downto 0) := "00";

  type t_field_storage_info is record
    len   : integer;
    upper : integer;
    lower : integer;
    hw_we : boolean;
    sw_access : t_field_access;
    hw_access : t_field_access;
    def_val : std_logic_vector(32-1 downto 0);
  end record;
  type t_field_storage_info_arr is array (integer range 31 downto 0) of t_field_storage_info;
  constant C_FIELD_NONE : t_field_storage_info := (0, 0, 0, false, C_NA, C_NA, (others => '0'));

  --
  -- this is only one specific register
  --
  constant C_WHATEVER_INFO : t_field_storage_info_arr := (
    (len => 16, upper => 31, lower => 16, hw_we => false, sw_access => C_RW, hw_access => C_R,  def_val => (others => '1')),
    (len => 8,  upper => 15, lower =>  8, hw_we => true,  sw_access => C_R , hw_access => C_RW, def_val => (others => '1')),
    (len => 8,  upper =>  7, lower =>  0, hw_we => true,  sw_access => C_RW, hw_access => C_RW, def_val => (others => '1')),
    others => C_FIELD_NONE
  );

  constant C_ANOTHER_INFO : t_field_storage_info_arr := (
    (len => 16, upper => 31, lower => 16, hw_we => false, sw_access => C_RW, hw_access => C_R,  def_val => (others => '1')),
    (len => 16, upper => 15, lower =>  0, hw_we => true,  sw_access => C_R , hw_access => C_W,  def_val => (others => '1')),
    others => C_FIELD_NONE
  );

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
  end record;
  type t_field_info_arr is array (integer range <>) of t_field_info;

  type t_field_signals_in is record
    data : std_logic_vector; -- VHDL-2008 - check if Vivado can simulate this
    we : std_logic;
    incr : std_logic;
    decr : std_logic;
  end record;

  type t_field_signals_out is record
    data : std_logic_vector; -- VHDL-2008
    we : std_logic;
    incr : std_logic;
    decr : std_logic;
  end record;

  --
  -- below: per regfile / module !
  --

  type t_regtype is (WHATEVER, ANOTHER);

  type t_reg_info is record
    regtype : t_regtype;
    fields  : t_field_storage_info_arr;
    N       : positive;
    M       : positive;
  end record;
  type t_reg_info_array is array (integer range <>) of t_reg_info;
  constant C_REGISTER_INFO : t_reg_info_array := (
    (regtype => WHATEVER, fields => C_WHATEVER_INFO, N => 1, M => 2),
    (regtype => ANOTHER, fields => C_ANOTHER_INFO, N => 1, M => 1)
    --(WHATEVER, C_WHATEVER_INFO)
  );

  -- contains up to 32 data bits plus the other signals (we, incr, ..)
  type t_reg_whatever_in is record
    -- fields
    foo : t_field_signals_in(data(C_WHATEVER_INFO(0).len-1 downto 0));
    bar : t_field_signals_in(data(C_WHATEVER_INFO(1).len-1 downto 0));
    baz : t_field_signals_in(data(C_WHATEVER_INFO(2).len-1 downto 0));
  end record;
  type t_reg_whatever_2d_in is array (natural range C_REGISTER_INFO(0).M downto 0) of t_reg_whatever_in;
  type t_reg_whatever_3d_in is array (natural range C_REGISTER_INFO(0).N downto 0) of t_reg_whatever_2d_in;

  type t_reg_whatever_out is record
    -- fields
    foo : t_field_signals_out(data(C_WHATEVER_INFO(0).len-1 downto 0));
    bar : t_field_signals_out(data(C_WHATEVER_INFO(1).len-1 downto 0));
    baz : t_field_signals_out(data(C_WHATEVER_INFO(2).len-1 downto 0));
  end record;
  type t_reg_whatever_2d_out is array (natural range C_REGISTER_INFO(0).M downto 0) of t_reg_whatever_out;
  type t_reg_whatever_3d_out is array (natural range C_REGISTER_INFO(0).N downto 0) of t_reg_whatever_2d_out;

  --
  -- below: data I/O type definitions
  --

  type t_registers_modname_in is record
    --wawah : t_reg_wawah_in;
    --uaohh : t_reg_uaohh_in;
    whatever : t_reg_whatever_3d_in;
  end record;

  type t_registers_modname_out is record
    --wawah : t_reg_wawah_out;
    --uaohh : t_reg_uaohh_out;
    whatever : t_reg_whatever_3d_out;
  end record;

  function fun_slv_to_whatever (slv : std_logic_vector(32-1 downto 0)) return t_reg_whatever_out;
  function fun_whatever_to_data (reg : t_reg_whatever_in) return std_logic_vector;
  function fun_logic_to_data ( reg_info : t_reg_info ; regs : t_registers_modname_in ; i,j : integer ) return std_logic_vector;
  function fun_logic_to_decr ( reg_info : t_reg_info ; regs : t_registers_modname_in ; i,j : integer ) return std_logic_vector;

end pkg_axi4;

package body pkg_axi4 is

  --
  -- functions
  --

  -- unpack
  function fun_slv_to_whatever (slv : std_logic_vector(32-1 downto 0)) return t_reg_whatever_out is
    variable v_tmp : t_reg_whatever_out;
  begin
    v_tmp.foo.data := slv(C_WHATEVER_INFO(0).upper downto C_WHATEVER_INFO(0).lower);
    v_tmp.bar.data := slv(C_WHATEVER_INFO(1).upper downto C_WHATEVER_INFO(1).lower);
    v_tmp.baz.data := slv(C_WHATEVER_INFO(2).upper downto C_WHATEVER_INFO(2).lower);

    return v_tmp;
  end function;

  -- pack
  function fun_whatever_to_data (reg : t_reg_whatever_in) return std_logic_vector is
    variable v_tmp : std_logic_vector(32-1 downto 0);
  begin
    v_tmp(C_WHATEVER_INFO(0).upper downto C_WHATEVER_INFO(0).lower) := reg.foo.data;
    v_tmp(C_WHATEVER_INFO(1).upper downto C_WHATEVER_INFO(1).lower) := reg.bar.data;
    v_tmp(C_WHATEVER_INFO(2).upper downto C_WHATEVER_INFO(2).lower) := reg.baz.data;

    return v_tmp;
  end function;

  function fun_logic_to_data ( reg_info : t_reg_info ; regs : t_registers_modname_in ; i,j : integer ) return std_logic_vector is
    variable v_tmp : std_logic_vector(32-1 downto 0);
  begin
    case reg_info.regtype is
      when WHATEVER =>
        v_tmp := fun_whatever_to_data(regs.whatever(i)(j));
        --v_tmp(reg_info.fields(<x>).upper downto reg_info.fields(<x>).lower) := regs.regname(i)(j).<fieldname>.data;
        v_tmp(reg_info.fields(0).upper downto reg_info.fields(0).lower) := regs.whatever(i)(j).foo.data;
        v_tmp(reg_info.fields(1).upper downto reg_info.fields(1).lower) := regs.whatever(i)(j).bar.data;
        v_tmp(reg_info.fields(2).upper downto reg_info.fields(2).lower) := regs.whatever(i)(j).baz.data;
      when others =>
        v_tmp := (others => '0');
    end case;

    return v_tmp;
  end function;

  function fun_logic_to_decr ( reg_info : t_reg_info ; regs : t_registers_modname_in ; i,j : integer ) return std_logic_vector is
    variable v_tmp : std_logic_vector(32-1 downto 0);
  begin
    case reg_info.regtype is
      when WHATEVER =>
        v_tmp(0) := regs.whatever(i)(j).foo.decr when C_WHATEVER_INFO(0).hw_we else '0'; -- FIXME?
        v_tmp(1) := regs.whatever(i)(j).bar.decr when C_WHATEVER_INFO(1).hw_we else '0'; -- FIXME?
        v_tmp(2) := regs.whatever(i)(j).baz.decr when C_WHATEVER_INFO(2).hw_we else '0'; -- FIXME?
      when others =>
        v_tmp := (others => '0');
    end case;

    return v_tmp;
  end function;

end package body;
