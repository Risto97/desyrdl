library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg_types.all;
use work.pkg_axi4.all; -- maybe rename to sth like pkg_axi4_<foocomponent>

entity top is
  generic(
    --g_adapter_id : integer; -- something like C_ADAPTER_LLRF_FD;
    G_ADDR_W : integer := 8
  );
  port (
    pi_clk           : in std_logic;
    pi_reset         : in std_logic;

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
  signal adapter_stb : std_logic_vector(C_REGISTERS-1 downto 0);
  signal adapter_we  : std_logic;
  signal adapter_err : std_logic;
  signal adapter_wdata : std_logic_vector(32-1 downto 0);
  signal adapter_rdata : t_32BitArray(C_REGISTERS-1 downto 0);

  signal logic_regs : t_registers_modname_out;
begin
  ins_adapter: entity work.adapter_axi4
  generic map (
                G_ADDR_W    => G_ADDR_W,
                G_REGISTERS => C_REGISTERS
              )
  port map (
             pi_regs       => adapter_rdata,
             po_stb        => adapter_stb,
             po_we         => adapter_we,
             pi_err        => adapter_err,
             po_data       => adapter_wdata,
             clk           => pi_clk,
             reset         => pi_reset,
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

  -- duplicated blocks below
  -- index 0 regname whatever
  blk_0_whatever : block
    constant l_r : integer := 0;
    constant l_reg_info : t_reg_info := C_REGISTER_INFO(l_r);
  begin
    gen_N : for i in 0 to l_reg_info.N-1 generate  -- outer dim, for 3D arrays
    begin
      gen_M: for j in 0 to l_reg_info.M-1 generate -- inner dim, for 2D arrays
        signal l_reg_decr     : std_logic_vector(32-1 downto 0);
        signal l_reg_incr     : std_logic_vector(32-1 downto 0);
        signal l_reg_we       : std_logic_vector(32-1 downto 0);
        signal l_reg_data_in  : std_logic_vector(32-1 downto 0);
        signal l_reg_data_out : std_logic_vector(32-1 downto 0);
      begin

        l_reg_decr    <= fun_logic_to_decr(l_reg_info, pi_logic_regs, i, j);
        l_reg_incr    <= fun_logic_to_incr(l_reg_info, pi_logic_regs, i, j);
        l_reg_we      <= fun_logic_to_we(l_reg_info, pi_logic_regs, i, j);
        l_reg_data_in <= fun_logic_to_data(l_reg_info, pi_logic_regs, i, j);

        -- logic_regs.<regname>
        po_logic_regs.whatever(i,j) <= fun_slv_to_whatever(l_reg_data_out);
        --prd_reg_to_logic(l_reg_info, logic_regs, l_reg_data_out, i, j);

        ins_reg: entity work.generic_register
        generic map (
                      -- contains an array of field info
                      g_fields => l_reg_info.fields
                    )
        port map (
                   pi_clock => pi_clk,
                   pi_reset => pi_reset,

                   -- to/from adapter
                   pi_adapter_stb  => adapter_stb(l_r+i*l_reg_info.N+j),
                   pi_adapter_we   => adapter_we,
                   po_adapter_err  => adapter_err,
                   pi_adapter_data => adapter_wdata,
                   po_adapter_data => adapter_rdata(l_r+i*l_reg_info.N+j),

                   -- to/from our IP
                   pi_logic_incr => l_reg_incr,
                   pi_logic_we   => l_reg_we,
                   pi_logic_data => l_reg_data_in,
                   po_logic_data => l_reg_data_out
                 );

      end generate;
    end generate;
  end block;

end architecture;

