library ieee;
use ieee.std_logic_1164.all;

entity clock_divider is

  generic (
    IN_FREQ       : integer;
    OUT_FREQ   : integer);

  port (
    clk_i  : in  std_logic;
    clk_o  : out std_logic);

end entity clock_divider;

architecture a1 of clock_divider is
  constant MAX : integer := IN_FREQ / OUT_FREQ;
  signal counter_next : integer range 0 to MAX;
  signal counter_reg : integer range 0 to MAX;
begin  -- architecture a1
  keep_max_freq: if IN_FREQ = OUT_FREQ generate
    clk_o <= clk_i;
  end generate keep_max_freq;

  counter: if IN_FREQ /= OUT_FREQ generate
    counter_next <= (counter_reg + 1) when counter_reg < MAX else 0;
    clk_o <= '1' when counter_reg >= MAX/2 else '0';
    set_counter: process (clk_i) is
    begin  -- process set_counter
      if rising_edge(clk_i) then          -- rising clock edge
        counter_reg <= counter_next;
      end if;
    end process set_counter;
  end generate counter;

end architecture a1;
