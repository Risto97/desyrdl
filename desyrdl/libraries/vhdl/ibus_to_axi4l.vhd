--------------------------------------------------------------------------------
--          ____  _____________  __                                           --
--         / __ \/ ____/ ___/\ \/ /                 _   _   _                 --
--        / / / / __/  \__ \  \  /                 / \ / \ / \                --
--       / /_/ / /___ ___/ /  / /               = ( M | S | K )=              --
--      /_____/_____//____/  /_/                   \_/ \_/ \_/                --
--                                                                            --
--------------------------------------------------------------------------------
--! @copyright Copyright 2023 DESY
--! SPDX-License-Identifier: Apache-2.0
--------------------------------------------------------------------------------
--! @date 2023-05-22
--! @author Lukasz Butkowski <lukasz.butkowski@desy.de>
--------------------------------------------------------------------------------
--! @brief
--! Simple bus translator from IBUS to AXI4-Lite, requires the same bus width
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

------------------------------------------------------------------------------
library desyrdl;
use desyrdl.common.all;

------------------------------------------------------------------------------
--! @brief II to AXI translation
entity ibus_to_axi4l is
  generic (
    G_BUS_TIMEOUT : natural := 4095
  );
  port (
    -- AXI4 slave port
    pi_reset        : in  std_logic;
    pi_clock        : in  std_logic;
    pi_s_decoder    : in  t_ibus_m2s;
    po_s_decoder    : out t_ibus_s2m;
    -- IBUS interface
    po_m_ext        : out t_axi4l_m2s;
    pi_m_ext        : in  t_axi4l_s2m
  );
end ibus_to_axi4l;

architecture rtl of ibus_to_axi4l is
  signal awvalid : std_logic := '0';
  signal arvalid : std_logic := '0';
  signal wvalid  : std_logic := '0';
  signal rd_trn  : std_logic := '0';
  signal wr_trn  : std_logic := '0';
begin
  -- write address
  po_m_ext.awvalid <= awvalid ;
  prs_awvalid: process(pi_clock)
  begin
    if rising_edge(pi_clock) then
      if pi_s_decoder.wena = '1' and awvalid  = '0' and wr_trn = '0' then
        po_m_ext.awaddr  <= pi_s_decoder.addr;
        awvalid <= '1';
        wr_trn  <= '1';
      else
        if pi_m_ext.awready = '1' then
          awvalid <= '0';
        end if;
        if pi_m_ext.bvalid = '1' then
          wr_trn  <= '0';
        end if;
      end if;
    end if;
  end process prs_awvalid;

  -- write data
  po_m_ext.wstrb <= (others => '1');
  po_m_ext.wvalid <= wvalid ;
  prs_wvalid: process(pi_clock)
  begin
    if rising_edge(pi_clock) then
      if pi_s_decoder.wena = '1' and wvalid = '0' then
        po_m_ext.wdata <= pi_s_decoder.data;
        wvalid <= '1';
      else
        if pi_m_ext.wready = '1' then
          wvalid <= '0';
        end if;
      end if;
    end if;
  end process prs_wvalid;

  -- read address
  po_m_ext.arvalid <= arvalid ;
  prs_arvalid: process(pi_clock)
  begin
    if rising_edge(pi_clock) then
      if pi_s_decoder.rena = '1' and arvalid  = '0' and rd_trn = '0' then
        po_m_ext.araddr  <= pi_s_decoder.addr;
        arvalid <= '1';
        rd_trn  <= '1';
      else
        if pi_m_ext.arready = '1' then
          arvalid <= '0';
        end if;
        if pi_m_ext.rvalid = '1' then
          rd_trn  <= '0';
        end if;
      end if;
    end if;
  end process prs_arvalid;

  -- read data (ilways ready)
  po_m_ext.rready <= '1';

  -- ibus
  -- ignore awready, wready, iresp, bvalid, arready, rresp
  prs_fd_data: process(pi_clock)
  begin
    if rising_edge(pi_clock) then
      if pi_m_ext.rvalid = '1' then
        po_s_decoder.data <= pi_m_ext.rdata;
      end if;
      po_s_decoder.rack <= pi_m_ext.rvalid;
    end if;
  end process prs_fd_data;

  -- write response (always ready)
  po_m_ext.bready   <= '1';
  po_s_decoder.wack <= pi_m_ext.bvalid;

end architecture;
