-------------------------------------------------------------------------------
--          ____  _____________  __                                          --
--         / __ \/ ____/ ___/\ \/ /                 _   _   _                --
--        / / / / __/  \__ \  \  /                 / \ / \ / \               --
--       / /_/ / /___ ___/ /  / /               = ( M | S | K )=             --
--      /_____/_____//____/  /_/                   \_/ \_/ \_/               --
--                                                                           --
-------------------------------------------------------------------------------
-- $Header$
-------------------------------------------------------------------------------
--! @file   axi4_spi.vhd
--! @brief  AXI4-Lite bridge to an SPI interface
--! @author Holger Kay, Michael Buechler
--! @email  hkay@desy.de, michael.buechler@desy.de
--! $Date$
--! $Revision$
--! $URL$
--------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;

use work.PKG_TYPES.all;
use work.pkg_axi.all;

entity axi4_spi is
generic (
    g_clk_div   : natural := 1;      -- po_sclk = pi_ibus.CLK / [2*(g_clk_div +1)]
    g_bi_dir    : std_logic := '1'; -- SDIO bidirectional mode
    g_addr_width : positive := 8
  );
port (
    pi_clock   : in  std_logic;
    pi_reset   : in  std_logic;

    -- AXI4 Interface
    pi_axi4_m2s    : in  t_axi4_m2s;
    po_axi4_s2m    : out t_axi4_s2m;

    po_read    : out std_logic;
    po_busy    : out std_logic;

    -- SPI interface
    po_sclk    : out std_logic; -- serial clock
    po_cs_n    : out std_logic; -- chip select low activ
    po_buf_t   : out std_logic; -- SDIO buffer tristate
    po_sdout   : out std_logic; -- serial data output
    pi_sdin    : in  std_logic -- serial data input
);
end axi4_spi;



architecture Behavioral of axi4_spi is

    signal  clock       : std_logic;
    signal  state       : integer range 0 to 31 := 0;
    signal  freq_div    : natural;
    signal  addr        : std_logic_vector(31 downto 0);
    signal  data        : std_logic_vector(7 downto 0);
    signal  wena        : std_logic;
    signal  rena        : std_logic;
    signal  spi_dout    : std_logic_vector(23 downto 0);
    signal  reg_shift_out   : std_logic_vector(23 downto 0);
    signal  reg_shift_in    : std_logic_vector(7 downto 0);
    signal  shift_trg   : std_logic_vector(1 downto 0);
    signal  read        : std_logic;
    signal  sclk        : std_logic := '0';
    signal  cs_n        : std_logic := '1';
    signal  buf_t       : std_logic := '0';
    signal  spi_done    : std_logic := '0';
    signal  reg_sdin        : std_logic;

    type t_axi_state is (ST_IDLE, ST_RSTART, ST_WWAITADDR, ST_WWAITDATA, ST_WSTART, ST_READING, ST_WRITING, ST_RDONE, ST_WDONE);
    signal axi_state : t_axi_state;
    signal wdata_q : std_logic_vector (7 downto 0);
    signal addr_q : std_logic_vector (31 downto 0);
    constant C_ADDR_ZEROS : std_logic_vector (g_addr_width-1 downto 0) := (others => '0');

begin


    ---------------------------  II-bus interface  ---------------------------

    clock <= pi_clock;

    -- AXI4 logic
    process (clock)
    begin
      if rising_edge (clock) then
        if pi_reset = '1' then
          axi_state <= ST_IDLE;
          wena <= '0';
          rena <= '0';
          data <= (others => '0');
          addr <= (others => '0');

          po_axi4_s2m <= C_AXI4_S2M_DEFAULT;
        else
          -- Be explicit about default signal assignments to prevent weird
          -- synthesis results.
          axi_state <= axi_state;
          wena <= '0';
          rena <= '0';
          data <= data;
          addr <= addr;
          addr_q <= addr_q;
          wdata_q <= wdata_q;

          po_axi4_s2m.arready <= po_axi4_s2m.arready;
          po_axi4_s2m.awready <= po_axi4_s2m.awready;
          po_axi4_s2m.wready <= po_axi4_s2m.wready;
          po_axi4_s2m.rvalid <= po_axi4_s2m.rvalid;
          po_axi4_s2m.rdata <= po_axi4_s2m.rdata;
          po_axi4_s2m.bvalid <= po_axi4_s2m.bvalid;

          case axi_state is
            when ST_IDLE =>
              po_axi4_s2m.arready <= '1';
              po_axi4_s2m.awready <= '1';
              po_axi4_s2m.wready <= '1';

              -- Read and write transactions can't be handled simultaneously.
              -- Give write transactions precedence. FIXME the other one is
              -- lost.
              if pi_axi4_m2s.awvalid = '1' and pi_axi4_m2s.wvalid = '1' then
                axi_state <= ST_WSTART;
                wdata_q <= pi_axi4_m2s.wdata(7 downto 0);
                addr_q <= pi_axi4_m2s.awaddr;

                po_axi4_s2m.wready <= '0';
                po_axi4_s2m.awready <= '0';
                po_axi4_s2m.arready <= '0';

              elsif pi_axi4_m2s.awvalid = '1' and pi_axi4_m2s.wvalid = '0' then
                axi_state <= ST_WWAITDATA;
                addr_q <= pi_axi4_m2s.awaddr;

                po_axi4_s2m.awready <= '0';
                po_axi4_s2m.arready <= '0';

              elsif pi_axi4_m2s.awvalid = '0' and pi_axi4_m2s.wvalid = '1' then
                axi_state <= ST_WWAITADDR;
                wdata_q <= pi_axi4_m2s.wdata(7 downto 0);

                po_axi4_s2m.wready <= '0';
                po_axi4_s2m.arready <= '0';

              elsif pi_axi4_m2s.ARVALID = '1' then
                axi_state <= ST_RSTART;
                addr_q <= pi_axi4_m2s.araddr;

                po_axi4_s2m.wready <= '0';
                po_axi4_s2m.awready <= '0';
                po_axi4_s2m.arready <= '0';

              end if;

            when ST_WWAITDATA =>
              if pi_axi4_m2s.wvalid = '1' then
                axi_state <= ST_WRITING;
                wdata_q <= pi_axi4_m2s.wdata(7 downto 0);
              end if;

            when ST_WWAITADDR =>
              if pi_axi4_m2s.awvalid = '1' then
                axi_state <= ST_WRITING;
                addr_q <= pi_axi4_m2s.awaddr;
              end if;

            when ST_WSTART =>
              axi_state <= ST_WRITING;
              wena <= '1';
              addr <= addr_q;
              data <= wdata_q;

            when ST_WRITING =>
              if spi_done = '1' then
                axi_state <= ST_WDONE;
                po_axi4_s2m.bvalid <= '1';
              end if;

            when ST_WDONE =>
              if pi_axi4_m2s.bready = '1' then
                axi_state <= ST_IDLE;
                po_axi4_s2m.bvalid <= '0';
                po_axi4_s2m.arready <= '1';
                po_axi4_s2m.wready <= '1';
                po_axi4_s2m.awready <= '1';
              end if;

            when ST_RSTART =>
              axi_state <= ST_READING;
              rena <= '1';
              addr <= addr_q;

            when ST_READING =>
              if spi_done = '1' then
                axi_state <= ST_RDONE;
                po_axi4_s2m.rvalid <= '1';
                po_axi4_s2m.rdata(31 downto 0) <= x"000000" & reg_shift_in;
              end if;

            when ST_RDONE =>
              if pi_axi4_m2s.rready = '1' then
                axi_state <= ST_IDLE;
                po_axi4_s2m.rvalid <= '0';
                po_axi4_s2m.arready <= '1';
                po_axi4_s2m.wready <= '1';
                po_axi4_s2m.awready <= '1';
              end if;

          end case;
        end if;
      end if;
    end process;


    process (clock)
    begin
      if rising_edge (clock) then
        if pi_reset = '1' then
          po_busy <= '0';
        else
          po_busy <= pi_reset or rena or wena or not cs_n;
        end if;
      end if;
    end process;

    spi_dout(23) <= rena;
    spi_dout(22 downto g_addr_width+8) <= (others => '0');
    spi_dout(g_addr_width+8-1 downto 8) <= addr(g_addr_width-1 downto 0);

    spi_dout(3 downto 0) <= data(3 downto 0);

    spi_dout(5) <= data(5);

    -- control port configuration in register addr 0 must not be overwritten

    spi_dout(4) <= data(4) when (addr(1+g_addr_width downto 2) /= C_ADDR_ZEROS) else '1'; -- Long Instruction

    spi_dout(6) <= data(6) when (addr(1+g_addr_width downto 2) /= C_ADDR_ZEROS) else '0'; -- LSB first

    spi_dout(7) <= data(7) when (addr(1+g_addr_width downto 2) /= C_ADDR_ZEROS) else g_bi_dir; -- SDIO bidirectional mode



    ---------------------------  SPI  ---------------------------

    po_cs_n  <= cs_n;
    po_read  <= read; -- for debugging


    process(pi_reset, clock)
    begin
        if (pi_reset = '1') then

            spi_done <= '0';
            freq_div <= 0;
            buf_t <= '0';
            state <= 0;
            cs_n <= '1';
            sclk <= '0';
            po_sclk <= '0';
            po_sdout <= '0';
            po_buf_t <= '0';

        elsif (rising_edge(clock)) then

            shift_trg <= shift_trg(0) & '0';
            spi_done <= '0';

            po_sclk  <= sclk;
            po_sdout <= reg_shift_out(23);
            po_buf_t <= buf_t;
            reg_sdin  <= pi_sdin;

            if (state = 0 or freq_div = 0) then
                freq_div <= g_clk_div;
            else
                freq_div <= freq_div -1;
            end if;

            if (state = 0 and (rena xor wena) = '1') then -- wait for start
                reg_shift_out <= spi_dout;
                state <= state +1;
                read  <= rena;
                cs_n  <= '0';
            end if;

            if (state /= 0 and state <= 24 and freq_div = 0) then
                if (sclk = '1') then -- shift data out on falling edge of SCLK
                    shift_trg(0) <= '1';
                    reg_shift_out <= reg_shift_out(22 downto 0) & '0';
                    state <= state +1;
                    sclk <= '0';
                else
                    sclk <= '1';
                end if;
            end if;

            if (shift_trg(1) = '1') then -- shift data in two clock cycle after shift out
                reg_shift_in <= reg_shift_in(6 downto 0) & reg_sdin;
            end if;

            if (state = 16 and freq_div = 0 and sclk = '1') then
                buf_t <= read; -- set buffer tristate to read data
            end if;

            if (state = 25 and freq_div = 0 and shift_trg = "00") then -- finish opperation
                spi_done <= '1';
                state <= state +1;
                buf_t <= '0';
                cs_n  <= '1';
            end if;

            if (state = 26 and rena = '0' and wena = '0') then
                state <= 0;
            end if;

        end if;
    end process;

end Behavioral;
