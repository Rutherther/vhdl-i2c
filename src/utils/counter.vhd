library ieee;
use ieee.std_logic_1164.all;

entity counter is

  generic (
    MAX      : natural := 9;
    DIGITS   : natural;
    IN_FREQ  : natural;
    OUT_FREQ : natural);

  port (
    clk_i   : in  std_logic;
    rst_in  : in  std_logic;
    value_o : out std_logic_vector(DIGITS * 4 - 1 downto 0));

end entity counter;

architecture a1 of counter is
  signal count_clk : std_logic;

  signal carries : std_logic_vector(DIGITS downto 0);
  signal value : std_logic_vector(DIGITS * 4 - 1 downto 0);
begin  -- architecture a1
  value_o <= value;

  pulse_gen: entity work.sync_edge_detector
    port map (
      clk_i          => clk_i,
      signal_i       => count_clk,
      rising_edge_o  => carries(0),
      falling_edge_o => open);

  clock_divider: entity work.clock_divider
    generic map (
      IN_FREQ => IN_FREQ,
      OUT_FREQ => OUT_FREQ)
    port map (
      clk_i => clk_i,
      clk_o => count_clk);

  counters: for i in 0 to DIGITS - 1 generate
    bcd_counter: entity work.bcd_counter
      generic map (
        MAX => MAX)
      port map (
        clk_i   => clk_i,
        rst_in  => rst_in,
        carry_i => carries(i),
        carry_o => carries(i + 1),
        count_o => value((i + 1) * 4 - 1 downto i * 4));
  end generate counters;

end architecture a1;
