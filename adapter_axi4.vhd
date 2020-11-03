-- BSD 3-Clause License
--
-- Copyright (c) 2020 Deutsches Elektronen-Synchrotron DESY.
--
-- TODO Authors: Jan Marjanovic, Michael Buechler

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg_types.all;
use work.pkg_reg_marsupials.all; -- maybe rename to sth like pkg_axi4_foocomponent

entity adapter_axi4 is
  generic (
    G_ADDR_W : integer := 8;
    G_REGISTERS : natural := 0
  );
  port (
    -- one element for each register, so N elements for a 2D register with length N
    pi_regs : in t_32BitArray(G_REGISTERS-1 downto 0);
    pi_err  : in  std_logic;

    po_stb  : out std_logic_vector(G_REGISTERS-1 downto 0);
    po_we   : out std_logic;
    po_data : out std_logic_vector(32-1 downto 0);

    --pi_dpm : in t_dpm_array_i(G_MEMORIES-1 downto 0);
    --po_dpm : in t_dpm_array_o(G_MEMORIES-1 downto 0);

    clk           : in std_logic;
    reset         : in std_logic;
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
    S_AXI_RREADY  : in std_logic

);
end entity adapter_axi4;

architecture arch of adapter_axi4 is

  -- read
  type t_state_read is (sReadIdle, sReadValid);
  signal state_read : t_state_read;

  signal rdata_reg : std_logic_vector(31 downto 0);
  signal raddr_word : integer;

  signal arready_wire : std_logic;
  signal rvalid_wire : std_logic;

  -- write
  type t_state_write is (sWriteIdle, sWriteWaitData, sWriteWaitAddr, sWriteResp);
  signal state_write : t_state_write;
  signal state_write_prev : t_state_write;

  signal waddr_reg : std_logic_vector(G_ADDR_W-1 downto 0);
  signal wdata_reg : std_logic_vector(31 downto 0);

  signal waddr_word : integer;

  signal awready_wire : std_logic;
  signal wready_wire : std_logic;
  signal bvalid_wire : std_logic;

begin

  proc_state_read: process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        state_read <= sReadIdle;
      else
        case state_read is
          when sReadIdle =>
            if S_AXI_ARVALID = '1' then
              state_read <= sReadValid;
            end if;
          when sReadValid =>
            if S_AXI_RREADY = '1' then
              state_read <= sReadIdle;
            end if;
        end case;
      end if;
    end if;
  end process;

  raddr_word <= to_integer(unsigned(S_AXI_ARADDR(G_ADDR_W-1 downto 2)));


  -- ### read logic

  proc_rdata_reg: process (clk)
  begin
    if rising_edge(clk) then
      rdata_reg <= (others => '0');

      for i in C_REGISTER_INFO'range loop
        for j in 0 to C_REGISTER_INFO(i).N-1 loop
          for k in 0 to C_REGISTER_INFO(i).M-1 loop
            if raddr_word = C_REGISTER_INFO(i).addr/4+j*C_REGISTER_INFO(i).M+k then
              rdata_reg <= pi_regs(C_REGISTER_INFO(i).base+j*C_REGISTER_INFO(i).M+k);
            end if;
          end loop;
        end loop;
      end loop;


      -- TODO have proper address decoding so a range of addresses reaches
      -- the appropriate memory. The lower bits will be used for the DPM
      -- address input.

      -- TODO multiplex the read data accordingly

      -- TODO enter a state machine to read. Data is available only one clock
      -- after setting the address.
--      for base,width in C_DPM_ARRAY loop
--        if raddr_word(32-1 downto width) = base(32-1 downto width) then
--          po_dpm(idx).ena  <= '1';
--          po_dpm(idx).wr   <= '0';
--          po_dpm(idx).addr <= raddr_word(width-1 downto 0);
--        end if;
--      end loop;
    end if;
  end process;

  proc_read_output: process (state_read)
  begin
    case state_read is
      when sReadIdle =>
        arready_wire <= '1';
        rvalid_wire <= '0';
      when sReadValid =>
        arready_wire <= '0';
        rvalid_wire <= '1';
      when others =>
        arready_wire <= '0';
        rvalid_wire <= '0';
    end case;
  end process;

  S_AXI_ARREADY <= arready_wire;
  S_AXI_RVALID <= rvalid_wire;
  S_AXI_RDATA <= rdata_reg;
  S_AXI_RRESP <= "00";


  -- this is all write logic
  proc_state_write_prev: process (clk) begin
    if rising_edge(clk) then
      state_write_prev <= state_write;
    end if;
  end process;

  proc_state_write: process (clk) begin
    if rising_edge (clk) then
      if reset = '1' then
        state_write <= sWriteIdle;
      else
        case state_write is
          when sWriteIdle =>
            if S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' then
              state_write <= sWriteResp;
              waddr_reg <= S_AXI_AWADDR;
              wdata_reg <= S_AXI_WDATA;
            elsif S_AXI_AWVALID = '1' and S_AXI_WVALID = '0' then
              state_write <= sWriteWaitData;
              waddr_reg <= S_AXI_AWADDR;
            elsif S_AXI_AWVALID = '0' and S_AXI_WVALID = '1' then
              state_write <= sWriteWaitAddr;
              wdata_reg <= S_AXI_WDATA;
            end if;
          when sWriteWaitData =>
            if S_AXI_WVALID = '1' then
              state_write <= sWriteResp;
              wdata_reg <= S_AXI_WDATA;
            end if;
          when sWriteWaitAddr =>
            if S_AXI_AWVALID = '1' then
              state_write <= sWriteResp;
              waddr_reg <= S_AXI_AWADDR;
            end if;
          when sWriteResp =>
            if S_AXI_BREADY = '1' then
              state_write <= sWriteIdle;
            end if;
        end case;
      end if;
    end if;
  end process;

  waddr_word <= to_integer(unsigned(waddr_reg(G_ADDR_W-1 downto 2)));
-- ### write logic (use waddr_word and wdata_reg)

  proc_write: process (clk) begin
    if rising_edge(clk) then

    -- default (pulse)
    -- TODO

    -- default (swmod)

      if state_write = sWriteResp and state_write_prev /= sWriteResp then
        for i in C_REGISTER_INFO'range loop
          for j in 0 to C_REGISTER_INFO(i).N-1 loop
            for k in 0 to C_REGISTER_INFO(i).M-1 loop
              if waddr_word = C_REGISTER_INFO(i).addr/4+j*C_REGISTER_INFO(i).M+k then
                report "Writing address " & integer'image(C_REGISTER_INFO(i).addr/4+j*C_REGISTER_INFO(i).M+k) severity note;
                po_stb(C_REGISTER_INFO(i).base+j*C_REGISTER_INFO(i).M+k) <= '1';
              end if;
            end loop;
          end loop;
        end loop;
        po_we <= '1';
      else
        po_stb <= (others => '0');
        po_we <= '0';
      end if;
      po_data <= wdata_reg;
    end if;
  end process;

  proc_write_output: process (state_write) begin
    case state_write is
      when sWriteIdle =>
        awready_wire <= '1';
        wready_wire <= '1';
        bvalid_wire <= '0';
      when sWriteWaitData =>
        awready_wire <= '0';
        wready_wire <= '1';
        bvalid_wire <= '0';
      when sWriteWaitAddr =>
        awready_wire <= '1';
        wready_wire <= '0';
        bvalid_wire <= '0';
      when sWriteResp =>
        awready_wire <= '0';
        wready_wire <= '0';
        bvalid_wire <= '1';
      when others =>
        awready_wire <= '0';
        wready_wire <= '0';
        bvalid_wire <= '0';
    end case;
  end process;

  S_AXI_AWREADY <= awready_wire;
  S_AXI_WREADY <= wready_wire;
  S_AXI_BRESP <= "00";
  S_AXI_BVALID <= bvalid_wire;
end architecture;
