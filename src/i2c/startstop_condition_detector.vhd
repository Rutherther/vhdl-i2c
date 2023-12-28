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
  signal reg_start, reg_stop : std_logic;
  signal next_start, next_stop : std_logic;

  signal reg_prev_sda : std_logic;
  signal next_prev_sda : std_logic;
begin  -- architecture a1

  next_prev_sda <= sda_i;

  next_start <= '0' when reg_start = '1' else
                '1' when reg_prev_sda = '0' and sda_i = '1' and scl_i = '1' else
                '0';
  next_stop <= '0' when reg_stop = '1' else
               '1' when reg_prev_sda = '1' and sda_i = '0' and scl_i = '1' else
               '0';

  set_next: process (clk_i) is
  begin  -- process set_next
    if rising_edge(clk_i) then          -- rising clock edge
      reg_prev_sda <= next_prev_sda;
      reg_start <= next_start;
      reg_stop <= next_stop;
    end if;
  end process set_next;

end architecture a1;
