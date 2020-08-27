-------------------------------------------------------------------------------
--          ____  _____________  __                                          --
--         / __ \/ ____/ ___/\ \/ /                 _   _   _                --
--        / / / / __/  \__ \  \  /                 / \ / \ / \               --
--       / /_/ / /___ ___/ /  / /               = ( M | S | K )=             --
--      /_____/_____//____/  /_/                   \_/ \_/ \_/               --
--                                                                           --
-------------------------------------------------------------------------------
-- $Header: https://mskllrfredminesrv.desy.de/svn/utca_firmware_framework/trunk/libraries/dsp/tb_iq_slide.vhd 2231 2017-12-14 19:46:01Z lbutkows $
-------------------------------------------------------------------------------
--! @file   tb_iq_slide.vhd
--! @brief  testbench for IQ demodulation
--! @author Michael Buechler
--! @email  michael.buechler@desy.de
--! $Date: 2017-12-14 20:46:01 +0100 (Do, 14 Dez 2017) $
--! $Revision: 2231 $
--! $URL: https://mskllrfredminesrv.desy.de/svn/utca_firmware_framework/trunk/libraries/dsp/tb_iq_slide.vhd $
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

use ieee.numeric_std.all;

library work;
use work.math_basic.all;

entity tb_iq_slide is
end tb_iq_slide;
 
architecture sim of tb_iq_slide is

  constant c_clk_period : time := 10 ns;
  constant c_sincos_wl  : natural := 18;
  constant c_sample_wl  : natural := 16;
  constant c_iq_wl      : natural := 18;

  constant c_sincos_base : natural := 16; -- fractional bits
  constant c_sincos_tab_size : natural := 5;
  constant c_iq_count    : natural := 5; -- called M in Matthias Hoffmann's diss

  constant c_fd_output_shift : natural := 15; -- match REGAE

  constant C_USE_NEW_VERSION : integer := 0;

  type TSinCosTab is array(c_sincos_tab_size-1 downto 0) of signed(c_sincos_wl-1 downto 0);
--  constant c_cos_tab : TSinCosTab := (
--  to_signed(65536, c_sincos_wl),
--  to_signed(20251, c_sincos_wl),
--  to_signed(-53019, c_sincos_wl),
--  to_signed(-53019, c_sincos_wl),
--  to_signed(20251, c_sincos_wl)
--  );
--  constant c_sin_tab : TSinCosTab := (
--  to_signed(0, c_sincos_wl),
--  to_signed(62328, c_sincos_wl),
--  to_signed(38521, c_sincos_wl),
--  to_signed(-38521, c_sincos_wl),
--  to_signed(-62328, c_sincos_wl)
--  );
  -- A=0.3; Qm.16
  constant c_cos_tab : TSinCosTab := (
  to_signed(6075, c_sincos_wl),
  to_signed(-15905, c_sincos_wl),
  to_signed(-15905, c_sincos_wl),
  to_signed(6075, c_sincos_wl),
  to_signed(19660, c_sincos_wl)
  );
  constant c_sin_tab : TSinCosTab := (
  to_signed(-18698, c_sincos_wl),
  to_signed(-11556, c_sincos_wl),
  to_signed(11556, c_sincos_wl),
  to_signed(18698, c_sincos_wl),
  to_signed(0, c_sincos_wl)
  );

  -- component ports
  signal pi_clock   : std_logic:='0';
  signal pi_reset : std_logic:='0';
  signal pi_data : std_logic_vector(c_sample_wl-1 downto 0) := (others => '0');
  signal pi_sin_tab : std_logic_vector(c_sincos_tab_size*c_sincos_wl-1 downto 0);
  signal pi_cos_tab : std_logic_vector(c_sincos_tab_size*c_sincos_wl-1 downto 0);
  signal pi_sin : std_logic_vector(c_sincos_wl-1 downto 0);
  signal pi_cos : std_logic_vector(c_sincos_wl-1 downto 0);
  signal sincos_tab_index : unsigned(ceil_log2(c_sincos_tab_size)-1 downto 0);
  --signal pi_sin_tab : TSinCosTab;
  --signal pi_cos_tab : TSinCosTab;
  signal po_i : std_logic_vector(c_iq_wl-1 downto 0):=(others => '0');
  signal po_q : std_logic_vector(c_iq_wl-1 downto 0):=(others => '0');
  signal po_valid : std_logic := '0';

begin  -- architecture sim

  gen_sin_cos: for I in 0 to c_sincos_tab_size-1 generate
  begin
    pi_cos_tab(c_sincos_wl*(I+1)-1 downto c_sincos_wl*I) <= std_logic_vector(c_cos_tab(I));
    pi_sin_tab(c_sincos_wl*(I+1)-1 downto c_sincos_wl*I) <= std_logic_vector(c_sin_tab(I));
  end generate;
  --pi_sin <= pi_sin_tab((to_integer(sincos_tab_index)+1)*c_sincos_wl-1 downto to_integer(sincos_tab_index)*c_sincos_wl);
  --pi_cos <= pi_cos_tab((to_integer(sincos_tab_index)+1)*c_sincos_wl-1 downto to_integer(sincos_tab_index)*c_sincos_wl);
  pi_sin <= std_logic_vector(c_sin_tab(to_integer(sincos_tab_index)));
  pi_cos <= std_logic_vector(c_cos_tab(to_integer(sincos_tab_index)));

  -- component instantiation
  gen_ENT_IQ_SLIDE : if C_USE_NEW_VERSION = 0 generate
    uut: entity work.ENT_IQ_SLIDE
    generic map (
                  GEN_INPUT_WIDTH => c_sample_wl,

                  GEN_SINCOS_TAB_SIZE   => c_sincos_tab_size,

                  GEN_AVG_FACTOR      => c_iq_count / c_sincos_tab_size,

                  GEN_OUTPUT_WIDTH => c_iq_wl,
                  GEN_OUTPUT_SHIFT => c_fd_output_shift
                )
    port map (
               P_I_CLK   => pi_clock,
               P_I_RESET => pi_reset,

               P_I_DATA  => pi_data,

               P_I_SIN   => pi_sin,
               P_I_COS   => pi_cos,

               P_O_I     => po_i,
               P_O_Q     => po_q,
               P_O_DRY   => po_valid
             );
  end generate gen_ENT_IQ_SLIDE;

  gen_iq_slide : if C_USE_NEW_VERSION = 1 generate
    uut: entity work.iq_slide
    generic map (
                  g_input_width => c_sample_wl,
                  g_output_width => c_iq_wl,

                  g_sincos_tab_size => c_sincos_tab_size,
                  g_avg_factor      => c_iq_count / c_sincos_tab_size,

                  g_use_input_regs  => 0,

                  g_adder_max_inputs => 3,
                  g_shift_margin     => 4 -- I think this is what ENT_IQ_SLIDE does.. 3 extra bits from adder + 1 remaining from the first shift and the result is 0.
                )
    port map (
               pi_clock => pi_clock,
               pi_reset => pi_reset,

               pi_data => pi_data,

               pi_sin => pi_sin,
               pi_cos => pi_cos,

               po_i => po_i,
               po_q => po_q,

               po_dry => po_valid
             );
  end generate gen_iq_slide;

  pi_clock <= not pi_clock after c_clk_period/2;

  -- sin/cos table sincos_tab_index counter
  process(pi_clock)
  begin
    if rising_edge(pi_clock) then
      if pi_reset = '1' then
        sincos_tab_index <= (others => '0');
      else
        if sincos_tab_index = c_sincos_tab_size-1 then
          sincos_tab_index <= (others => '0');
        else
          sincos_tab_index <= sincos_tab_index+1;
        end if;
      end if;
    end if;
  end process;

  prs_reset : process
  begin
    pi_reset <= '1';
    wait for 3*c_clk_period;
    pi_reset <= '0';
    wait;
  end process;

end architecture;
