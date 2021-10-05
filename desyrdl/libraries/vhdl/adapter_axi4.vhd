-- BSD 3-Clause License
--
-- Copyright (c) 2020-2021 Deutsches Elektronen-Synchrotron DESY.
--
-- TODO Authors: Jan Marjanovic, Michael Buechler

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.common.all;

entity adapter_axi4 is
  generic (
    G_ADDR_W    : integer := 8;
    G_REGISTER_INFO : t_reg_info_array;
    G_MEMNAMES  : integer := 1;
    G_MEM_START : T_IntegerArray;
    G_MEM_AW    : T_IntegerArray;
    G_EXTCOUNT  : integer := 1;
    G_EXT_START : T_IntegerArray;
    G_EXT_SIZE  : T_IntegerArray;
    G_EXT_AW    : T_IntegerArray;
    G_REGNAMES  : integer := 1;
    G_REGCOUNT  : natural := 1
  );
  port (
    -- one element for each register, so N elements for a 2D register with length N
    pi_regs : in t_32BitArray(G_REGCOUNT-1 downto 0);
    pi_err  : in  std_logic;

    po_stb  : out std_logic_vector(G_REGCOUNT-1 downto 0);
    po_we   : out std_logic;
    po_data : out std_logic_vector(32-1 downto 0);

    pi_mem : in t_mem_out_arr(G_MEMNAMES downto 0);
    po_mem : out t_mem_in_arr(G_MEMNAMES downto 0);

    pi_ext : in t_axi4_s2m_array(G_EXTCOUNT downto 0);
    po_ext : out t_axi4_m2s_array(G_EXTCOUNT downto 0);

    clk           : in std_logic;
    reset         : in std_logic;
    S_AXI_AWADDR  : in std_logic_vector(G_ADDR_W-1 downto 0);
    S_AXI_AWPROT  : in std_logic_vector(2 downto 0);
    S_AXI_AWVALID : in std_logic;
    S_AXI_AWREADY : out std_logic;
    S_AXI_AWID    : in std_logic_vector(16-1 downto 0);
    S_AXI_WDATA   : in std_logic_vector(32-1 downto 0);
    S_AXI_WSTRB   : in std_logic_vector(32/8-1 downto 0);
    S_AXI_WVALID  : in std_logic;
    S_AXI_WREADY  : out std_logic;
    S_AXI_BRESP   : out std_logic_vector(1 downto 0);
    S_AXI_BVALID  : out std_logic;
    S_AXI_BREADY  : in std_logic;
    S_AXI_BID     : out std_logic_vector(16-1 downto 0);
    S_AXI_ARADDR  : in std_logic_vector(G_ADDR_W-1 downto 0);
    S_AXI_ARPROT  : in std_logic_vector(2 downto 0);
    S_AXI_ARVALID : in std_logic;
    S_AXI_ARREADY : out std_logic;
    S_AXI_ARID    : in std_logic_vector(16-1 downto 0);
    S_AXI_RDATA   : out std_logic_vector(32-1 downto 0);
    S_AXI_RRESP   : out std_logic_vector(1 downto 0);
    S_AXI_RVALID  : out std_logic;
    S_AXI_RREADY  : in std_logic;
    S_AXI_RID     : out std_logic_vector(16-1 downto 0)
);
end entity adapter_axi4;

architecture arch of adapter_axi4 is

  type t_target is (NONE, REG, MEM, EXT);
  signal rtarget, wtarget : t_target;
  signal rtarget_q, wtarget_q : t_target;
  -- read
  type t_state_read is (
    ST_READ_IDLE, ST_READ_SELECT, ST_READ_VALID,
    ST_READ_REG_BUSY,
    ST_READ_MEM_BUSY,
    ST_READ_EXT_BUSY
  );
  signal state_read : t_state_read;

  signal rdata_reg : std_logic_vector(31 downto 0);
  signal rdata_mem : t_32BitArray(G_MEMNAMES-1 downto 0);
  signal rdata_ext : std_logic_vector(31 downto 0);
  signal raddr_q : std_logic_vector(G_ADDR_W-1 downto 0);
  signal raddr_q_int : integer;

  signal rdata   : std_logic_vector(31 downto 0);

  -- write
  type t_state_write is (
    ST_WriteIdle, ST_WriteWaitData, ST_WriteWaitAddr, ST_WriteSelect, ST_WriteResp,
    ST_WriteMemBusy,
    ST_WriteExtBusy
  );
  signal state_write : t_state_write;

  signal wdata_q : std_logic_vector(31 downto 0);
  signal wstrb_q : std_logic_vector(3 downto 0);
  signal waddr_q : std_logic_vector(G_ADDR_W-1 downto 0);
  signal waddr_q_int : integer;

  -- select read
  signal reg_rsel : integer := 0;
  signal mem_rsel : integer := 0;
  signal ext_rsel : integer := 0;
  signal reg_rsel_q : integer := 0;
  signal mem_rsel_q : integer := 0;
  signal ext_rsel_q : integer := 0;
  -- select write
  signal reg_wsel : integer := 0;
  signal mem_wsel : integer := 0;
  signal ext_wsel : integer := 0;
  signal reg_wsel_q : integer := 0;
  signal mem_wsel_q : integer := 0;
  signal ext_wsel_q : integer := 0;

  -- memories
  signal mem_ren : std_logic_vector(G_MEMNAMES downto 0) := (others => '0');
  signal mem_rack : std_logic_vector(G_MEMNAMES downto 0) := (others => '0');
  signal mem_wen : std_logic_vector(G_MEMNAMES downto 0) := (others => '0');
  signal mem_wack : std_logic_vector(G_MEMNAMES downto 0) := (others => '0');

  -- downstream interfaces

  -- Oh you wanted to write to the same record from multiple processes?
  -- I don't care if the individual signals are indepentent SCREW YOU go
  -- and use separate signals for each.
  signal ext_arvalid : std_logic_vector (G_EXTCOUNT downto 0);
  signal ext_araddr : T_32BitArray (G_EXTCOUNT downto 0);
  signal ext_rready : std_logic_vector (G_EXTCOUNT downto 0);

  signal ext_awvalid : std_logic_vector (G_EXTCOUNT downto 0);
  signal ext_wvalid : std_logic_vector (G_EXTCOUNT downto 0);
  signal ext_bready : std_logic_vector (G_EXTCOUNT downto 0);
  signal ext_awaddr : T_32BitArray (G_EXTCOUNT downto 0);
  signal ext_wdata : T_32BitArray (G_EXTCOUNT downto 0);
  signal ext_wstrb : T_4BitArray (G_EXTCOUNT downto 0);

begin

  gen_ext_if : for i in G_EXTCOUNT-1 downto 0 generate
    po_ext(i).arvalid <= ext_arvalid(i);
    po_ext(i).araddr(G_EXT_AW(i)-1 downto 0) <= ext_araddr(i)(G_EXT_AW(i)-1 downto 0);
    po_ext(i).araddr(po_ext(i).araddr'left downto G_EXT_AW(i)) <= (others => '0');
    po_ext(i).rready <= ext_rready(i);
    po_ext(i).awvalid <= ext_awvalid(i);
    po_ext(i).wvalid <= ext_wvalid(i);
    po_ext(i).bready <= ext_bready(i);
    po_ext(i).awaddr(G_EXT_AW(i)-1 downto 0) <= ext_awaddr(i)(G_EXT_AW(i)-1 downto 0);
    po_ext(i).awaddr(po_ext(i).awaddr'left downto G_EXT_AW(i)) <= (others => '0');
    po_ext(i).wdata(31 downto 0) <= ext_wdata(i);
    po_ext(i).wstrb(3 downto 0) <= ext_wstrb(i);
  end generate;

  -- ### read logic

  -- state transitions, assignment of extended state variables and assignment
  -- of output signals in one process
  prs_state_read: process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        state_read <= ST_READ_IDLE;
        mem_ren <= (others => '0');

        -- some AXI4 signals must be reset here
        for i in G_EXTCOUNT downto 0 loop
          ext_arvalid(i) <= '0';
          ext_rready(i) <= '0';
        end loop;
      else
        state_read <= state_read;

        case state_read is
          when ST_READ_IDLE =>
            if S_AXI_ARVALID = '1' then
              state_read <= ST_READ_SELECT;
              raddr_q <= S_AXI_ARADDR(G_ADDR_W-1 downto 0);
              S_AXI_RRESP <= "00";
              S_AXI_RID <= S_AXI_ARID;
            end if;

          when ST_READ_SELECT =>
            state_read <= state_read;
            rtarget_q <= rtarget;
            if rtarget = REG then
              state_read <= ST_READ_REG_BUSY;
              reg_rsel_q <= reg_rsel;
            elsif rtarget = MEM then
              state_read <= ST_READ_MEM_BUSY;
              mem_rsel_q <= mem_rsel;
              mem_ren(mem_rsel) <= '1';
            elsif rtarget = EXT then
              state_read <= ST_READ_EXT_BUSY;
              ext_rsel_q <= ext_rsel;
              ext_arvalid(ext_rsel) <= '1';
              ext_araddr(ext_rsel) <= raddr_q;
              ext_rready(ext_rsel) <= '1';
            end if;

          when ST_READ_REG_BUSY =>
            state_read <= ST_READ_VALID;
            rdata_reg <= pi_regs(reg_rsel_q);

          when ST_READ_MEM_BUSY =>
            if mem_rack(mem_rsel_q) = '1' then
              state_read <= ST_READ_VALID;
              mem_ren <= (others => '0');
            end if;

          when ST_READ_EXT_BUSY =>
            -- This state begins with ext_arvalid=1, so once we see a
            -- ready signal the addr or data was accepted.
            if pi_ext(ext_rsel_q).arready = '1' then
              ext_arvalid(ext_rsel_q) <= '0';
            end if;

            if pi_ext(ext_rsel_q).rvalid = '1' then
              state_read <= ST_READ_VALID;
              rdata_ext <= pi_ext(ext_rsel_q).rdata(31 downto 0);
              ext_rready(ext_rsel_q) <= '0';

              -- might be redundant
              ext_arvalid(ext_rsel_q) <= '0';
            end if;

          when ST_READ_VALID =>
            if S_AXI_RREADY = '1' then
              state_read <= ST_READ_IDLE;
            end if;

          when others =>
            state_read <= ST_READ_IDLE;
            mem_ren <= (others => '0');

        end case;

      end if;
    end if;
  end process;

  -- have separate processes for improved overview and less errors during
  -- development
  prs_axi_rvalid: process (state_read)
  begin
    case state_read is
      when ST_READ_VALID =>
        S_AXI_RVALID <= '1';
      when others =>
        S_AXI_RVALID <= '0';
    end case;
  end process;

  prs_axi_arready: process (state_read)
  begin
    case state_read is
      when ST_READ_IDLE =>
        S_AXI_ARREADY <= '1';
      when others =>
        S_AXI_ARREADY <= '0';
    end case;
  end process;

  raddr_q_int <= to_integer(unsigned(raddr_q));

  prs_rtarget_sel: process (raddr_q_int)
  begin
    rtarget <= NONE;
    reg_rsel <= 0;
    mem_rsel <= 0;
    ext_rsel <= 0;

    -- TODO: optimize: do the comparisons during ST_READ_IDLE
    -- and put in raddr_is_mem_x[G_MEMCOUNT]
    -- TODO must be G_MEMCOUNT
    -- TODO optimize. Also see:
    -- https://zipcpu.com/blog/2019/07/17/crossbar.html#examining-the-arbitration-code

    for i in 0 to G_MEMNAMES-1 loop
      if raddr_q_int-G_MEM_START(i) >= 0
      and raddr_q_int-(G_MEM_START(i)+2**G_MEM_AW(i)) < 0 then
        rtarget <= MEM;
        mem_rsel <= i;
      end if;
    end loop;

    for i in 0 to G_EXTCOUNT-1 loop
      if raddr_q_int-G_EXT_START(i) >= 0
      and raddr_q_int-(G_EXT_START(i)+G_EXT_SIZE(i)) < 0 then
        rtarget <= EXT;
        ext_rsel <= i;
      end if;
    end loop;

    for i in 0 to G_REGNAMES-1 loop
      for j in 0 to G_REGISTER_INFO(i).N-1 loop
        for k in 0 to G_REGISTER_INFO(i).M-1 loop
          if raddr_q_int = G_REGISTER_INFO(i).addr+4*(j*G_REGISTER_INFO(i).M+k) then
            rtarget <= REG;
            reg_rsel <= G_REGISTER_INFO(i).internal_offset+j*G_REGISTER_INFO(i).M+k;
          end if;
        end loop;
      end loop;
    end loop;

  end process;

  S_AXI_RDATA <= rdata;
  -- Multiplex read data
  with rtarget_q select rdata <=
    rdata_reg when REG,
    rdata_mem(mem_rsel_q) when MEM,
    rdata_ext when EXT,
    rdata_reg when others;

  -- Dual-port memories
  --
  -- AXI address is addressing bytes
  -- DPM address is addressing the AXI data width (4 bytes)
  -- DPM data width is the same as the AXI data width
  --
  gen_memories : for i in G_MEMNAMES-1 downto 0 generate
    signal l_rwsel : std_logic_vector(1 downto 0) := (others => '0');
    signal l_mem_addr : std_logic_vector(G_ADDR_W-1 downto 0) := (others => '0');

    signal l_ena : std_logic := '0';
    signal l_wr : std_logic := '0';
  begin
    l_rwsel <= mem_ren(i) & mem_wen(i);

    with l_rwsel select l_mem_addr <=
      waddr_q when "00", -- don't care
      waddr_q when "01",
      raddr_q when "10",
      raddr_q when "11",
      (others => '0') when others;

    prs_rwsel : process(l_rwsel)
    begin
      case l_rwsel is
        when "00" =>
          -- memory signals
          l_ena <= '0';
          l_wr <= '0';
          -- ack for state logic
          mem_rack(i) <= '0';
          mem_wack(i) <= '0';
        when "01" =>
          l_ena <= '1';
          l_wr <= '1';

          mem_rack(i) <= '0';
          mem_wack(i) <= '1';
        when "10" =>
          l_ena <= '1';
          l_wr <= '0';

          mem_rack(i) <= '1';
          mem_wack(i) <= '0';
        when "11" =>
          -- read has precedence (random designer's choice)
          l_ena <= '1';
          l_wr <= '0';

          mem_rack(i) <= '1';
          mem_wack(i) <= '0';
        when others => report "impossible case" severity failure;
      end case;
    end process;

    po_mem(i).ena <= l_ena;
    po_mem(i).wr <= l_wr;
    -- addresses from SW are always increasing by 32 bit words
    -- regardless of the memory width
    po_mem(i).addr(G_MEM_AW(i)-3 downto 0) <= l_mem_addr(G_MEM_AW(i)-1 downto 2);
    po_mem(i).addr(po_mem(i).addr'high downto G_MEM_AW(i)-2) <= (others => '0');
    po_mem(i).data <= wdata_q;
    rdata_mem(i) <= pi_mem(i);

  end generate;

  -- ### write logic

  prs_state_write: process (clk) begin
    if rising_edge (clk) then
      if reset = '1' then
        state_write <= ST_WriteIdle;
        mem_wen <= (others => '0');

        po_we <= '0';
        for i in G_REGCOUNT-1 downto 0 loop
          po_stb(i) <= '0';
        end loop;

        -- some AXI4 signals must be reset here
        for i in G_EXTCOUNT-1 downto 0 loop
          ext_awvalid(i) <= '0';
          ext_wvalid(i) <= '0';
          ext_bready(i) <= '0';
        end loop;
      else
        case state_write is
          when ST_WriteIdle =>

            if S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' then
              state_write <= ST_WriteSelect;
              waddr_q <= S_AXI_AWADDR;
              S_AXI_BID <= S_AXI_AWID;
              wdata_q <= S_AXI_WDATA;
              wstrb_q <= S_AXI_WSTRB;
            elsif S_AXI_AWVALID = '1' and S_AXI_WVALID = '0' then
              state_write <= ST_WriteWaitData;
              waddr_q <= S_AXI_AWADDR;
              S_AXI_BID <= S_AXI_AWID;
            elsif S_AXI_AWVALID = '0' and S_AXI_WVALID = '1' then
              state_write <= ST_WriteWaitAddr;
              wdata_q <= S_AXI_WDATA;
              wstrb_q <= S_AXI_WSTRB;
            end if;

          when ST_WriteWaitData =>
            if S_AXI_WVALID = '1' then
              state_write <= ST_WriteSelect;
              wdata_q <= S_AXI_WDATA;
              wstrb_q <= S_AXI_WSTRB;
            end if;

          when ST_WriteWaitAddr =>
            if S_AXI_AWVALID = '1' then
              state_write <= ST_WriteSelect;
              waddr_q <= S_AXI_AWADDR;
              S_AXI_BID <= S_AXI_AWID;
            end if;

          when ST_WriteSelect =>
            wtarget_q <= wtarget;
            if wtarget = REG then
              state_write <= ST_WriteResp;
              --reg_wsel_q <= reg_wsel; -- unnecessary?
              po_we <= '1';
              po_stb(reg_wsel) <= '1';
            elsif wtarget = MEM then
              state_write <= ST_WriteMemBusy;
              mem_wsel_q <= mem_wsel;
              mem_wen(mem_wsel) <= '1';
            elsif wtarget = EXT then
              state_write <= ST_WriteExtBusy;
              ext_wsel_q <= ext_wsel;
              ext_awvalid(ext_wsel) <= '1';
              ext_awaddr(ext_wsel) <= waddr_q;
              ext_wvalid(ext_wsel) <= '1';
              ext_wdata(ext_wsel) <= wdata_q;
              ext_wstrb(ext_wsel) <= wstrb_q;
              ext_bready(ext_wsel) <= '1';
            else
              state_write <= ST_WriteIdle;
            end if;

          when ST_WriteMemBusy =>
            if mem_wack(mem_wsel_q) = '1' then
              state_write <= ST_WriteResp;
              mem_wen <= (others => '0');
            end if;

          when ST_WriteExtBusy =>
            -- This state begins with ext_awvalid=1 and ext_wvalid=1, so once we see a
            -- ready signal the addr or data was accepted.
            if pi_ext(ext_wsel_q).awready = '1' then
              ext_awvalid(ext_wsel_q) <= '0';
            end if;
            if pi_ext(ext_wsel_q).wready = '1' then
              ext_wvalid(ext_wsel_q) <= '0';
            end if;

            if pi_ext(ext_wsel_q).bvalid = '1' then
              state_write <= ST_WriteResp;
              ext_bready(ext_wsel_q) <= '0';

              -- might be redundant
              ext_awvalid(ext_wsel_q) <= '0';
              ext_wvalid(ext_wsel_q) <= '0';
            end if;

          when ST_WriteResp =>
            po_we <= '0';
            po_stb <= (others => '0');
            if S_AXI_BREADY = '1' then
              state_write <= ST_WriteIdle;
            end if;

          when others =>
            state_write <= ST_WriteIdle;
            mem_wen <= (others => '0');

        end case;
      end if;
    end if;
  end process;

  waddr_q_int <= to_integer(unsigned(waddr_q));

  po_data <= wdata_q; -- REG

  prs_wtarget_sel: process (waddr_q_int)
  begin

    wtarget <= NONE;
    reg_wsel <= 0;
    mem_wsel <= 0;
    ext_wsel <= 0;

    -- TODO this is a copy of the read address decoder, just a few renames.
    -- Move to a procedure or so... right?

    for i in 0 to G_MEMNAMES-1 loop
      if waddr_q_int-G_MEM_START(i) >= 0
      and waddr_q_int-(G_MEM_START(i)+2**G_MEM_AW(i)) < 0 then
        wtarget <= MEM;
        mem_wsel <= i;
      end if;
    end loop;

    for i in 0 to G_EXTCOUNT-1 loop
      if waddr_q_int-G_EXT_START(i) >= 0
      and waddr_q_int-(G_EXT_START(i)+G_EXT_SIZE(i)) < 0 then
        wtarget <= EXT;
        ext_wsel <= i;
      end if;
    end loop;

    for i in 0 to G_REGNAMES-1 loop
      for j in 0 to G_REGISTER_INFO(i).N-1 loop
        for k in 0 to G_REGISTER_INFO(i).M-1 loop
          if waddr_q_int = G_REGISTER_INFO(i).addr+4*(j*G_REGISTER_INFO(i).M+k) then
            wtarget <= REG;
            reg_wsel <= G_REGISTER_INFO(i).internal_offset+j*G_REGISTER_INFO(i).M+k;
          end if;
        end loop;
      end loop;
    end loop;

  end process;

  -- have separate processes for improved overview and less errors during
  -- development
  prs_axi_bvalid: process (state_write)
  begin
    case state_write is
      when ST_WriteResp =>
        S_AXI_BVALID <= '1';
      when others =>
        S_AXI_BVALID <= '0';
    end case;
  end process;

  prs_axi_awready: process (state_write)
  begin
    case state_write is
      when ST_WriteIdle | ST_WriteWaitAddr =>
        S_AXI_AWREADY <= '1';
      when others =>
        S_AXI_AWREADY <= '0';
    end case;
  end process;

  prs_axi_wready: process (state_write)
  begin
    case state_write is
      when ST_WriteIdle | ST_WriteWaitData =>
        S_AXI_WREADY <= '1';
      when others =>
        S_AXI_WREADY <= '0';
    end case;
  end process;

  S_AXI_BRESP <= "00";
end architecture;
