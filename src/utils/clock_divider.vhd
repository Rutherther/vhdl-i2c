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
  constant MAX : integer := IN_FREQ / OUT_FREQ / 2;
  signal curr_count : integer range 0 to MAX - 1;
  signal next_count : integer range 0 to MAX - 1;

  signal gen_clk : std_logic := '0';
begin  -- architecture a1
  keep_max_freq: if IN_FREQ = OUT_FREQ generate
    clk_o <= clk_i;
  end generate keep_max_freq;

  counter: if IN_FREQ /= OUT_FREQ generate
    clk_o <= gen_clk;
    next_count <= (curr_count - 1) when curr_count > 0 else MAX - 1;

    set_counter: process (clk_i) is
    begin  -- process set_counter
      if rising_edge(clk_i) then          -- rising clock edge
        curr_count <= next_count;

        if curr_count = 0 then
          gen_clk <= not gen_clk;
        end if;
      end if;
    end process set_counter;
  end generate counter;

end architecture a1;
