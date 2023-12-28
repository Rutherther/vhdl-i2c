library ieee;
use ieee.std_logic_1164.all;

entity metastability_filter is

  port (
    clk_i    : in  std_logic;
    signal_i : in  std_logic;
    signal_o : out std_logic);

end entity metastability_filter;

architecture a1 of metastability_filter is

begin  -- architecture a1

  delay: entity work.delay
    generic map (
      DELAY => 2)
    port map (
      clk_i   => clk_i,
      rst_in  => '1',
      signal_i => signal_i,
      signal_o => signal_o);

end architecture a1;
