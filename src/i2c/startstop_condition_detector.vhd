library ieee;
use ieee.std_logic_1164.all;

entity startstop_condition_detector is

  port (
    clk_i   : in  std_logic;
    sda_i   : in  std_logic;
    scl_i   : in  std_logic;
    start_o : out std_logic;
    stop_o  : out std_logic);

end entity startstop_condition_detector;

architecture a1 of startstop_condition_detector is
  -- signal curr_start, curr_stop : std_logic;
  -- signal next_start, next_stop : std_logic;

  signal curr_prev_sda, curr_prev_scl : std_logic;
  signal next_prev_sda, next_prev_scl : std_logic;
begin  -- architecture a1
  -- start_o <= curr_start;
  -- stop_o <= curr_stop;

  next_prev_sda <= sda_i;
  next_prev_scl <= scl_i;

  start_o <= -- '0' when curr_start = '1' else
             '1' when curr_prev_sda = '1' and sda_i = '0' and curr_prev_scl = '1' and scl_i = '1' else
             '0';
  stop_o <= -- '0' when curr_stop = '1' else
            '1' when curr_prev_sda = '0' and sda_i = '1' and curr_prev_scl = '1' and scl_i = '1' else
            '0';

  set_next: process (clk_i) is
  begin  -- process set_next
    if rising_edge(clk_i) then          -- rising clock edge
      curr_prev_sda <= next_prev_sda;
      curr_prev_scl <= next_prev_scl;
      -- curr_start <= next_start;
      -- curr_stop <= next_stop;
    end if;
  end process set_next;

end architecture a1;
