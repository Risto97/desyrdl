library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.types.all;

package pkg_axi4 is
  constant C_ADDR_W : integer := 8;

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
  type t_field_storage_info_arr is array (integer range <>) of t_field_storage_info;

  -- this is only one specific register
  constant C_FIELD_STORAGE_INFO : t_field_storage_info_arr := (
    (len => 16, upper => 31, lower => 16, hw_we => true, sw_access => C_RW, hw_access => C_R,  def_val => (others => '1')),
    (len => 8,  upper => 15, lower =>  8, hw_we => true, sw_access => C_R , hw_access => C_RW, def_val => (others => '1')),
    (len => 8,  upper =>  7, lower =>  0, hw_we => true, sw_access => C_RW, hw_access => C_RW, def_val => (others => '1'))
  );

  -- TODO delete
  type t_register_info is record
    addr : integer;
    --hw_rmask  : std_logic_vector(32-1 downto 0);
    --hw_wmask  : std_logic_vector(32-1 downto 0);
    hw : string(1 to 2);
    sw_rmask  : std_logic_vector(32-1 downto 0);
    sw_wmask  : std_logic_vector(32-1 downto 0);
  end record;
  type t_register_info_arr is array (integer range <>) of t_register_info;

  constant C_REGISTER_INFO : t_register_info_arr := (
    (addr => 0, hw => "na", sw_rmask => (others => '1'), sw_wmask => (others => '1')),
    (addr => 1, hw => "rw", sw_rmask => (others => '1'), sw_wmask => (others => '1')),
    (addr => 2, hw => "ro", sw_rmask => (others => '1'), sw_wmask => (others => '1'))
  );

  --type t_registers_<name> is array (0 to C_REGISTERS-1) of 
  --type t_registers is record
  --  reg1 : t_register_reg1;
    
end package pkg_axi4;
