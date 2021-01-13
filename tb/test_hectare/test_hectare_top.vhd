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
    po_regs : out t_registers_test_hectare_out
  );
end test_hectare_top;

architecture arch of test_hectare_top is
  signal s_axi4_m2s : t_axi4_m2s;
  signal s_axi4_s2m : t_axi4_s2m;

  signal regs_in : t_registers_test_hectare_in;
  signal regs_out : t_registers_test_hectare_out;
begin

  ins_top_reg_test_hectare : entity work.top_reg_test_hectare
  port map (
    pi_clock      => pi_clock,
    pi_reset      => pi_reset,
    S_AXI_AWADDR  => pi_s_axi4.awaddr(C_ADDR_W-1 downto 0),
    S_AXI_AWPROT  => (others => '0'),
    S_AXI_AWVALID => pi_s_axi4.awvalid,
    S_AXI_AWREADY => po_s_axi4.awready,
    S_AXI_AWID    => pi_s_axi4.awid,
    S_AXI_WDATA   => pi_s_axi4.wdata(32-1 downto 0),
    S_AXI_WSTRB   => pi_s_axi4.wstrb(4-1 downto 0),
    S_AXI_WVALID  => pi_s_axi4.wvalid,
    S_AXI_WREADY  => po_s_axi4.wready,
    S_AXI_BRESP   => po_s_axi4.bresp,
    S_AXI_BVALID  => po_s_axi4.bvalid,
    S_AXI_BREADY  => pi_s_axi4.bready,
    S_AXI_BID     => po_s_axi4.bid,
    S_AXI_ARADDR  => pi_s_axi4.araddr(C_ADDR_W-1 downto 0),
    S_AXI_ARPROT  => (others => '0'),
    S_AXI_ARVALID => pi_s_axi4.arvalid,
    S_AXI_ARREADY => po_s_axi4.arready,
    S_AXI_ARID    => pi_s_axi4.arid,
    S_AXI_RDATA   => po_s_axi4.rdata(32-1 downto 0),
    S_AXI_RRESP   => po_s_axi4.rresp,
    S_AXI_RVALID  => po_s_axi4.rvalid,
    S_AXI_RREADY  => pi_s_axi4.rready,
    S_AXI_RID     => po_s_axi4.rid,
    pi_logic_regs => regs_in,
    po_logic_regs => regs_out
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

end architecture;
