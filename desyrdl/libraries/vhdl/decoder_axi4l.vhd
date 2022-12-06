------------------------------------------------------------------------------
--          ____  _____________  __                                         --
--         / __ \/ ____/ ___/\ \/ /                 _   _   _               --
--        / / / / __/  \__ \  \  /                 / \ / \ / \              --
--       / /_/ / /___ ___/ /  / /               = ( M | S | K )=            --
--      /_____/_____//____/  /_/                   \_/ \_/ \_/              --
--                                                                          --
------------------------------------------------------------------------------
--! @copyright Copyright 2020-2022 DESY
--! SPDX-License-Identifier: Apache-2.0
------------------------------------------------------------------------------
--! @date 2020-05-25/2021-10-12
--! @author Michael Büchler <michael.buechler@desy.de>
--! @author Lukasz Butkowski <lukasz.butkowski@desy.de>
--! @author Jan Marjanovic <jan.marjanovic@desy.de>
------------------------------------------------------------------------------
--! @brief
--! ax4-lite address decoder for DesyRdl
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library desyrdl;
use desyrdl.common.all;

-- library desy;
-- use desy.common_axi.all;

entity decoder_axi4l is
  generic (
    G_ADDR_WIDTH    : integer := 32;
    G_DATA_WIDTH    : integer := 32;

    G_REGISTER_INFO  : t_reg_info_array;
    G_REGITEMS       : integer := 0;
    G_REGCOUNT       : integer := 0;

    G_MEM_INFO       : t_mem_info_array;
    G_MEMITEMS       : integer := 0;
    G_MEMCOUNT       : integer := 0;

    G_EXT_INFO       : t_ext_info_array;
    G_EXTITEMS       : integer := 0;
    G_EXTCOUNT       : integer := 0
  );
  port (
    pi_clock  : in std_logic;
    pi_reset  : in std_logic;
    -- one element for each register, so N elements for a 2D register with length N

    po_reg_rd_stb  : out std_logic_vector(G_REGCOUNT-1 downto 0);
    po_reg_wr_stb  : out std_logic_vector(G_REGCOUNT-1 downto 0);
    po_reg_data    : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
    pi_reg_data    : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);
    --pi_reg_ack  : in  std_logic;

    po_mem_stb     : out std_logic_vector(G_MEMCOUNT-1 downto 0);
    po_mem_we      : out std_logic;
    po_mem_addr    : out std_logic_vector(G_ADDR_WIDTH-1 downto 0);
    po_mem_data    : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
    pi_mem_data    : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);
    pi_mem_ack     : in  std_logic;

    pi_ext    : in  t_axi4l_s2m_array(G_EXTCOUNT-1 downto 0);
    po_ext    : out t_axi4l_m2s_array(G_EXTCOUNT-1 downto 0);

    pi_s_top  : in  t_axi4l_m2s ;
    po_s_top  : out t_axi4l_s2m

);
end entity decoder_axi4l;

architecture arch of decoder_axi4l is

  type t_target is (NONE, REG, MEM, EXT);
  signal rtarget, wtarget  : t_target := NONE;

  ----------------------------------------------------------
  -- read
  type t_state_read is (
    ST_READ_IDLE,
    ST_READ_SELECT,
    ST_READ_VALID,
    ST_READ_DONE,
    ST_READ_REG_BUSY,
    ST_READ_MEM_BUSY,
    ST_READ_EXT_ADDR,
    ST_READ_EXT_BUSY
  );
  signal state_read : t_state_read;

  signal rdata_reg : std_logic_vector(G_DATA_WIDTH-1 downto 0);
  signal rdata_mem : std_logic_vector(G_DATA_WIDTH-1 downto 0);
  signal rdata_ext : std_logic_vector(G_DATA_WIDTH-1 downto 0);

  signal rdata     : std_logic_vector(G_DATA_WIDTH-1 downto 0) := (others => '0');
  signal raddr     : std_logic_vector(G_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal raddr_int : INTEGER;

  -- select read
  signal reg_rd_stb  : std_logic_vector(G_REGCOUNT-1 downto 0) := (others => '0');
  signal ext_rd_stb  : std_logic_vector(G_EXTCOUNT-1 downto 0) := (others => '0');
  signal mem_rd_stb  : std_logic_vector(G_MEMCOUNT-1 downto 0) := (others => '0');
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
    ST_WRITE_EXT_BUSY,
    ST_WRITE_RESP
  );
  signal state_write : t_state_write;

  signal wdata     : std_logic_vector(G_DATA_WIDTH-1 downto 0) := (others => '0');
  signal wstrb     : std_logic_vector(G_DATA_WIDTH/8-1 downto 0) := (others => '0');
  signal waddr     : std_logic_vector(G_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal waddr_int : INTEGER;

  -- select write
  signal reg_wr_stb  : std_logic_vector(G_REGCOUNT-1 downto 0) := (others => '0');
  signal ext_wr_stb  : std_logic_vector(G_EXTCOUNT-1 downto 0) := (others => '0');
  signal mem_wr_stb  : std_logic_vector(G_MEMCOUNT-1 downto 0) := (others => '0');
  signal mem_wr_req  : std_logic := '0';
  signal mem_wr_ack  : std_logic := '0';

  -- external bus
  signal ext_arvalid : std_logic := '0';
  signal ext_arready : std_logic := '0';
  signal ext_rready  : std_logic := '0';
  signal ext_rvalid  : std_logic := '0';
  signal ext_awvalid : std_logic := '0';
  signal ext_awready : std_logic := '0';
  signal ext_wvalid  : std_logic := '0';
  signal ext_wready  : std_logic := '0';
  signal ext_bvalid  : std_logic := '0';
  signal ext_bready  : std_logic := '0';

  constant read_timeout  : natural := 8191;
  constant write_timeout : natural := 8191;
  signal read_time_cnt   : natural := 0;
  signal write_time_cnt  : natural := 0;
  signal invalid_rdata   : std_logic ;
begin

  -- ===========================================================================
  -- ### read logic
  ------------------------------------------------------------------------------
  -- read channel state machine
  ------------------------------------------------------------------------------
  prs_state_read: process (pi_clock)
  begin
    if rising_edge(pi_clock) then
      if pi_reset = '1' then
        state_read <= ST_READ_IDLE;
        ext_arvalid <= '0'; -- TODO axi ext move to separate process
        read_time_cnt <= 0;
        invalid_rdata <= '0';
      else
        case state_read is
          when ST_READ_IDLE =>

            if pi_s_top.arvalid = '1' then
              state_read <= ST_READ_SELECT;
            end if;

            ext_arvalid   <= '0';
            read_time_cnt <= 0;
            invalid_rdata <= '0';
          when ST_READ_SELECT =>
            if rtarget = REG then
              state_read    <= ST_READ_VALID;

            elsif rtarget = MEM then
              state_read <= ST_READ_MEM_BUSY;

            elsif rtarget = EXT then
              ext_arvalid <= '1';
              state_read  <= ST_READ_EXT_ADDR;

            else
              state_read <= ST_READ_REG_BUSY;
            end if;

          when ST_READ_REG_BUSY =>
            state_read <= ST_READ_VALID;

          when ST_READ_MEM_BUSY =>
            read_time_cnt <= read_time_cnt + 1;
            if mem_rd_ack = '1' then
               state_read <= ST_READ_VALID;
            elsif read_time_cnt >= read_timeout then
              invalid_rdata <= '1';
              state_read <= ST_READ_VALID;
            end if;

          when ST_READ_EXT_ADDR =>
            read_time_cnt <= read_time_cnt + 1;

            if ext_arready = '1' then
              ext_arvalid  <= '0';
              read_time_cnt <= 0;
              state_read <= ST_READ_EXT_BUSY ;
            elsif read_time_cnt >= read_timeout then
              invalid_rdata <= '1';
              state_read <= ST_READ_VALID;
            end if;

          when ST_READ_EXT_BUSY =>
            read_time_cnt <= read_time_cnt + 1;

            if ext_rvalid = '1' and pi_s_top.rready = '1' then
              state_read <= ST_READ_DONE;
            elsif read_time_cnt >= read_timeout then
              invalid_rdata <= '1';
              state_read <= ST_READ_VALID;
            end if;

          when ST_READ_VALID =>
            if pi_s_top.rready = '1' then
              state_read <= ST_READ_DONE;
            end if;

          when ST_READ_DONE =>
              state_read <= ST_READ_IDLE;

          when others =>
            state_read <= ST_READ_IDLE;

        end case;

      end if;
    end if;
  end process;

  ext_rready <= pi_s_top.rready;

  po_s_top.rresp <= "00";

  ------------------------------------------------------------------------------
  -- read data mux
  prs_rdata_mux: process(rtarget,rdata_reg,rdata_mem,rdata_ext,invalid_rdata)
  begin
    if invalid_rdata = '1' then
      po_s_top.rdata <= (others => '0' ) ;
    elsif rtarget = REG then
      po_s_top.rdata <= rdata_reg ;
    elsif rtarget = MEM then
      po_s_top.rdata <= rdata_mem ;
    elsif rtarget = EXT then
      po_s_top.rdata <= rdata_ext ;
    end if;
  end process prs_rdata_mux;

  ------------------------------------------------------------------------------
  -- ARREADY flag handling
  prs_axi_arready: process (state_read)
  begin
    case state_read is
      when ST_READ_IDLE =>
        po_s_top.arready <= '1';
      when others =>
        po_s_top.arready <= '0';
    end case;
  end process;
  -- RVALID flag handling
  prs_axi_rvalid: process (state_read, ext_rvalid)
  begin
    case state_read is
      when ST_READ_EXT_BUSY =>
        po_s_top.rvalid <= ext_rvalid;
      when ST_READ_VALID =>
        po_s_top.rvalid <= '1';
      when others =>
        po_s_top.rvalid <= '0';
    end case;
  end process;

  ------------------------------------------------------------------------------
  -- Address decoder
  ------------------------------------------------------------------------------
  raddr_int <= to_integer(unsigned(pi_s_top.araddr(G_ADDR_WIDTH-1 downto 0)));

  prs_raddr_decoder: process(pi_clock)
  begin
    if rising_edge(pi_clock) then
      if state_read = ST_READ_IDLE and pi_s_top.arvalid = '1' then
        rtarget    <= NONE;
        reg_rd_stb <= (others => '0');
        raddr      <= pi_s_top.araddr(G_ADDR_WIDTH-1 downto 0);

        for i in 0 to G_REGITEMS - 1 loop
          for j in 0 to G_REGISTER_INFO(i).dim_n-1 loop
            for k in 0 to G_REGISTER_INFO(i).dim_m-1 loop
              if raddr_int = G_REGISTER_INFO(i).address + 4 * (j * G_REGISTER_INFO(i).dim_m + k) then
                rtarget  <= REG;
                --reg_rsel <= G_REGISTER_INFO(i).item + j * G_REGISTER_INFO(i).dim_m + k;
                reg_rd_stb(G_REGISTER_INFO(i).index + j * G_REGISTER_INFO(i).dim_m + k) <= '1';
              end if;
            end loop;
          end loop;
        end loop;

        for i in 0 to G_MEMITEMS - 1  loop
          if raddr_int >= G_MEM_INFO(i).address and raddr_int < G_MEM_INFO(i).address + G_MEM_INFO(i).entries * 4 then
            rtarget <= MEM;
            mem_rd_stb(i) <= '1';
            mem_rd_req    <= '1';
          end if;
        end loop;

        for i in 0 to G_EXTITEMS - 1  loop
          if raddr_int >= G_EXT_INFO(i).address and raddr_int < G_EXT_INFO(i).address + G_EXT_INFO(i).size then
            rtarget <= EXT;
            ext_rd_stb(i) <= '1';
          end if;
        end loop;

      elsif state_read = ST_READ_DONE then
        --rtarget    <= NONE;
        if G_REGITEMS > 0 then
          reg_rd_stb <= (others => '0');
        end if;
        if G_EXTITEMS > 0 then
          ext_rd_stb <= (others => '0');
        end if;
        if G_MEMITEMS > 0 then
          mem_rd_stb <= (others => '0');
        end if;
        mem_rd_req <= '0';
      end if;
    end if;
  end process prs_raddr_decoder;


  -- ===========================================================================
  -- ### write logic
  ------------------------------------------------------------------------------
  -- Write channel state machine
  ------------------------------------------------------------------------------
  prs_state_write: process (pi_clock)
  begin
    if rising_edge (pi_clock) then
      if pi_reset = '1' then
        state_write <= ST_WRITE_IDLE;
        ext_awvalid <= '0'; -- TODO move axi ext to separate process
        ext_wvalid  <= '0';
        ext_bready  <= '0';
        write_time_cnt <= 0;
      else
        case state_write is
          when ST_WRITE_IDLE =>

            if pi_s_top.awvalid = '1' and pi_s_top.wvalid = '1' then
              state_write <= ST_WRITE_SELECT;
            elsif pi_s_top.awvalid = '1' and pi_s_top.wvalid = '0' then
              state_write <= ST_WRITE_WAIT_DATA;
            elsif pi_s_top.awvalid = '0' and pi_s_top.wvalid = '1' then
              state_write <= ST_WRITE_WAIT_ADDR;
            end if;

            ext_awvalid <= '0';
            ext_wvalid  <= '0';
            ext_bready  <= '0';
            write_time_cnt <= 0;

          when ST_WRITE_WAIT_DATA =>
            if pi_s_top.wvalid = '1' then
              state_write <= ST_WRITE_SELECT;
            end if;

          when ST_WRITE_WAIT_ADDR =>
            if pi_s_top.awvalid = '1' then
              state_write <= ST_WRITE_SELECT;
            end if;

          when ST_WRITE_SELECT =>
            if wtarget = REG then
              state_write <= ST_WRITE_RESP;

            elsif wtarget = MEM then
              state_write <= ST_WRITE_MEM_BUSY;

            elsif wtarget = EXT then
              ext_awvalid <= '1';
              ext_wvalid  <= '1';
              ext_bready  <= '1';
              state_write <= ST_WRITE_EXT_BUSY;

            else
              state_write <= ST_WRITE_RESP; -- every write transaction must end with response
            end if;

          when ST_WRITE_MEM_BUSY =>
            write_time_cnt <= write_time_cnt + 1;

            if mem_wr_ack = '1' then
              state_write <= ST_WRITE_RESP;
            elsif write_time_cnt >= write_timeout then
              state_write <= ST_WRITE_RESP;
            end if;

          when ST_WRITE_EXT_BUSY =>
            write_time_cnt <= write_time_cnt + 1;

            if ext_awready = '1' then
              ext_awvalid  <= '0';
            end if;

            if ext_wready = '1' then
              ext_wvalid <= '0';
            end if;

            if ext_bvalid = '1' then
              ext_bready <= '0';
              state_write <= ST_WRITE_RESP;
            elsif write_time_cnt >= write_timeout then
              state_write <= ST_WRITE_RESP;
            end if;

          when ST_WRITE_RESP =>
            if pi_s_top.bready = '1' then
              state_write <= ST_WRITE_IDLE;
            end if;

          when others =>
            state_write <= ST_WRITE_IDLE;

        end case;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- WRITE AXI handshaking
  po_s_top.bresp <= "00";

  prs_axi_bvalid: process (state_write)
  begin
    case state_write is
      when ST_WRITE_RESP =>
        po_s_top.bvalid <= '1';
      when others =>
        po_s_top.bvalid <= '0';
    end case;
  end process;

  prs_axi_awready: process (state_write)
  begin
    case state_write is
      when ST_WRITE_IDLE | ST_WRITE_WAIT_ADDR =>
        po_s_top.awready <= '1';
      when others =>
        po_s_top.awready <= '0';
    end case;
  end process;

  prs_axi_wready: process (state_write)
  begin
    case state_write is
      when ST_WRITE_IDLE | ST_WRITE_WAIT_DATA =>
        po_s_top.wready <= '1';
      when others =>
        po_s_top.wready <= '0';
    end case;
  end process;

  ------------------------------------------------------------------------------
  -- write Address decoder
  ------------------------------------------------------------------------------
  waddr_int <= to_integer(unsigned(pi_s_top.awaddr(G_ADDR_WIDTH-1 downto 0)));

  prs_waddr_decoder: process(pi_clock)
  begin
    if rising_edge(pi_clock) then
      if (state_write = ST_WRITE_IDLE or state_write = ST_WRITE_WAIT_ADDR ) and pi_s_top.awvalid = '1' then
        wtarget    <= NONE;
        reg_wr_stb <= (others => '0');
        waddr      <= pi_s_top.awaddr(G_ADDR_WIDTH-1 downto 0) ;

        for i in 0 to G_REGITEMS-1 loop
          for j in 0 to G_REGISTER_INFO(i).dim_n-1 loop
            for k in 0 to G_REGISTER_INFO(i).dim_m-1 loop
              if waddr_int = G_REGISTER_INFO(i).address + 4 * (j * G_REGISTER_INFO(i).dim_m + k) then
                wtarget  <= REG;
                --reg_rsel <= G_REGISTER_INFO(i).item + j * G_REGISTER_INFO(i).dim_m + k;
                reg_wr_stb(G_REGISTER_INFO(i).index + j * G_REGISTER_INFO(i).dim_m + k) <= '1';
              end if;
            end loop;
          end loop;
        end loop;

        for i in 0 to G_MEMITEMS - 1  loop
          if waddr_int >= G_MEM_INFO(i).address and waddr_int < G_MEM_INFO(i).address + G_MEM_INFO(i).entries * 4 then
            wtarget       <= MEM;
            mem_wr_stb(i) <= '1';
            mem_wr_req    <= '1';
          end if;
        end loop;

        for i in 0 to G_EXTITEMS - 1  loop
          if waddr_int >= G_EXT_INFO(i).address and waddr_int < G_EXT_INFO(i).address + G_EXT_INFO(i).size then
            wtarget <= EXT;
            ext_wr_stb(i) <= '1';
          end if;
        end loop;

      elsif state_write = ST_WRITE_RESP then
        --wtarget    <= NONE;
        if G_REGITEMS > 0 then
          reg_wr_stb <= (others => '0');
        end if;
        if G_EXTITEMS > 0 then
          ext_wr_stb <= (others => '0');
        end if;
        if G_MEMITEMS > 0 then
          mem_wr_stb <= (others => '0');
        end if;
        mem_wr_req <= '0';
      end if;
    end if;
  end process prs_waddr_decoder;


  prs_wdata_reg : process(pi_clock)
  begin
    if rising_edge(pi_clock) then
      if state_write  = ST_WRITE_IDLE or state_write = ST_WRITE_WAIT_DATA then
        wdata <= pi_s_top.wdata;
        wstrb <= pi_s_top.wstrb;
      end if;
    end if;
  end process prs_wdata_reg ;



  -- ===========================================================================

  -- ===========================================================================
  -- registers
  ------------------------------------------------------------------------------
  po_reg_rd_stb <= reg_rd_stb;
  po_reg_wr_stb <= reg_wr_stb;
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
  ------------------------------------------------------------------------------
  blk_mem : block
    signal l_wr_trn : std_logic := '0';
    signal l_rd_ack : std_logic := '0';
    signal l_wr_ack : std_logic := '0';
  begin

    prs_rdwr_arb: process(pi_clock)
    begin
      if rising_edge(pi_clock) then

        -- write transaction indicate
        if mem_wr_req = '1' and mem_rd_req = '0' then
          l_wr_trn <= '1';
        elsif mem_wr_req = '0' then
          l_wr_trn <= '0';
        end if;

        -- read has higher priority, but do not disturb pending write transaction
        -- mem_rd_req goes to 0 for 1 clock cycle after each read transaction - write grant
        if mem_rd_req = '1' and l_wr_trn = '0' then
          for i in 0 to G_MEMITEMS - 1  loop
            if  mem_rd_stb(i) = '1' then
              po_mem_addr(G_MEM_INFO(i).addrwidth-3 downto 0) <= raddr(G_MEM_INFO(i).addrwidth-1 downto 2);
              po_mem_addr(G_ADDR_WIDTH-1 downto G_MEM_INFO(i).addrwidth-2) <= (others => '0');
            end IF;
          end loop;
          po_mem_stb <= mem_rd_stb;
          po_mem_we  <= '0';
          l_rd_ack <= '1';

        elsif mem_wr_req = '1'  then
          for i in 0 to G_MEMITEMS - 1  loop
            if  mem_wr_stb(i) = '1' then
              po_mem_addr(G_MEM_INFO(i).addrwidth-3 downto 0) <= waddr(G_MEM_INFO(i).addrwidth-1 downto 2);
              po_mem_addr(G_ADDR_WIDTH-1 downto G_MEM_INFO(i).addrwidth-2) <= (others => '0');
            end IF;
          end loop;
          po_mem_stb <= mem_wr_stb;
          po_mem_we  <= '1';
          l_wr_ack   <= '1';

        else
          po_mem_stb <= (others => '0');
          po_mem_we  <= '0';
          l_rd_ack   <= '0';
          l_wr_ack   <= '0';
        end IF;
      end IF;
    end process prs_rdwr_arb;

    mem_wr_ack <= l_wr_ack;
    mem_rd_ack <= l_rd_ack when rising_edge(pi_clock);
    -- delay read ack due to synch process of po_mem_addr and po_mem_stb,
    -- read requires one more clock cycle to get data back from memory
    -- possible in future: change of interface to use pi_mem_ack
    gen_no_mem: if G_MEMITEMS= 0 generate
      po_mem_addr <= (others => '0');
      po_mem_stb  <= (others => '0');
      --po_mem_data <= (others => '0');
    end generate;

    po_mem_data <= wdata ;
    rdata_mem   <= pi_mem_data ;

  end block;


  -- ===========================================================================
  -- external buses -- the same type as upstream bus: axi4l
  ------------------------------------------------------------------------------
  gen_ext_if : for idx in 0 to G_EXTITEMS-1 generate
    po_ext(idx).arvalid                                          <= ext_arvalid and ext_rd_stb(idx);
    po_ext(idx).araddr(G_EXT_INFO(idx).addrwidth - 1 downto 0)   <= raddr(G_EXT_INFO(idx).addrwidth - 1 downto 0);
    po_ext(idx).araddr(po_ext(idx).araddr'left downto G_EXT_INFO(idx).addrwidth) <= (others => '0');
    po_ext(idx).rready                                           <= ext_rready; -- and ext_rd_stb(idx);
    -- po_ext(idx).rready                                           <= pi_s_top.rready and ext_rd_stb(idx);

    po_ext(idx).awvalid                                          <= ext_awvalid and ext_wr_stb(idx);
    po_ext(idx).awaddr(G_EXT_INFO(idx).addrwidth - 1 downto 0)   <= waddr(G_EXT_INFO(idx).addrwidth - 1 downto 0);
    po_ext(idx).awaddr(po_ext(idx).awaddr'left downto G_EXT_INFO(idx).addrwidth) <= (others => '0');
    po_ext(idx).wvalid                                           <= ext_wvalid and ext_wr_stb(idx);
    po_ext(idx).wdata(31 downto 0)                               <= wdata;
    po_ext(idx).wstrb(3 downto 0)                                <= wstrb;
    po_ext(idx).bready                                           <= ext_bready;-- and ext_wr_stb(idx);
  end generate;

  prs_ext_rd_mux: process(ext_rd_stb,pi_ext)
  begin
    ext_arready <= '0';
    ext_rvalid  <= '0';
    rdata_ext   <= (others => '0');
    -- if rising_edge(pi_clock) then
      for idx in 0 to G_EXTITEMS-1 loop
        if ext_rd_stb(idx) = '1' then
          ext_arready <= pi_ext(idx).arready;
          ext_rvalid  <= pi_ext(idx).rvalid;
          rdata_ext   <= pi_ext(idx).rdata;
        end IF;
      end loop;
    -- end IF;
  end process prs_ext_rd_mux;

  prs_ext_wr_mux: process(ext_wr_stb,pi_ext)
  begin
    ext_awready <= '0';
    ext_wready  <= '0';
    ext_bvalid  <= '0';
    -- if rising_edge(pi_clock) then
      for idx in 0 to G_EXTITEMS-1 loop
        if ext_wr_stb(idx) = '1' then
          ext_awready <= pi_ext(idx).awready;
          ext_wready  <= pi_ext(idx).wready;
          ext_bvalid  <= pi_ext(idx).bvalid;
        end IF;
      end loop;
    -- end IF;
  end process prs_ext_wr_mux;

end architecture;
