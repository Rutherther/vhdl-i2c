library ieee;
use ieee.std_logic_1164.all;

entity delay is
  generic (
    DELAY : natural range 0 to 31);

  port (
    clk_i   : in std_logic;
    rst_in  : in std_logic;
    signal_i : in std_logic;
    signal_o : out std_logic);

end entity delay;

architecture a1 of delay is
  constant DELAYED_PULSE_POS : natural := DELAY - 1;
  signal curr_pulses : std_logic_vector(DELAYED_PULSE_POS downto 0);
  signal next_pulses : std_logic_vector(DELAYED_PULSE_POS downto 0);
begin  -- architecture a1

  zero_delay: if DELAY = 0 generate
    signal_o <= signal_i;
  else generate
    signal_o <= curr_pulses(DELAYED_PULSE_POS);
  end generate zero_delay;

  next_pulses <= curr_pulses(DELAYED_PULSE_POS - 1 downto 1) & signal_i;

  set_regs: process (clk_i) is
  begin  -- process set_regs
    if rising_edge(clk_i) then          -- rising clock edge
      if rst_in = '0' then              -- synchronous reset (active low)
        curr_pulses <= (others => '0');
      else
        curr_pulses <= next_pulses;
      end if;
    end if;
  end process set_regs;

end architecture a1;
