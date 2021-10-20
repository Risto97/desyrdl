-- BSD 3-Clause License
--
-- Copyright (c) 2020-2021 Deutsches Elektronen-Synchrotron DESY.
--
-- TODO Authors: Jan Marjanovic, Michael Buechler

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library desyrdl;
use desyrdl.common.all;

-- library desy;
-- use desy.common_axi.all;

entity decoder_axi4l is
  generic (
    g_addr_width    : integer := 32;
    g_data_width    : integer := 32;

    g_register_info  : t_reg_info_array;
    g_regitems       : integer := 0;
    g_regcount       : integer := 0;

    g_mem_info       : t_mem_info_array;
    g_memitems       : integer := 0;
    g_memcount       : integer := 0;

    g_ext_info       : t_ext_info_array;
    g_extitems       : integer := 0;
    g_extcount       : integer := 0
  );
  port (
    pi_clock  : in std_logic;
    pi_reset  : in std_logic;
    -- one element for each register, so N elements for a 2D register with length N

    po_reg_rd_stb  : out std_logic_vector(g_regcount-1 downto 0);
    po_reg_wr_stb  : out std_logic_vector(g_regcount-1 downto 0);
    po_reg_data    : out std_logic_vector(g_data_width-1 downto 0);
    pi_reg_data    : in  std_logic_vector(g_data_width-1 downto 0);
    --pi_reg_ack  : in  std_logic;

    po_mem_stb     : out std_logic_vector(g_memcount-1 downto 0);
    po_mem_we      : out std_logic;
    po_mem_addr    : out std_logic_vector(g_addr_width-1 downto 0);
    po_mem_data    : out std_logic_vector(g_data_width-1 downto 0);
    pi_mem_data    : in  std_logic_vector(g_data_width-1 downto 0);
    pi_mem_ack     : in  std_logic;

    pifi_ext    : in  tif_axi4l_s2m_array(G_EXTCOUNT downto 0);
    pifo_ext    : out tif_axi4l_m2s_array(G_EXTCOUNT downto 0);

    pifi_s_top  : in  tif_axi4l_m2s ;
    pifo_s_top  : out tif_axi4l_s2m

);
end entity decoder_axi4l;

architecture arch of decoder_axi4l is

  type t_target is (NONE, REG, MEM, EXT);
  signal rtarget, wtarget     : t_target := NONE;
--  signal rtarget_q, wtarget_q : t_target;

  ----------------------------------------------------------
  -- read
  type t_state_read is (
    ST_READ_IDLE,
    ST_READ_SELECT,
    ST_READ_VALID,
    ST_READ_REG_BUSY,
    ST_READ_MEM_BUSY,
    ST_READ_EXT_BUSY
  );
  signal state_read : t_state_read;

  signal rdata_reg : std_logic_vector(g_data_width-1 downto 0);
  signal rdata_mem : std_logic_vector(g_data_width-1 downto 0);
  signal rdata_ext : std_logic_vector(g_data_width-1 downto 0);

  signal rdata     : std_logic_vector(g_data_width-1 downto 0) := (others => '0');
  signal raddr     : std_logic_vector(g_addr_width-1 downto 0) := (others => '0');
  signal raddr_int : integer;

  -- select read
  signal reg_rd_stb  : std_logic_vector(g_regcount downto 0) := (others => '0');
  signal mem_rd_stb  : std_logic_vector(g_memcount downto 0) := (others => '0');
  signal mem_rd_req  : std_logic := '0';
  signal mem_rd_ack  : std_logic := '0';

  ----------------------------------------------------------
  -- write
  type t_state_write is (
    ST_WRITE_IDLE,
    ST_WRITE_WAIT_DATA,
    ST_WRITE_WAIT_ADDR,
    ST_WRITE_SELECT,
    ST_WRITE_MEM_BUSY,
    ST_WRITE_RESP
  );
  signal state_write : t_state_write;

  signal wdata     : std_logic_vector(g_data_width-1 downto 0) := (others => '0');
  signal waddr     : std_logic_vector(g_addr_width-1 downto 0) := (others => '0');
  signal waddr_int : integer;

  -- select write
  signal reg_wr_stb  : std_logic_vector(g_regcount downto 0) := (others => '0');
  signal mem_wr_stb  : std_logic_vector(g_memcount downto 0) := (others => '0');
  signal mem_wr_req  : std_logic := '0';
  signal mem_wr_ack  : std_logic := '0';

  -- memories
  -- signal mem_ren : std_logic_vector(G_MEMNAMES downto 0) := (others => '0');
  -- signal mem_rack : std_logic_vector(G_MEMNAMES downto 0) := (others => '0');
  -- signal mem_wen : std_logic_vector(G_MEMNAMES downto 0) := (others => '0');
  -- signal mem_wack : std_logic_vector(G_MEMNAMES downto 0) := (others => '0');

  -- -- downstream interfaces

  -- -- Oh you wanted to write to the same record from multiple processes?
  -- -- I don't care if the individual signals are indepentent SCREW YOU go
  -- -- and use separate signals for each.
  -- signal ext_arvalid : std_logic_vector (G_EXTCOUNT downto 0);
  -- signal ext_araddr : t_32b_slv_array (G_EXTCOUNT downto 0);
  -- signal ext_rready : std_logic_vector (G_EXTCOUNT downto 0);

  -- signal ext_awvalid : std_logic_vector (G_EXTCOUNT downto 0);
  -- signal ext_wvalid : std_logic_vector (G_EXTCOUNT downto 0);
  -- signal ext_bready : std_logic_vector (G_EXTCOUNT downto 0);
  -- signal ext_awaddr : t_32b_slv_array (G_EXTCOUNT downto 0);
  -- signal ext_wdata : t_32b_slv_array (G_EXTCOUNT downto 0);
  -- signal ext_wstrb : t_4b_slv_array (G_EXTCOUNT downto 0);

begin

  -- gen_ext_if : for i in G_EXTCOUNT-1 downto 0 generate
  --   po_ext(i).arvalid                                          <= ext_arvalid(i);
  --   po_ext(i).araddr(G_EXT_AW(i)-1 downto 0)                   <= ext_araddr(i)(G_EXT_AW(i)-1 downto 0);
  --   po_ext(i).araddr(po_ext(i).araddr'left downto G_EXT_AW(i)) <= (others => '0');
  --   po_ext(i).rready                                           <= ext_rready(i);
  --   po_ext(i).awvalid                                          <= ext_awvalid(i);
  --   po_ext(i).wvalid                                           <= ext_wvalid(i);
  --   po_ext(i).bready                                           <= ext_bready(i);
  --   po_ext(i).awaddr(G_EXT_AW(i)-1 downto 0)                   <= ext_awaddr(i)(G_EXT_AW(i)-1 downto 0);
  --   po_ext(i).awaddr(po_ext(i).awaddr'left downto G_EXT_AW(i)) <= (others => '0');
  --   po_ext(i).wdata(31 downto 0)                               <= ext_wdata(i);
  --   po_ext(i).wstrb(3 downto 0)                                <= ext_wstrb(i);
  -- end generate;

  -- ### read logic

  -- state transitions, assignment of extended state variables and assignment
  -- of output signals in one process
  prs_state_read: process (pi_clock)
  begin
    if rising_edge(pi_clock) then
      if pi_reset = '1' then
        state_read <= ST_READ_IDLE;

      else
        case state_read is
          when ST_READ_IDLE =>

            if pifi_s_top.arvalid = '1' then
              state_read <= ST_READ_SELECT;
            end if;

          when ST_READ_SELECT =>
            if rtarget = REG then
              state_read    <= ST_READ_VALID;

            elsif rtarget = MEM then
               state_read <= ST_READ_MEM_BUSY;
            --   mem_rsel_q <= mem_rsel;
            --   mem_ren(mem_rsel) <= '1';
            -- elsif rtarget = EXT then
            --   state_read <= ST_READ_EXT_BUSY;
            --   ext_rsel_q <= ext_rsel;
            --   ext_arvalid(ext_rsel) <= '1';
            --   ext_araddr(ext_rsel) <= raddr_q;
            --   ext_rready(ext_rsel) <= '1';
            else
              state_read <= ST_READ_REG_BUSY;
            end if;

          when ST_READ_REG_BUSY =>
            state_read <= ST_READ_VALID;
           -- rdata_reg <= pi_regs(reg_rsel_q);

          when ST_READ_MEM_BUSY =>
            if mem_rd_ack = '1' then
               state_read <= ST_READ_VALID;
            end if;

          -- when ST_READ_EXT_BUSY =>
          --   -- This state begins with ext_arvalid=1, so once we see a
          --   -- ready signal the addr or data was accepted.
          --   if pi_ext(ext_rsel_q).arready = '1' then
          --     ext_arvalid(ext_rsel_q) <= '0';
          --   end if;

          --   if pi_ext(ext_rsel_q).rvalid = '1' then
          --     state_read <= ST_READ_VALID;
          --     rdata_ext <= pi_ext(ext_rsel_q).rdata(31 downto 0);
          --     ext_rready(ext_rsel_q) <= '0';

          --     -- might be redundant
          --     ext_arvalid(ext_rsel_q) <= '0';
          --   end if;

          when ST_READ_VALID =>

            if pifi_s_top.rready = '1' then
              state_read <= ST_READ_IDLE;
            end if;

          when others =>
            state_read <= ST_READ_IDLE;
            -- mem_ren <= (others => '0');

        end case;

      end if;
    end if;
  end process;

  prs_rdata_mux: process(rtarget,rdata_reg,rdata_mem,rdata_ext)
  begin
    if rtarget = REG then
      pifo_s_top.rdata <= rdata_reg ;
    elsif rtarget = MEM then
      pifo_s_top.rdata <= rdata_mem ;
    else
      pifo_s_top.rdata <= rdata_ext ;
    end if;
  end process prs_rdata_mux;

  -- ARREADY flag handling
  prs_axi_arready: process (state_read)
  begin
    case state_read is
      when ST_READ_IDLE =>
        pifo_s_top.arready <= '1';
      when others =>
        pifo_s_top.arready <= '0';
    end case;
  end process;
  -- RVALID flag handling
  prs_axi_rvalid: process (state_read)
  begin
    case state_read is
      when ST_READ_VALID =>
        pifo_s_top.rvalid <= '1';
      when others =>
        pifo_s_top.rvalid <= '0';
    end case;
  end process;

  -- Address decoder
  -- TODO: check timing, if issues add one more state for addr decoding
  raddr_int <= to_integer(unsigned(pifi_s_top.araddr));


  prs_raddr_decoder: process(pi_clock)
  begin
    if rising_edge(pi_clock) then
      if state_read = ST_READ_IDLE and pifi_s_top.arvalid = '1' then
        rtarget    <= NONE;
        reg_rd_stb <= (others => '0');
        raddr      <= pifi_s_top.araddr;

        for i in 0 to g_regitems - 1 loop
          for j in 0 to g_register_info(i).dim_n-1 loop
            for k in 0 to g_register_info(i).dim_m-1 loop
              if raddr_int = g_register_info(i).address + 4 * (j * g_register_info(i).dim_m + k) then
                rtarget  <= REG;
                --reg_rsel <= g_register_info(i).item + j * g_register_info(i).dim_m + k;
                reg_rd_stb(g_register_info(i).index + j * g_register_info(i).dim_m + k) <= '1';
              end if;
            end loop;
          end loop;
        end loop;

        for i in 0 to g_memitems - 1  loop
          if raddr_int >= g_mem_info(i).address and raddr_int < g_mem_info(i).address + g_mem_info(i).entries then
            rtarget <= MEM;
            mem_rd_stb(i) <= '1';
            mem_rd_req    <= '1';
          end if;
        end loop;

      elsif state_read = ST_READ_VALID then
        --rtarget    <= NONE;
        reg_rd_stb <= (others => '0');
        mem_rd_stb <= (others => '0');
        mem_rd_req <= '0';
      end if;
    end if;
  end process prs_raddr_decoder;

  -- ### write logic
  prs_state_write: process (pi_clock)
  begin
    if rising_edge (pi_clock) then
      if pi_reset = '1' then
        state_write <= ST_WRITE_IDLE;

      else
        case state_write is
          when ST_WRITE_IDLE =>

            if pifi_s_top.awvalid = '1' and pifi_s_top.wvalid = '1' then
              state_write <= ST_WRITE_SELECT;
            elsif pifi_s_top.awvalid = '1' and pifi_s_top.wvalid = '0' then
              state_write <= ST_WRITE_WAIT_DATA;
            elsif pifi_s_top.awvalid = '0' and pifi_s_top.wvalid = '1' then
              state_write <= ST_WRITE_WAIT_ADDR;
            end if;

          when ST_WRITE_WAIT_DATA =>
            if pifi_s_top.wvalid = '1' then
              state_write <= ST_WRITE_SELECT;
            end if;

          when ST_WRITE_WAIT_ADDR =>
            if pifi_s_top.awvalid = '1' then
              state_write <= ST_WRITE_SELECT;
            end if;

          when ST_WRITE_SELECT =>
            if wtarget = REG then
              state_write <= ST_WRITE_RESP;

            elsif wtarget = MEM then
              state_write <= ST_WRITE_MEM_BUSY;
            --   mem_wsel_q <= mem_wsel;
            --   mem_wen(mem_wsel) <= '1';
            -- elsif wtarget = EXT then
            --   state_write <= ST_WriteExtBusy;
            --   ext_wsel_q <= ext_wsel;
            --   ext_awvalid(ext_wsel) <= '1';
            --   ext_awaddr(ext_wsel) <= waddr_q;
            --   ext_wvalid(ext_wsel) <= '1';
            --   ext_wdata(ext_wsel) <= wdata_q;
            --   ext_wstrb(ext_wsel) <= wstrb_q;
            --   ext_bready(ext_wsel) <= '1';
            else
              state_write <= ST_WRITE_RESP; -- every write transaction must end with response
            end if;

          when ST_WRITE_MEM_BUSY =>
            if mem_wr_ack = '1' then
              state_write <= ST_WRITE_RESP;
            end if;

          when ST_WRITE_RESP =>
            if pifi_s_top.bready = '1' then
              state_write <= ST_WRITE_IDLE;
            end if;

          when others =>
            state_write <= ST_WRITE_IDLE;

        end case;
      end if;
    end if;
  end process;

  -- AXI handshaking
  pifo_s_top.bresp <= "00";

  prs_axi_bvalid: process (state_write)
  begin
    case state_write is
      when ST_WRITE_RESP =>
        pifo_s_top.bvalid <= '1';
      when others =>
        pifo_s_top.bvalid <= '0';
    end case;
  end process;

  prs_axi_awready: process (state_write)
  begin
    case state_write is
      when ST_WRITE_IDLE | ST_WRITE_WAIT_ADDR =>
        pifo_s_top.awready <= '1';
      when others =>
        pifo_s_top.awready <= '0';
    end case;
  end process;

  prs_axi_wready: process (state_write)
  begin
    case state_write is
      when ST_WRITE_IDLE | ST_WRITE_WAIT_DATA =>
        pifo_s_top.wready <= '1';
      when others =>
        pifo_s_top.wready <= '0';
    end case;
  end process;

  -- Address decoder
  -- TODO: check timing, if issues add one more state for addr decoding
  waddr_int <= to_integer(unsigned(pifi_s_top.awaddr));


  prs_waddr_decoder: process(pi_clock)
  begin
    if rising_edge(pi_clock) then
      if (state_write = ST_WRITE_IDLE or state_write = ST_WRITE_WAIT_ADDR ) and pifi_s_top.awvalid = '1' then
        wtarget    <= NONE;
        reg_wr_stb <= (others => '0');
        waddr      <= pifi_s_top.awaddr ;

        for i in 0 to g_regitems-1 loop
          for j in 0 to g_register_info(i).dim_n-1 loop
            for k in 0 to g_register_info(i).dim_m-1 loop
              if waddr_int = g_register_info(i).address + 4 * (j * g_register_info(i).dim_m + k) then
                wtarget  <= REG;
                --reg_rsel <= g_register_info(i).item + j * g_register_info(i).dim_m + k;
                reg_wr_stb(g_register_info(i).index + j * g_register_info(i).dim_m + k) <= '1';
              end if;
            end loop;
          end loop;
        end loop;

        for i in 0 to g_memitems - 1  loop
          if waddr_int >= g_mem_info(i).address and raddr_int < g_mem_info(i).address + g_mem_info(i).entries then
            wtarget       <= MEM;
            mem_wr_stb(i) <= '1';
            mem_wr_req    <= '1';
          end if;
        end loop;

      elsif state_write = ST_WRITE_RESP then
        wtarget    <= NONE;
        reg_wr_stb <= (others => '0');
        mem_wr_stb <= (others => '0');
        mem_wr_req <= '0';
      end if;
    end if;
  end process prs_waddr_decoder;


  prs_wdata_reg : process(pi_clock)
  begin
    if rising_edge(pi_clock) then
      if state_write  = ST_WRITE_IDLE or state_write = ST_WRITE_WAIT_DATA then
        wdata <= pifi_s_top.wdata;
      end if;
    end if;
  end process prs_wdata_reg ;



  -- ===========================================================================
  -- registers
  --
  po_reg_rd_stb <= reg_rd_stb(g_regcount-1 downto 0);
  po_reg_wr_stb <= reg_wr_stb(g_regcount-1 downto 0);
  po_reg_data   <= wdata;
  rdata_reg     <= pi_reg_data ;

  -- ===========================================================================
  -- Dual-port memories
  --
  -- AXI address is addressing bytes
  -- DPM address is addressing the memory data width (up to 4 bytes)
  -- DPM data width is the same as the AXI data width
  -- currently only DPM interface supported with read/write arbiter
  -- write afer read
  blk_mem : block
    signal l_rwsel  : std_logic_vector(1 downto 0) := (others => '0');
    signal l_wr     : std_logic := '0';
    signal l_wr_trn : std_logic := '0';
    signal l_rd_ack : std_logic := '0';
    signal l_wr_ack : std_logic := '0';
  begin
    l_rwsel <= mem_rd_req & mem_wr_req;

    prs_rdwr_arb: process(pi_clock)
    begin
      if rising_edge(pi_clock) then

        -- write indicate transaction
        if mem_wr_req = '1' and mem_rd_req = '0' then
          l_wr_trn <= '1';
        elsif mem_wr_req = '0' then
          l_wr_trn <= '0';
        end if;

        -- read has higher priority, but do not disturb pending write transaction
        -- mem_rd_req goes to 0 for 1 clock cycle after each read transaction - write grant
        if mem_rd_req = '1' and l_wr_trn = '0' then
          for i in 0 to g_memitems - 1  loop
            if  mem_rd_stb(i) = '1' then
              po_mem_addr(g_mem_info(i).addrwidth-3 downto 0) <= raddr(g_mem_info(i).addrwidth-1 downto 2);
              po_mem_addr(g_addr_width-1 downto g_mem_info(i).addrwidth-2) <= (others => '0');
            end if;
          end loop;
          po_mem_stb <= mem_rd_stb(g_memitems-1 downto 0);
          po_mem_we  <= '0';
          l_rd_ack <= '1';

        elsif mem_wr_req = '1'  then
          for i in 0 to g_memitems - 1  loop
            if  mem_wr_stb(i) = '1' then
              po_mem_addr(g_mem_info(i).addrwidth-3 downto 0) <= waddr(g_mem_info(i).addrwidth-1 downto 2);
              po_mem_addr(g_addr_width-1 downto g_mem_info(i).addrwidth-2) <= (others => '0');
            end if;
          end loop;
          po_mem_stb <= mem_wr_stb(g_memitems-1 downto 0);
          po_mem_we  <= '1';
          l_wr_ack   <= '1';

        else
          po_mem_stb <= (others => '0');
          po_mem_we  <= '0';
          l_rd_ack   <= '0';
          l_wr_ack   <= '0';
        end if;
      end if;
    end process prs_rdwr_arb;

    mem_wr_ack <= l_wr_ack;
    mem_rd_ack <= l_rd_ack when rising_edge(pi_clock);
    -- delay read ack due to synch process of po_mem_addr and po_mem_stb,
    -- read requires one more clock cycle to get data back from memory

    po_mem_data <= wdata ;
    rdata_mem   <= pi_mem_data ;

  end block;
end architecture;
