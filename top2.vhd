library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg_types.all;
use work.pkg_axi4.all; -- maybe rename to sth like pkg_axi4_<foocomponent>

entity top is
  generic(
    g_adapter_id : integer; -- something like C_ADAPTER_LLRF_FD;
    G_ADDR_W : integer := 8;
    G_REGISTERS : natural := 0
  );
  port (
    clk           : in std_logic;
    reset         : in std_logic;

    -- AXI4
    S_AXI_AWADDR  : in std_logic_vector(G_ADDR_W-1 downto 0);
    S_AXI_AWPROT  : in std_logic_vector(2 downto 0);
    S_AXI_AWVALID : in std_logic;
    S_AXI_AWREADY : out std_logic;
    S_AXI_WDATA   : in std_logic_vector(32-1 downto 0);
    S_AXI_WSTRB   : in std_logic_vector(32/8-1 downto 0);
    S_AXI_WVALID  : in std_logic;
    S_AXI_WREADY  : out std_logic;
    S_AXI_BRESP   : out std_logic_vector(1 downto 0);
    S_AXI_BVALID  : out std_logic;
    S_AXI_BREADY  : in std_logic;
    S_AXI_ARADDR  : in std_logic_vector(G_ADDR_W-1 downto 0);
    S_AXI_ARPROT  : in std_logic_vector(2 downto 0);
    S_AXI_ARVALID : in std_logic;
    S_AXI_ARREADY : out std_logic;
    S_AXI_RDATA   : out std_logic_vector(32-1 downto 0);
    S_AXI_RRESP   : out std_logic_vector(1 downto 0);
    S_AXI_RVALID  : out std_logic;
    S_AXI_RREADY  : in std_logic;

    -- logic
    pi_logic_regs : in t_registers_modname_in;
    po_logic_regs : out t_registers_modname_out
  );
end entity;

architecture arch of top is
  signal clk : std_logic;
  signal reset : std_logic;

  signal adapter_stb : std_logic_vector(C_ADAPTER_INFO(g_adapter_id).C_N_REGS-1 downto 0);
  signal adapter_we  : std_logic;
  signal adapter_err : std_logic;
  signal adapter_wdata : std_logic_vector(32-1 downto 0);
  signal adapter_rdata : t_32BitArray(G_REGISTERS-1 downto 0);

  signal register_incr : std_logic_vector(32-1 downto 0);
  signal register_we : std_logic_vector(32-1 downto 0);
  signal register_data_in : std_logic_vector(32-1 downto 0);
  signal register_data_out : std_logic_vector(32-1 downto 0);
begin
  ins_adapter: entity work.adapter_axi4
  generic map (
                G_ADDR_W    => G_ADDR_W,
                G_REGISTERS => G_REGISTERS
              )
  port map (
             pi_regs       => adapter_rdata,
             po_stb        => adapter_stb,
             po_we         => adapter_we,
             pi_err        => adapter_err,
             po_data       => adapter_wdata,
             clk           => clk,
             reset         => reset,
             S_AXI_AWADDR  => S_AXI_AWADDR,
             S_AXI_AWPROT  => S_AXI_AWPROT,
             S_AXI_AWVALID => S_AXI_AWVALID,
             S_AXI_AWREADY => S_AXI_AWREADY,
             S_AXI_WDATA   => S_AXI_WDATA,
             S_AXI_WSTRB   => S_AXI_WSTRB,
             S_AXI_WVALID  => S_AXI_WVALID,
             S_AXI_WREADY  => S_AXI_WREADY,
             S_AXI_BRESP   => S_AXI_BRESP,
             S_AXI_BVALID  => S_AXI_BVALID,
             S_AXI_BREADY  => S_AXI_BREADY,
             S_AXI_ARADDR  => S_AXI_ARADDR,
             S_AXI_ARPROT  => S_AXI_ARPROT,
             S_AXI_ARVALID => S_AXI_ARVALID,
             S_AXI_ARREADY => S_AXI_ARREADY,
             S_AXI_RDATA   => S_AXI_RDATA,
             S_AXI_RRESP   => S_AXI_RRESP,
             S_AXI_RVALID  => S_AXI_RVALID,
             S_AXI_RREADY  => S_AXI_RREADY
           );

  for r in C_ADAPTER_INFO(g_adapter_id).C_REGISTER_INFO'range generate
    constant l_reg_info : t_reg_info := C_ADAPTER_INFO(g_adapter_id).C_REGISTER_INFO(r);

    -- TODO rename to l_regs_sdfsdf
    signal l_logic_incr     : std_logic_vector(32-1 downto 0);
    signal l_logic_we       : std_logic_vector(32-1 downto 0);
    signal l_logic_data_in  : std_logic_vector(32-1 downto 0);
    signal l_logic_data_out : std_logic_vector(32-1 downto 0);
  begin

    l_logic_incr    <= fun_logic_to_reg_incr(l_reg_info, pi_logic_regs(r).incr);
    l_logic_we      <= fun_logic_to_reg_we(l_reg_info, pi_logic_regs(r).we);
    l_logic_data_in <= fun_logic_to_reg_data(l_reg_info, pi_logic_regs(r).data);

    po_logic_regs(r) <= fun_reg_to_logic(l_reg_info.info, l_logic_data_out);

    ins_reg: entity work.generic_register
    generic map (
                  -- contains an array of field info
                  g_info => l_reg_info
                )
    port map (
               pi_clock => pi_clock,
               pi_reset => pi_reset,
               -- to/from adapter
               pi_adapter_stb  => adapter_stb(r),
               pi_adapter_we   => adapter_we,
               po_adapter_err  => adapter_err
               pi_adapter_data => adapter_wdata,
               po_adapter_data => adapter_rdata(r),

               -- to/from our IP
               pi_logic_incr => l_logic_incr,
               pi_logic_we   => l_logic_we,
               pi_logic_data => l_logic_data_in,
               po_logic_data => l_logic_data_out
             );
  end generate;

end architecture;

