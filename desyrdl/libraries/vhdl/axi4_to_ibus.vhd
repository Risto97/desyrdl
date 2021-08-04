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
--! @file   axi4_to_ibus.vhd
--! @brief  AXI4 to II translation
--! @author Lukasz Butkowski
--! @author Holger Kay
--! @mail   holger.kay@desy.de
--! $Date$
--! $Revision$
--! $URL$
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_MISC.all;
use IEEE.numeric_std.all;
------------------------------------------------------------------------------
use work.common.all;

------------------------------------------------------------------------------
--! @brief AXI4 to II translation  
entity axi4_to_ibus is
  port (
    -- AXI4 slave port
    pi_reset          : in  std_logic;
    pi_clock          : in  std_logic;
    pi_adapter_m2s    : in  T_AXI4_M2S;
    po_adapter_s2m    : out T_AXI4_S2M;
    -- IBUS interface
    po_ext_m2s        : out t_ibus_m2s;
    pi_ext_s2m        : in  t_ibus_s2m
  );
  -- preserve synthesis optimization which brakes handshaking functionality
  attribute KEEP_HIERARCHY : string;
  attribute KEEP_HIERARCHY of axi4_to_ibus : entity is "yes";
end axi4_to_ibus;

------------------------------------------------------------------------------
architecture rtl of axi4_to_ibus is

  type T_STATE is (ST_IDLE, 
                   ST_READ_DATA_ADDR,
                   ST_READ_DATA,
                   ST_READ_DATA_WAIT,
                   ST_WRITE_DATA_ADDR,
                   ST_WRITE_DATA,
                   ST_WRITE_DATA_WAIT,
                   ST_WRITE_RESP,
                   ST_READ_DATA_PUSH,
                   ST_WAIT_AFTER_TRN);
                  
  signal SIG_STATE   : T_STATE;          
  signal SIG_LEN     : std_logic_vector(7 downto 0);

  signal SIG_RENA    : std_logic;
  signal SIG_WENA    : std_logic;
  signal SIG_ADDR    : std_logic_vector(31 downto 0) := (others => '0');

  signal SIG_M2S     : T_AXI4_M2S := C_AXI4_M2S_DEFAULT;
  signal SIG_S2M     : T_AXI4_S2M := C_AXI4_S2M_DEFAULT;
    
    -- signal SIG_WAIT_CNT : natural:=0;

  ---------------------------------------------------------------------------
begin

  -- unsed AXI4 Signals: SIG_M2S.AWSIZE  SIG_M2S.AWBURST  SIG_M2S.WSTRB
  -- unsed AXI4 Signals: SIG_M2S.ARSIZE  SIG_M2S.ARBURST  SIG_M2S.WLAST
    
  po_adapter_s2m     <= SIG_S2M;
  SIG_M2S          <= pi_adapter_m2s;
  ------------------------------------
  SIG_S2M.RRESP    <=  AXI4_RESP_OKAY;
  
  SIG_S2M.BRESP    <=  AXI4_RESP_OKAY;
  
  SIG_S2M.ACLK     <=  pi_clock;
  
  po_ext_m2s.CLK    <=  pi_clock;
  
  po_ext_m2s.ADDR   <=  SIG_ADDR;
  po_ext_m2s.RENA   <=  SIG_RENA when rising_edge(pi_clock); -- delay one clock cycle to have 1 clock cycle delay after data on bus
  po_ext_m2s.WENA   <=  SIG_WENA when rising_edge(pi_clock);


  process(pi_clock)
  begin
      if rising_edge(pi_clock) then
        if (pi_reset = '1') then
          SIG_STATE        <= ST_IDLE ;
          SIG_RENA         <= '0';
          SIG_WENA         <= '0';
          SIG_S2M.ARESET_N <= '0';
          SIG_S2M.BVALID   <= '0';
        else
          SIG_RENA         <= '0'  ;
          SIG_WENA         <= '0'  ;
          
          case SIG_STATE is
            -------------------------------------
            when ST_IDLE =>

              SIG_S2M.ARESET_N <= '1'  ;
          
              -- SIG_ADDR_CNT <= 0;
              -- SIG_WAIT_CNT <= 0;

              if ( SIG_M2S.ARVALID = '1' ) then
                  SIG_STATE   <= ST_READ_DATA_ADDR ;
                  
              elsif ( SIG_M2S.AWVALID  = '1' ) then
                  SIG_STATE   <= ST_WRITE_DATA_ADDR;
                  
              end if;
              
            -------------------------------------  
            when ST_WRITE_DATA_ADDR =>
            
              if ( SIG_M2S.AWVALID  = '1' ) then
                SIG_S2M.BID <= SIG_M2S.AWID;
                SIG_LEN     <= SIG_M2S.AWLEN ;
                SIG_ADDR    <= SIG_M2S.AWADDR;
                SIG_STATE   <= ST_WRITE_DATA;
              end if;
              
            -------------------------------------  
            when ST_WRITE_DATA =>
            
                if ( SIG_M2S.WVALID  = '1' ) then
                    po_ext_m2s.DATA <= SIG_M2S.WDATA(31 downto 0);
                    SIG_WENA      <= '1';
                    SIG_STATE     <= ST_WRITE_DATA_WAIT;
                end if;
                
            -------------------------------------    
            when ST_WRITE_DATA_WAIT =>
                
                if pi_ext_s2m.WACK = '1' then
                    SIG_STATE      <= ST_WRITE_RESP ;
                    SIG_S2M.BVALID <= '1';
                end if;

            -------------------------------------
            when ST_WRITE_RESP =>
                if pi_adapter_m2s.BREADY = '1' then
                  SIG_S2M.BVALID <= '0';
                  SIG_STATE      <= ST_WAIT_AFTER_TRN ;
                end if;

            -------------------------------------    
            when ST_READ_DATA_ADDR =>
            
              if ( SIG_M2S.ARVALID = '1' ) then
                SIG_S2M.RID <= SIG_M2S.ARID;
                SIG_LEN     <= SIG_M2S.ARLEN;
                SIG_ADDR    <= SIG_M2S.ARADDR;
                SIG_STATE   <= ST_READ_DATA;
              end if;
              
            -------------------------------------  
            when ST_READ_DATA =>
            
                SIG_RENA <= '1';
                SIG_STATE  <= ST_READ_DATA_WAIT ;
                
            -------------------------------------    
            when ST_READ_DATA_WAIT => 
            
                if pi_ext_s2m.RACK = '1' then
                    SIG_S2M.RDATA(31 downto 0)  <= pi_ext_s2m.DATA;
                    SIG_STATE      <= ST_READ_DATA_PUSH ;
                end if;

            -------------------------------------  
            when ST_READ_DATA_PUSH =>
                
                if SIG_M2S.RREADY = '1' then
                    -- if std_logic_vector(to_unsigned(SIG_ADDR_CNT,8)) = SIG_LEN then
                  SIG_STATE <= ST_WAIT_AFTER_TRN ;
                    -- else
                        -- SIG_ADDR_CNT <= SIG_ADDR_CNT + 1 ; 
                        -- SIG_ADDR   <= std_logic_vector(unsigned(SIG_ADDR) + 4);
                        -- SIG_STATE  <= ST_READ_DATA ;
                    -- end if;
                end if;

            -------------------------------------    
            when ST_WAIT_AFTER_TRN =>
              -- if SIG_WAIT_CNT >= 3 then
                SIG_STATE <= ST_IDLE ;
              -- else
                -- SIG_WAIT_CNT <= SIG_WAIT_CNT + 1;
              -- end if;
          end case ;
        end if;
      end if;
  end process;

  PROC_AXI_HDS:process(SIG_STATE, SIG_M2S)
  begin 
    SIG_S2M.ARREADY  <= '0' ;
    SIG_S2M.AWREADY  <= '0' ;
    SIG_S2M.WREADY   <= '0' ;
    SIG_S2M.RVALID   <= '0' ;
    SIG_S2M.RLAST    <= '1' ;
      
    case SIG_STATE is
      when ST_READ_DATA_ADDR =>
          SIG_S2M.ARREADY <= SIG_M2S.ARVALID ;

      when ST_WRITE_DATA_ADDR =>
          SIG_S2M.AWREADY <= SIG_M2S.AWVALID ;
          
      when ST_WRITE_DATA =>
          SIG_S2M.WREADY <= SIG_M2S.WVALID ;
          
      when ST_READ_DATA_PUSH =>
          SIG_S2M.RVALID <= '1';

      when others =>
    end case;
  end process;
  
end rtl;
  
