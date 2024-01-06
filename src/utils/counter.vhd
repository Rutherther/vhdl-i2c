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
  constant MAX_COUNT : natural := IN_FREQ / OUT_FREQ;
  signal curr_count : integer range 0 to MAX_COUNT - 1;
  signal next_count : integer range 0 to MAX_COUNT - 1;

  signal count_clk : std_logic;

  signal carries : std_logic_vector(DIGITS downto 0);
  signal value : std_logic_vector(DIGITS * 4 - 1 downto 0);
begin  -- architecture a1
  value_o <= value;

  next_count <= curr_count - 1 when curr_count > 0 else MAX_COUNT - 1;

  carries(0) <= '1' when curr_count = 0 else '0';

  set_regs: process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if rst_in = '0' then
        curr_count <= MAX_COUNT - 1;
      else
	curr_count <= next_count;
      end if;
    end if;
  end process set_regs;

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
