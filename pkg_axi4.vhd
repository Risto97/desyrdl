library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg_types.all;

package pkg_axi4 is
  constant C_ADDR_W : integer := 8;

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

  --type t_field_access is (R, W, RW, NA);
  subtype t_field_access is std_logic_vector(1 downto 0);
  constant C_RW : std_logic_vector(1 downto 0) := "11";
  constant C_R  : std_logic_vector(1 downto 0) := "10";
  constant C_W  : std_logic_vector(1 downto 0) := "01";
  constant C_NA : std_logic_vector(1 downto 0) := "00";

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
  type t_field_info_arr is array (integer range 31 downto 0) of t_field_info;
  constant C_FIELD_NONE : t_field_info := (WIRE, 0, 0, 0, false, C_NA, C_NA, (others => '0'));

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

  constant C_REGNAMES  : integer := 2;
  constant C_REGISTERS : integer := 3;

  -- register types

  type t_regtype is (WOMBAT, KOALA);

  type t_reg_info is record
    addr    : integer;
    regtype : t_regtype;
    fields  : t_field_info_arr;
    N       : positive;
    M       : positive;
  end record;
  -- Maybe better to constrain t_reg_info_array. Vivado shows weird indices when unconstrained.
  -- Must be the number of distinct register names, not one for each 2D/3D array element!
  type t_reg_info_array is array (0 to C_REGNAMES-1) of t_reg_info;

  constant C_WOMBAT_INFO : t_field_info_arr := (
    0 => (ftype => STORAGE, len => 16, upper => 31, lower => 16, hw_we => false, sw_access => C_RW, hw_access => C_R,  def_val => (others => '1')),
    1 => (ftype => STORAGE, len => 8,  upper => 15, lower =>  8, hw_we => true,  sw_access => C_R , hw_access => C_RW, def_val => (others => '1')),
    2 => (ftype => STORAGE, len => 8,  upper =>  7, lower =>  0, hw_we => true,  sw_access => C_RW, hw_access => C_RW, def_val => (others => '1')),
    others => C_FIELD_NONE
  );

  constant C_KOALA_INFO : t_field_info_arr := (
    0 => (ftype => STORAGE, len => 16, upper => 31, lower => 16, hw_we => false, sw_access => C_RW, hw_access => C_R,  def_val => (others => '1')),
    1 => (ftype => STORAGE, len => 16, upper => 15, lower =>  0, hw_we => true,  sw_access => C_R , hw_access => C_W,  def_val => (others => '1')),
    others => C_FIELD_NONE
  );

  constant C_REGISTER_INFO : t_reg_info_array := (
    0 => (addr => 16, regtype => WOMBAT, fields => C_WOMBAT_INFO, N => 1, M => 2),
    1 => (addr => 32, regtype => KOALA, fields => C_KOALA_INFO, N => 1, M => 1)
  );

  -- contains up to 32 data bits plus the other signals (we, incr, ..)
  type t_reg_wombat_in is record
    -- fields
    foo : t_field_signals_in(data(C_WOMBAT_INFO(0).len-1 downto 0));
    bar : t_field_signals_in(data(C_WOMBAT_INFO(1).len-1 downto 0));
    baz : t_field_signals_in(data(C_WOMBAT_INFO(2).len-1 downto 0));
  end record;
  type t_reg_wombat_2d_in is array (integer range <>) of t_reg_wombat_in;
  type t_reg_wombat_3d_in is array (integer range <>, integer range <>) of t_reg_wombat_in;

  type t_reg_wombat_out is record
    -- fields
    foo : t_field_signals_out(data(C_WOMBAT_INFO(0).len-1 downto 0));
    bar : t_field_signals_out(data(C_WOMBAT_INFO(1).len-1 downto 0));
    baz : t_field_signals_out(data(C_WOMBAT_INFO(2).len-1 downto 0));
  end record;
  type t_reg_wombat_2d_out is array (integer range <>) of t_reg_wombat_out;
  type t_reg_wombat_3d_out is array (integer range <>, integer range <>) of t_reg_wombat_out;

  -- contains up to 32 data bits plus the other signals (we, incr, ..)
  type t_reg_koala_in is record
    -- fields
    hp : t_field_signals_in(data(C_KOALA_INFO(0).len-1 downto 0));
    mana : t_field_signals_in(data(C_KOALA_INFO(1).len-1 downto 0));
  end record;
  type t_reg_koala_2d_in is array (integer range <>) of t_reg_koala_in;
  type t_reg_koala_3d_in is array (integer range <>, integer range <>) of t_reg_koala_in;

  type t_reg_koala_out is record
    -- fields
    hp : t_field_signals_out(data(C_KOALA_INFO(0).len-1 downto 0));
    mana : t_field_signals_out(data(C_KOALA_INFO(1).len-1 downto 0));
  end record;
  type t_reg_koala_2d_out is array (integer range <>) of t_reg_koala_out;
  type t_reg_koala_3d_out is array (integer range <>, integer range <>) of t_reg_koala_out;

  --
  -- below: data I/O type definitions
  --

  type t_registers_marsupials_in is record
    --wawah : t_reg_wawah_in;
    --uaohh : t_reg_uaohh_in;
    wombat : t_reg_wombat_3d_in(0 to C_REGISTER_INFO(0).N-1, 0 to C_REGISTER_INFO(0).M-1);
    koala  : t_reg_koala_3d_in(0 to C_REGISTER_INFO(1).N-1, 0 to C_REGISTER_INFO(1).M-1);
  end record;

  type t_registers_marsupials_out is record
    --wawah : t_reg_wawah_out;
    --uaohh : t_reg_uaohh_out;
    wombat : t_reg_wombat_3d_out(0 to C_REGISTER_INFO(0).N-1, 0 to C_REGISTER_INFO(0).M-1);
    koala  : t_reg_koala_3d_out(0 to C_REGISTER_INFO(1).N-1, 0 to C_REGISTER_INFO(1).M-1);
  end record;

  -- functions for wombat
  function fun_slv_to_wombat (slv : std_logic_vector(32-1 downto 0)) return t_reg_wombat_out;
  function fun_wombat_to_data (reg : t_reg_wombat_in) return std_logic_vector;
  function fun_logic_to_data ( reg_info : t_reg_info ; regs : t_registers_marsupials_in ; i,j : integer ) return std_logic_vector;
  function fun_logic_to_decr ( reg_info : t_reg_info ; regs : t_registers_marsupials_in ; i,j : integer ) return std_logic_vector;
  function fun_logic_to_incr ( reg_info : t_reg_info ; regs : t_registers_marsupials_in ; i,j : integer ) return std_logic_vector;
  function fun_logic_to_we ( reg_info : t_reg_info ; regs : t_registers_marsupials_in ; i,j : integer ) return std_logic_vector;

  -- functions for koala
  function fun_slv_to_koala (slv : std_logic_vector(32-1 downto 0)) return t_reg_koala_out;
  function fun_koala_to_data (reg : t_reg_koala_in) return std_logic_vector;
  function fun_koala_to_decr (reg : t_reg_koala_in) return std_logic_vector;
  function fun_koala_to_incr (reg : t_reg_koala_in) return std_logic_vector;
  function fun_koala_to_we   (reg : t_reg_koala_in) return std_logic_vector;
end pkg_axi4;

package body pkg_axi4 is

  --
  -- functions
  --

  -- unpack
  function fun_slv_to_wombat (slv : std_logic_vector(32-1 downto 0)) return t_reg_wombat_out is
    variable v_tmp : t_reg_wombat_out;
  begin
    v_tmp.foo.data := slv(C_WOMBAT_INFO(0).upper downto C_WOMBAT_INFO(0).lower);
    v_tmp.bar.data := slv(C_WOMBAT_INFO(1).upper downto C_WOMBAT_INFO(1).lower);
    v_tmp.baz.data := slv(C_WOMBAT_INFO(2).upper downto C_WOMBAT_INFO(2).lower);

    return v_tmp;
  end function;

  -- pack
  function fun_wombat_to_data (reg : t_reg_wombat_in) return std_logic_vector is
    variable v_tmp : std_logic_vector(32-1 downto 0);
  begin
    v_tmp(C_WOMBAT_INFO(0).upper downto C_WOMBAT_INFO(0).lower) := reg.foo.data;
    v_tmp(C_WOMBAT_INFO(1).upper downto C_WOMBAT_INFO(1).lower) := reg.bar.data;
    v_tmp(C_WOMBAT_INFO(2).upper downto C_WOMBAT_INFO(2).lower) := reg.baz.data;

    return v_tmp;
  end function;

  function fun_logic_to_data ( reg_info : t_reg_info ; regs : t_registers_marsupials_in ; i,j : integer ) return std_logic_vector is
    variable v_tmp : std_logic_vector(32-1 downto 0);
  begin
    case reg_info.regtype is
      when WOMBAT =>
        v_tmp := fun_wombat_to_data(regs.wombat(i,j));
        --v_tmp(reg_info.fields(<x>).upper downto reg_info.fields(<x>).lower) := regs.regname(i,j).<fieldname>.data;
        v_tmp(reg_info.fields(0).upper downto reg_info.fields(0).lower) := regs.wombat(i,j).foo.data;
        v_tmp(reg_info.fields(1).upper downto reg_info.fields(1).lower) := regs.wombat(i,j).bar.data;
        v_tmp(reg_info.fields(2).upper downto reg_info.fields(2).lower) := regs.wombat(i,j).baz.data;
      when others =>
        v_tmp := (others => '0');
    end case;

    return v_tmp;
  end function;

  function fun_logic_to_decr ( reg_info : t_reg_info ; regs : t_registers_marsupials_in ; i,j : integer ) return std_logic_vector is
    variable v_tmp : std_logic_vector(32-1 downto 0);
  begin
    case reg_info.regtype is
      when WOMBAT =>
        v_tmp(0) := regs.wombat(i,j).foo.decr ; -- FIXME?
        v_tmp(1) := regs.wombat(i,j).bar.decr ; -- FIXME?
        v_tmp(2) := regs.wombat(i,j).baz.decr ; -- FIXME?
      when others =>
        v_tmp := (others => '0');
    end case;

    return v_tmp;
  end function;

  function fun_logic_to_incr ( reg_info : t_reg_info ; regs : t_registers_marsupials_in ; i,j : integer ) return std_logic_vector is
    variable v_tmp : std_logic_vector(32-1 downto 0);
  begin
    case reg_info.regtype is
      when WOMBAT =>
        v_tmp(0) := regs.wombat(i,j).foo.incr when C_WOMBAT_INFO(0).hw_we else '0'; -- FIXME
        v_tmp(1) := regs.wombat(i,j).bar.incr when C_WOMBAT_INFO(1).hw_we else '0'; -- FIXME
        v_tmp(2) := regs.wombat(i,j).baz.incr when C_WOMBAT_INFO(2).hw_we else '0'; -- FIXME
      when others =>
        v_tmp := (others => '0');
    end case;

    return v_tmp;
  end function;

  function fun_logic_to_we ( reg_info : t_reg_info ; regs : t_registers_marsupials_in ; i,j : integer ) return std_logic_vector is
    variable v_tmp : std_logic_vector(32-1 downto 0);
  begin
    case reg_info.regtype is
      when WOMBAT =>
        v_tmp(0) := regs.wombat(i,j).foo.we when C_WOMBAT_INFO(0).hw_we else '0'; -- FIXME?
        v_tmp(1) := regs.wombat(i,j).bar.we when C_WOMBAT_INFO(1).hw_we else '0'; -- FIXME?
        v_tmp(2) := regs.wombat(i,j).baz.we when C_WOMBAT_INFO(2).hw_we else '0'; -- FIXME?
      when others =>
        v_tmp := (others => '0');
    end case;

    return v_tmp;
  end function;

  -- for koala
  -- unpack
  function fun_slv_to_koala (slv : std_logic_vector(32-1 downto 0)) return t_reg_koala_out is
    variable v_tmp : t_reg_koala_out;
  begin
    v_tmp.hp.data := slv(C_KOALA_INFO(0).upper downto C_KOALA_INFO(0).lower);
    v_tmp.mana.data := slv(C_KOALA_INFO(1).upper downto C_KOALA_INFO(1).lower);

    return v_tmp;
  end function;

  -- pack
  function fun_koala_to_data (reg : t_reg_koala_in) return std_logic_vector is
    variable v_tmp : std_logic_vector(32-1 downto 0);
  begin
    v_tmp(C_KOALA_INFO(0).upper downto C_KOALA_INFO(0).lower) := reg.hp.data;
    v_tmp(C_KOALA_INFO(1).upper downto C_KOALA_INFO(1).lower) := reg.mana.data;

    return v_tmp;
  end function;

  function fun_koala_to_incr (reg : t_reg_koala_in) return std_logic_vector is
    variable v_tmp : std_logic_vector(32-1 downto 0);
  begin
    v_tmp(0) := reg.hp.incr;
    v_tmp(1) := reg.mana.incr;

    return v_tmp;
  end function;

  function fun_koala_to_decr (reg : t_reg_koala_in) return std_logic_vector is
    variable v_tmp : std_logic_vector(32-1 downto 0);
  begin
    v_tmp(0) := reg.hp.decr;
    v_tmp(1) := reg.mana.decr;

    return v_tmp;
  end function;

  function fun_koala_to_we (reg : t_reg_koala_in) return std_logic_vector is
    variable v_tmp : std_logic_vector(32-1 downto 0);
  begin
    v_tmp(0) := reg.hp.we;
    v_tmp(1) := reg.mana.we;

    return v_tmp;
  end function;

end package body;
