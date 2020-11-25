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
  type t_state_read is (sReadIdle, sReadSelect, sReadValid);
  signal state_read : t_state_read;

  signal rdata_reg : std_logic_vector(31 downto 0);
  signal rdata_mem : t_32BitArray(C_MEMORIES-1 downto 0);
  signal rdata_out : std_logic_vector(31 downto 0);
  signal raddr_reg : std_logic_vector(G_ADDR_W-1 downto 0);
  signal raddr_mem : unsigned(G_ADDR_W-2-1 downto 0);
  signal raddr_word : integer;

  signal raddr_is_reg : std_logic;
  signal raddr_is_reg_q : std_logic;

  signal arready_wire : std_logic;
  signal rvalid_wire : std_logic;

  -- write
  type t_state_write is (sWriteIdle, sWriteWaitData, sWriteWaitAddr, sWriteSelect, sWriteResp);
  signal state_write : t_state_write;
  signal state_write_prev : t_state_write;

  signal wdata_q : std_logic_vector(31 downto 0);
  signal waddr_q : std_logic_vector(G_ADDR_W-1 downto 0);
  signal waddr_mem : unsigned(G_ADDR_W-2-1 downto 0);
  signal waddr_word : integer;

  signal waddr_is_reg : std_logic;

  signal awready_wire : std_logic;
  signal wready_wire : std_logic;
  signal bvalid_wire : std_logic;

  -- memories
  signal mem_ren : std_logic_vector(C_MEMORIES-1 downto 0) := (others => '0');
  signal mem_rsel : integer := 0;
  signal mem_rsel_q : integer := 0;
  signal mem_rack : std_logic_vector(C_MEMORIES-1 downto 0) := (others => '0');
  signal mem_rack_q : std_logic_vector(C_MEMORIES-1 downto 0) := (others => '0');
  signal mem_wen : std_logic_vector(C_MEMORIES-1 downto 0) := (others => '0');
  signal mem_wsel : integer := 0;
  signal mem_wack : std_logic_vector(C_MEMORIES-1 downto 0) := (others => '0');

begin

  -- ### read logic

  -- 0. sReadIdle
  -- 1. -> ARVALID signals a new address to be read --> sReadValid
  -- 2. -> RREADY  signals that the master is ready to receive data --> sReadIdle

  proc_state_read: process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        state_read <= sReadIdle;
      else
        case state_read is
          when sReadIdle =>
            if S_AXI_ARVALID = '1' then
              state_read <= sReadSelect;
              raddr_reg <= S_AXI_ARADDR(G_ADDR_W-1 downto 0);
            end if;

          when sReadSelect =>
            state_read <= state_read;
            -- reading from a register is always done in 1 clock
            if raddr_is_reg = '1' then
              state_read <= sReadValid;
            -- wait for an ack from memory logic
            elsif mem_rack(mem_rsel) = '1' then
              state_read <= sReadValid;
            end if;

          when sReadValid =>
            if S_AXI_RREADY = '1' then
              state_read <= sReadIdle;
            end if;
        end case;

        raddr_is_reg_q <= raddr_is_reg;
        mem_rsel_q <= mem_rsel;
        mem_rack_q <= mem_rack;

      end if;
    end if;
  end process;

  raddr_word <= to_integer(unsigned(raddr_reg(G_ADDR_W-1 downto 2)));
  raddr_mem <= unsigned(raddr_reg(G_ADDR_W-1 downto 2));

  -- registers
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

    end if;
  end process;

  -- memories

  -- select register or memory
  proc_read_sel: process (state_read, raddr_word)
  begin
    for i in C_MEMORIES-1 downto 0 loop
      -- TODO optimize. Also see:
      -- https://zipcpu.com/blog/2019/07/17/crossbar.html#examining-the-arbitration-code
      case state_read is

        when sReadSelect =>
          if raddr_word-C_MEM_START(i)/4 >= 0 and raddr_word-(C_MEM_START(i)/4+2**C_MEM_AW(i)) < 0 then
            raddr_is_reg <= '0';
            mem_ren(i) <= '1';
            mem_rsel <= i;
          else
            mem_ren(i) <= '0';
          end if;

        when others =>
          raddr_is_reg <= '1';
          mem_ren(i) <= '0';

      end case;
    end loop;
  end process;

  -- Data from either register or memory only becomes available for sReadValid
  -- and must therefore be multiplexed combinatorically at the output.
  proc_read_sel_out: process(state_read, rdata_reg, rdata_mem, raddr_is_reg_q, mem_rack_q, mem_rsel_q)
  begin
    -- TODO drop case statement, not needed?
    case state_read is
      when sReadValid =>
        if raddr_is_reg_q = '1' then
          rdata_out <= rdata_reg;
        elsif mem_rack_q(mem_rsel_q) = '1' then
          rdata_out <= rdata_mem(mem_rsel_q);
        end if;
      when others =>
        null;
    end case;
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
  S_AXI_RDATA <= rdata_out;
  S_AXI_RRESP <= "00";

  -- Dual-port memories
  gen_memories : for i in C_MEMORIES-1 downto 0 generate
    gen_internal : if C_MEM_INTERNAL(i) = 1 generate
      signal l_rwsel : std_logic_vector(1 downto 0) := (others => '0');
      signal l_mem_addr : unsigned(C_MEM_AW(i)-1 downto 0) := (others => '0');

      signal l_ena : std_logic := '0';
      signal l_wr : std_logic := '0';
    begin
      l_rwsel <= mem_ren(i) & mem_wen(i);

      prs_rwsel : process(l_rwsel, l_mem_addr, waddr_mem, raddr_mem)
      begin
        case l_rwsel is
          when "00" =>
            -- memory signals
            l_ena <= '0';
            l_wr <= '0';
            l_mem_addr <= l_mem_addr;
            -- ack for state logic
            mem_rack(i) <= '0';
            mem_wack(i) <= '0';
          when "01" =>
            l_ena <= '1';
            l_wr <= '1';
            l_mem_addr <= waddr_mem(C_MEM_AW(i)-1 downto 0);

            mem_rack(i) <= '0';
            mem_wack(i) <= '1';
          when "10" =>
            l_ena <= '1';
            l_wr <= '0';
            l_mem_addr <= raddr_mem(C_MEM_AW(i)-1 downto 0);

            mem_rack(i) <= '1';
            mem_wack(i) <= '0';
          when "11" =>
            -- read has precedence (random designer's choice)
            l_ena <= '1';
            l_wr <= '0';
            l_mem_addr <= raddr_mem(C_MEM_AW(i)-1 downto 0);

            mem_rack(i) <= '1';
            mem_wack(i) <= '0';
          when others => report "impossible case" severity failure;
        end case;
      end process;

      -- TODO handle write address
      ins_memory : entity work.dual_port_memory
      generic map (
        G_DATA_WIDTH => 32,
        G_ADDR_WIDTH => C_MEM_AW(i)
      )
      port map (
        pi_clk_a  => clk,
        pi_ena_a  => l_ena,
        pi_wr_a   => l_wr,
        pi_addr_a => std_logic_vector(l_mem_addr),
        pi_data_a => wdata_q,
        po_data_a => rdata_mem(i),

        pi_clk_b  => clk,
        pi_ena_b  => '1',
        pi_wr_b   => '0',
        pi_addr_b => (others => '0'),
        pi_data_b => (others => '0'),
        po_data_b => open
      );
    end generate;
  end generate;

  -- ### write logic
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
              state_write <= sWriteSelect;
              waddr_q <= S_AXI_AWADDR;
              wdata_q <= S_AXI_WDATA;
            elsif S_AXI_AWVALID = '1' and S_AXI_WVALID = '0' then
              state_write <= sWriteWaitData;
              waddr_q <= S_AXI_AWADDR;
            elsif S_AXI_AWVALID = '0' and S_AXI_WVALID = '1' then
              state_write <= sWriteWaitAddr;
              wdata_q <= S_AXI_WDATA;
            end if;
          when sWriteWaitData =>
            if S_AXI_WVALID = '1' then
              state_write <= sWriteSelect;
              wdata_q <= S_AXI_WDATA;
            end if;
          when sWriteWaitAddr =>
            if S_AXI_AWVALID = '1' then
              state_write <= sWriteSelect;
              waddr_q <= S_AXI_AWADDR;
            end if;
          -- new select state now, optimize later
          when sWriteSelect =>
            if waddr_is_reg = '1' then
              state_write <= sWriteResp;
            elsif waddr_is_reg = '0' and mem_wack(mem_wsel) = '1' then
              state_write <= sWriteResp;
            else
              state_write <= state_write;
            end if;
          when sWriteResp =>
            if S_AXI_BREADY = '1' then
              state_write <= sWriteIdle;
            end if;
        end case;
      end if;
    end if;
  end process;

  waddr_word <= to_integer(unsigned(waddr_q(G_ADDR_W-1 downto 2)));
  waddr_mem <= unsigned(waddr_q(G_ADDR_W-1 downto 2));

  proc_write_reg : process (clk) begin
    if rising_edge(clk) then

      if state_write = sWriteResp and state_write_prev /= sWriteResp then
        for i in C_REGISTER_INFO'range loop
          for j in 0 to C_REGISTER_INFO(i).N-1 loop
            for k in 0 to C_REGISTER_INFO(i).M-1 loop
              if waddr_word = C_REGISTER_INFO(i).addr/4+j*C_REGISTER_INFO(i).M+k then
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
      po_data <= wdata_q;
    end if;
  end process;

  proc_wdata_sel : process(state_write, waddr_word)
  begin
    for i in C_MEMORIES-1 downto 0 loop
      case state_write is
        when sWriteSelect =>
          if waddr_word-C_MEM_START(i)/4 >= 0 and waddr_word-(C_MEM_START(i)/4+2**C_MEM_AW(i)) < 0 then
            waddr_is_reg <= '0';
            mem_wen(i) <= '1';
            mem_wsel <= i;
          else
            waddr_is_reg <= '1';
            mem_wen(i) <= '0';
          end if;
        when others =>
          waddr_is_reg <= '1';
          mem_wen(i) <= '0';
      end case;
    end loop;
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
