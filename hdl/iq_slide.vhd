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
--! @file   iq_slide.vhd
--! @brief  IQ demodulation, pipelined
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
use work.math_basic.all;
use work.pkg_types.all;

entity iq_slide is
  generic (
    g_input_width     : natural := 16;
    g_output_width    : natural := 18;
    --
    g_sincos_tab_size : natural := 5;
    g_avg_factor      : natural := 1;
    --
    g_use_input_regs  : integer := 0;
    --
    g_adder_max_inputs : natural := 3;
    g_shift_margin    : natural := 4 -- I think this is what ENT_IQ_SLIDE does.. 3 extra bits from adder + 1 remaining from the first shift and the result is 0.
  );
  port (
    pi_clock      : in  std_logic;
    pi_reset      : in  std_logic;

    pi_data       : in std_logic_vector(g_input_width-1 downto 0);

    pi_sin        : in std_logic_vector(g_output_width-1 downto 0);
    pi_cos        : in std_logic_vector(g_output_width-1 downto 0);

    po_i          : out std_logic_vector(g_output_width-1 downto 0);
    po_q          : out std_logic_vector(g_output_width-1 downto 0);
    po_ovfl       : out std_logic;

    po_dry        : out std_logic
  );
end iq_slide;

architecture behav of iq_slide is

  function ovfl(a: signed; new_length: positive) return std_logic is
  begin
    if a(a'left) = a(a'left-1) then
      return '1';
    else
      return '0';
    end if;
  end function;

  -- Allow the user of this module to define that a number of bits can
  -- safely be dropped from the adder result through resize()
  --constant C_MARGIN : integer := 2; -- becuase sin/cos are Q1.16 (range +-2) used with half range
  constant C_MARGIN : integer := 4; -- I think this is what ENT_IQ_SLIDE does.. 3 extra bits from adder + 1 remaining from the first shift and the result is 0.

  -- ensure the two shifts after multiplication and summation are balanced
  constant C_SHIFT_1_PRODUCT : integer := g_input_width-1;

  -- bit width of the immediate multiplier outputs
  constant C_PRODUCT_WIDTH : positive := g_input_width+g_output_width;
  -- bit width of multiplier results that are put into the sliding window
  constant C_WINDOW_WIDTH : positive := C_PRODUCT_WIDTH-C_SHIFT_1_PRODUCT;

  constant C_M : positive := g_sincos_tab_size * g_avg_factor; -- window length

  type t_window_array is array(natural range <>) of signed(C_WINDOW_WIDTH-1 downto 0);

  function fun_window_to_slv(window: t_window_array) return std_logic_vector is
    variable result : std_logic_vector(window'length*C_WINDOW_WIDTH-1 downto 0);
  begin
    for i in 0 to C_M-1 loop
      result((i+1)*C_WINDOW_WIDTH-1 downto i*C_WINDOW_WIDTH) := std_logic_vector(window(i));
    end loop;
    return result;
  end function;

  signal window_i : t_window_array(C_M-1 downto 0);
  signal window_q : t_window_array(C_M-1 downto 0);
  signal window_rdy : std_logic;

  constant C_ADDER_STAGES : positive := ceil_logY(C_M, g_adder_max_inputs);
  constant C_ADDER_EXTRA_BITS : positive := ceil_log2(C_M);
  constant C_ADDER_RESULT_WIDTH : positive := C_WINDOW_WIDTH + C_ADDER_EXTRA_BITS;
  --constant C_ADDER_STAGE_WIDTH := fun_ceil(C_M, g_adder_max_inputs);
  constant C_SHIFT_2_SUM : integer := (g_input_width-C_SHIFT_1_PRODUCT)+C_ADDER_EXTRA_BITS-C_MARGIN;
  type t_adder_stage is array(natural range <>) of signed(C_ADDER_RESULT_WIDTH-1 downto 0);
  type t_adder_tree is array(natural range <>) of t_adder_stage(0 to C_M-1);

  signal clock : std_logic;

  signal sin, cos : signed(g_output_width-1 downto 0);
  signal data     : signed(g_input_width-1 downto 0);

  signal sum_i : signed(C_ADDER_RESULT_WIDTH-1 downto 0);
  signal sum_q : signed(C_ADDER_RESULT_WIDTH-1 downto 0);
  signal sum_rdy : std_logic;

begin
  clock <= pi_clock;
  --
  -- Stage 1 (0-1 clocks): input register
  --
  gen_input_regs : if g_use_input_regs = 1 generate
    prs_input_regs : process(clock)
    begin
      if rising_edge(clock) then
        sin <= signed(pi_sin);
        cos <= signed(pi_cos);
        data <= signed(pi_data);
      end if;
    end process;
  end generate;

  gen_no_input_regs : if g_use_input_regs = 0 generate
    sin <= signed(pi_sin);
    cos <= signed(pi_cos);
    data <= signed(pi_data);
  end generate;

  --
  -- Stage 2 (2 clocks): multiplication and sliding window
  --
  blk_mult: block
    signal l_product_i : signed(C_PRODUCT_WIDTH-1 downto 0);
    signal l_product_q : signed(C_PRODUCT_WIDTH-1 downto 0);

    constant C_MULT_DELAY : integer := G_USE_INPUT_REGS+2+C_M; -- 1 for mult, 1 for ???
    signal l_window_cnt : unsigned(ceil_log2(C_MULT_DELAY)-1 downto 0);
  begin
    prs_multiplier: process(clock)
    begin
      if rising_edge(clock) then
        l_product_i <= cos * data;
        l_product_q <= sin * data;
      end if;
    end process;

    prs_window: process(clock)
    begin
      if rising_edge(clock) then
        if pi_reset = '1' then
          window_i <= (others => (others => '0'));
          window_q <= (others => (others => '0'));
          window_rdy <= '0';

          l_window_cnt <= (others => '0');
        else
          -- Could be combined with the multiplication for a single clock,
          -- storing window(0) in the DSP slice M register.
          window_i(0) <= resize(
                         shift_right(
                         l_product_i,
                         C_SHIFT_1_PRODUCT),
                         C_WINDOW_WIDTH);
          window_q(0) <= resize(
                         shift_right(
                         l_product_q,
                         C_SHIFT_1_PRODUCT),
                         C_WINDOW_WIDTH);

          -- Sliding window
          window_i(window_i'left downto 1)  <= window_i(window_i'left-1 downto 0);
          window_q(window_q'left downto 1)  <= window_q(window_q'left-1 downto 0);

          -- Counter for rdy singal
          if to_integer(l_window_cnt) = C_MULT_DELAY-1 then
            l_window_cnt <= l_window_cnt;
            window_rdy <= '1';
          else
            l_window_cnt <= l_window_cnt+1;
            window_rdy <= '0';
          end if;
        end if;
      end if;
    end process;
  end block blk_mult;

  --
  -- Stage 3 (multiple clocks): multi-stage adder
  --
  blk_adders: block
    signal l_sum_i_rdy : std_logic;
    signal l_sum_q_rdy : std_logic;
  begin

    -- TODO adders could be wrapped in another entity adder_pipe_iq

    ins_adder_i: entity work.adder_pipe
    generic map (
                  g_input_width => C_WINDOW_WIDTH,
                  g_output_width => C_ADDER_RESULT_WIDTH,
                  g_n_inputs => C_M,
                  g_adder_max_inputs => g_adder_max_inputs
                )
    port map (
               pi_clock => clock,
               pi_reset => pi_reset,

               pi_rdy => window_rdy,
               pi_data => fun_window_to_slv(window_i),
               po_rdy => l_sum_i_rdy,
               po_sum => sum_i
             );

    ins_adder_q: entity work.adder_pipe
    generic map (
                  g_input_width => C_WINDOW_WIDTH,
                  g_output_width => C_ADDER_RESULT_WIDTH,
                  g_n_inputs => C_M,
                  g_adder_max_inputs => g_adder_max_inputs
                )
    port map (
               pi_clock => clock,
               pi_reset => pi_reset,

               pi_rdy => window_rdy,
               pi_data => fun_window_to_slv(window_q),
               po_rdy => l_sum_q_rdy,
               po_sum => sum_q
             );

    sum_rdy <= l_sum_q_rdy and l_sum_i_rdy;

    -- TODO overflow detection

  end block blk_adders;


  --
  -- Output stage
  --
  gen_output_shift : if C_SHIFT_2_SUM > 0 generate
    po_i <= std_logic_vector(resize(shift_right(sum_i, C_SHIFT_2_SUM), g_output_width));
    po_q <= std_logic_vector(resize(shift_right(sum_q, C_SHIFT_2_SUM), g_output_width));
  end generate;
  gen_no_output_shift : if C_SHIFT_2_SUM = 0 generate
    po_i <= std_logic_vector(resize(sum_i, g_output_width));
    po_q <= std_logic_vector(resize(sum_q, g_output_width));
  end generate;

  po_dry <= sum_rdy;

end architecture;
