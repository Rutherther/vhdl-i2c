-------------------------------------------------------------------------------
-- Title      : Synchronous edge detector
-- Project    :
-------------------------------------------------------------------------------
-- File       : sync_edge_detector.vhd
-- Author     : Frantisek Bohacek  <rutherther@protonmail.com>
-- Created    : 2023-11-26
-- Last update: 2023-11-26
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Detects edges in signal_i, synchronously to clk_i
-------------------------------------------------------------------------------
-- Copyright (c) 2023
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2023-11-26  1.0      ruther	Created
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;

entity sync_edge_detector is

  port (
    clk_i          : in  std_logic;
    signal_i       : in  std_logic;
    rising_edge_o  : out std_logic;
    falling_edge_o : out std_logic);

end entity sync_edge_detector;

architecture a1 of sync_edge_detector is
  signal reg_prev_signal : std_logic;
  signal next_prev_signal : std_logic;
begin  -- architecture a1
  next_prev_signal <= signal_i;

  rising_edge_o <= '1' when reg_prev_signal = '0' and signal_i = '1' else
                   '0';

  falling_edge_o <= '1' when reg_prev_signal = '1' and signal_i = '0' else
                    '0';

  set_next: process (clk_i) is
  begin  -- process set_next
    if rising_edge(clk_i) then          -- rising clock edge
      reg_prev_signal <= next_prev_signal;
    end if;
  end process set_next;

end architecture a1;
