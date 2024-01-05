library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bcd_counter is

  generic (
    MAX : integer := 10);

  port (
    clk_i   : in  std_logic;
    rst_in  : in  std_logic;
    carry_i : in  std_logic;
    carry_o : out std_logic;
    count_o : out std_logic_vector(3 downto 0));

end entity bcd_counter;

architecture a1 of bcd_counter is
  signal count_next : unsigned(3 downto 0);
  signal count_reg : unsigned(3 downto 0);
begin  -- architecture a1

  count_next <= ((count_reg + 1) mod MAX) when carry_i = '1' else count_reg;
  carry_o <= '1' when count_next = "0000" and carry_i = '1' else '0';
  count_o <= std_logic_vector(count_reg);

  set_count: process (clk_i) is
  begin  -- process set_count
    if rising_edge(clk_i) then          -- rising clock edge
      if rst_in = '0' then              -- synchronous reset (active low)
        count_reg <= "0000";
      else
        count_reg <= count_next;
      end if;
    end if;
  end process set_count;

end architecture a1;
