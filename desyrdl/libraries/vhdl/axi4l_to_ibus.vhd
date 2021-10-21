-------------------------------------------------------------------------------
--          ____  _____________  __                                          --
--         / __ \/ ____/ ___/\ \/ /                 _   _   _                --
--        / / / / __/  \__ \  \  /                 / \ / \ / \               --
--       / /_/ / /___ ___/ /  / /               = ( M | S | K )=             --
--      /_____/_____//____/  /_/                   \_/ \_/ \_/               --
--                                                                           --
-------------------------------------------------------------------------------
--! @copyright  (c) 2021 DESY
--! @license    SPDX-License-Identifier: Apache-2.0
-------------------------------------------------------------------------------
--! @file axi4l_to_ibus.vhd
--! @brief AXI4-Lite to II (IBUS) translation, part of DesyRdl
-------------------------------------------------------------------------------
--! @author Lukasz Butkowski <lukasz.butkowski@desy.de>
--! @author Holger Kay <holger.kay@desy.de>
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

------------------------------------------------------------------------------
library desyrdl;
use desyrdl.common.all;

------------------------------------------------------------------------------
--! @brief AXI4 to II translation
entity axi4l_to_ibus is
  port (
    -- AXI4 slave port
    pi_reset          : in  std_logic;
    pi_clock          : in  std_logic;
    pifi_s_decoder    : in  tif_axi4l_m2s;
    pifo_s_decoder    : out tif_axi4l_s2m;
    -- IBUS interface
    pifo_m_ext        : out tif_ibus_m2s;
    pifi_m_ext        : in  tif_ibus_s2m
  );
  -- preserve synthesis optimization which brakes handshaking functionality
  attribute KEEP_HIERARCHY : string;
  attribute KEEP_HIERARCHY of axi4l_to_ibus : entity is "yes";
end axi4l_to_ibus;

------------------------------------------------------------------------------
architecture rtl of axi4l_to_ibus is

  type t_state is (ST_IDLE,
                   ST_READ_DATA_ADDR,
                   ST_READ_DATA,
                   ST_READ_DATA_WAIT,
                   ST_WRITE_DATA_ADDR,
                   ST_WRITE_DATA,
                   ST_WRITE_DATA_WAIT,
                   ST_WRITE_RESP,
                   ST_READ_DATA_PUSH,
                   ST_WAIT_AFTER_TRN);
  signal SIG_STATE   : t_state;
  signal SIG_LEN     : std_logic_vector(7 downto 0);

  signal SIG_RENA    : std_logic;
  signal SIG_WENA    : std_logic;
  signal SIG_ADDR    : std_logic_vector(31 downto 0) := (others => '0');

  signal SIG_M2S     : tif_axi4l_m2s := C_AXI4L_M2S_DEFAULT;
  signal SIG_S2M     : tif_axi4l_s2m := C_AXI4L_S2M_DEFAULT;

    -- signal SIG_WAIT_CNT : natural:=0;

  ---------------------------------------------------------------------------
begin

  -- unsed AXI4 Signals: SIG_M2S.AWSIZE  SIG_M2S.AWBURST  SIG_M2S.WSTRB
  -- unsed AXI4 Signals: SIG_M2S.ARSIZE  SIG_M2S.ARBURST  SIG_M2S.WLAST

  pifo_s_decoder   <= sig_s2m;
  sig_m2s          <= pifi_s_decoder;
  ------------------------------------
  sig_s2m.rresp    <=  "00";

  sig_s2m.bresp    <=  "00";

  pifo_m_ext.clk    <=  pi_clock;

  pifo_m_ext.addr   <=  sig_addr;
  pifo_m_ext.rena   <=  sig_rena when rising_edge(pi_clock); -- delay one clock cycle to have 1 clock cycle delay after data on bus
  pifo_m_ext.wena   <=  sig_wena when rising_edge(pi_clock);

  process(pi_clock)
  begin
    if rising_edge(pi_clock) then
      if (pi_reset = '1') then
        sig_state      <= ST_IDLE;
        sig_rena       <= '0';
        sig_wena       <= '0';
        sig_s2m.bvalid <= '0';
      else
        sig_rena <= '0';
        sig_wena <= '0';

        case sig_state is
          -------------------------------------
          when ST_IDLE =>

            if (sig_m2s.arvalid = '1') then
              sig_state <= ST_READ_DATA_ADDR;

            elsif (sig_m2s.awvalid = '1') then
              sig_state <= ST_WRITE_DATA_ADDR;

            end if;

          -------------------------------------
          when ST_WRITE_DATA_ADDR =>

            if (sig_m2s.awvalid = '1') then
              sig_addr  <= sig_m2s.awaddr;
              sig_state <= ST_WRITE_DATA;
            end if;

          -------------------------------------
          when ST_WRITE_DATA =>

            if (sig_m2s.wvalid = '1') then
              pifo_m_ext.data <= sig_m2s.wdata(31 downto 0);
              sig_wena        <= '1';
              sig_state       <= ST_WRITE_DATA_WAIT;
            end if;

          -------------------------------------
          when ST_WRITE_DATA_WAIT =>

            if pifi_m_ext.wack = '1' then
              sig_state      <= ST_WRITE_RESP;
              sig_s2m.bvalid <= '1';
            end if;

          -------------------------------------
          when st_write_resp =>
            if sig_m2s.bready = '1' then
              sig_s2m.bvalid <= '0';
              sig_state      <= ST_WAIT_AFTER_TRN;
            end if;

          -------------------------------------
          when ST_READ_DATA_ADDR =>

            if (sig_m2s.arvalid = '1') then
              sig_addr  <= sig_m2s.araddr;
              sig_state <= ST_READ_DATA;
            end if;

          -------------------------------------
          when ST_READ_DATA =>

            sig_rena  <= '1';
            sig_state <= ST_READ_DATA_WAIT;

          -------------------------------------
          when ST_READ_DATA_WAIT =>

            if pifi_m_ext.rack = '1' then
              sig_s2m.rdata(31 downto 0) <= pifi_m_ext.data;
              sig_state                  <= ST_READ_DATA_PUSH;
            end if;

          -------------------------------------
          when ST_READ_DATA_PUSH =>

            if sig_m2s.rready = '1' then
              -- if std_logic_vector(to_unsigned(sig_addr_cnt,8)) = sig_len then
              sig_state <= ST_WAIT_AFTER_TRN;
            -- else
            -- sig_addr_cnt <= sig_addr_cnt + 1 ;
            -- sig_addr   <= std_logic_vector(unsigned(sig_addr) + 4);
            -- sig_state  <= st_read_data ;
            -- end if;
            end if;

          -------------------------------------
          when ST_WAIT_AFTER_TRN =>
            -- if sig_wait_cnt >= 3 then
            sig_state <= ST_IDLE;
        -- else
        -- sig_wait_cnt <= sig_wait_cnt + 1;
        -- end if;
        end case;
      end if;
    end if;
  end process;

  proc_axi_hds : process(sig_state, sig_m2s)
  begin
    sig_s2m.arready <= '0';
    sig_s2m.awready <= '0';
    sig_s2m.wready  <= '0';
    sig_s2m.rvalid  <= '0';

    case sig_state is
      when st_read_data_addr =>
        sig_s2m.arready <= sig_m2s.arvalid;

      when st_write_data_addr =>
        sig_s2m.awready <= sig_m2s.awvalid;

      when st_write_data =>
        sig_s2m.wready <= sig_m2s.wvalid;

      when st_read_data_push =>
        sig_s2m.rvalid <= '1';

      when others =>
    end case;
  end process;

end rtl;
