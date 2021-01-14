-------------------------------------------------------------------------------
--          ____  _____________  __                                          --
--         / __ \/ ____/ ___/\ \/ /                 _   _   _                --
--        / / / / __/  \__ \  \  /                 / \ / \ / \               --
--       / /_/ / /___ ___/ /  / /               = ( m | s | k )=             --
--      /_____/_____//____/  /_/                   \_/ \_/ \_/               --
--                                                                           --
-------------------------------------------------------------------------------
-- $Header: https://mskllrfredminesrv.desy.de/svn/utca_firmware_framework/trunk/applications/test_scope/hdl/app_top.vhd 4071 2020-08-04 10:39:13Z mbuechl $
-------------------------------------------------------------------------------
--! @file   <filename.vhd>
--! @brief  
--! @author Michael Buechler
--! @email  michael.buechler@desy.de
--! $Date: 2020-08-04 12:39:13 +0200 (Di, 04 Aug 2020) $
--! $Revision: 4071 $
--! $URL: url $
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

use work.pkg_axi.all;

use work.pkg_types.all;

use work.pkg_reg_test_hectare.all;

entity test_hectare_top is
  generic(
    g_axi_data_width : natural := 256
  );
  port(
    pi_clock  : in std_logic;
    pi_reset  : in std_logic;
    -------------------------------------------
    --! daq axi4 interface
    pi_s_axi4 : in  t_axi4_m2s;
    po_s_axi4 : out t_axi4_s2m;
    -- external ports
    pi_regs : in t_registers_test_hectare_in;
    po_regs : out t_registers_test_hectare_out;

    pi_mem : in t_memories_test_hectare_in;
    po_mem : out t_memories_test_hectare_out
  );
end test_hectare_top;

architecture arch of test_hectare_top is
  signal s_axi4_m2s : t_axi4_m2s;
  signal s_axi4_s2m : t_axi4_s2m;

  signal regs_in : t_registers_test_hectare_in;
  signal regs_out : t_registers_test_hectare_out;

  signal mem_a_in : t_memories_test_hectare_in;
  signal mem_a_out : t_memories_test_hectare_out;
  signal mem_b_in : t_memories_test_hectare_in;
  signal mem_b_out : t_memories_test_hectare_out;
begin

  ins_top_reg_test_hectare : entity work.top_reg_test_hectare
  port map (
    pi_clock      => pi_clock,
    pi_reset      => pi_reset,

    pi_s_axi4     => pi_s_axi4,
    po_s_axi4     => po_s_axi4,

    pi_logic_regs => regs_in,
    po_logic_regs => regs_out,

    pi_mem => mem_a_out,
    po_mem => mem_a_in
  );

  -- TODO add to top.vhd.in ?
  po_s_axi4.aclk <= pi_clock;
  -- needed?
  po_s_axi4.rdata(po_s_axi4.rdata'left downto 32) <= (others => '0');
  po_s_axi4.bid <= (others => '0');
  po_s_axi4.rid <= (others => '0');
  po_s_axi4.rlast <= '0';

  -- user logic here
  po_regs <= regs_out;
  regs_in <= pi_regs;

  po_mem.coolmem <= mem_b_out.coolmem;
  mem_b_in.coolmem <= pi_mem.coolmem;


  ins_memory : entity work.dual_port_memory
  generic map (
    G_DATA_WIDTH => 32,
    G_ADDR_WIDTH => 10 -- TODO add entry to record
  )
  port map (
    pi_clk_a  => pi_clock,
    pi_ena_a  => mem_a_in.coolmem.ena,
    pi_wr_a   => mem_a_in.coolmem.wr,
    pi_addr_a => mem_a_in.coolmem.addr(10-1 downto 0),
    pi_data_a => mem_a_in.coolmem.data,
    po_data_a => mem_a_out.coolmem,

    pi_clk_b  => pi_clock,
    pi_ena_b  => mem_b_in.coolmem.ena,
    pi_wr_b   => mem_b_in.coolmem.wr,
    pi_addr_b => mem_b_in.coolmem.addr(10-1 downto 0),
    pi_data_b => mem_b_in.coolmem.data,
    po_data_b => mem_b_out.coolmem
  );

end architecture;
