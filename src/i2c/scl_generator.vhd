library ieee;
use ieee.std_logic_1164.all;

entity scl_generator is

  generic (
    MIN_STABLE_CYCLES : natural := 5);

  port (
    clk_i            : in  std_logic;
    rst_in           : in  std_logic;

    scl_i            : in  std_logic;
    scl_rising_i     : in  std_logic;
    scl_falling_i    : in  std_logic;

    gen_continuous_i : in  std_logic;
    gen_rising_i     : in  std_logic;
    gen_falling_i    : in  std_logic;
    scl_enable_o     : out std_logic;
    cannot_comply_o  : out std_logic);

end entity scl_generator;

architecture a1 of scl_generator is
  signal should_fall : std_logic;
  signal should_rise : std_logic;
  signal should_change : std_logic;

  signal can_change : std_logic;

  signal req_change : std_logic;
  signal change : std_logic;

  signal scl_changing : std_logic;

  signal exp_scl : std_logic;

  signal curr_stable_count : integer range 0 to MIN_STABLE_CYCLES;
  signal next_stable_count : integer range 0 to MIN_STABLE_CYCLES;

  signal curr_scl_enable : std_logic;
  signal next_scl_enable : std_logic;
begin  -- architecture a1
  scl_enable_o <= curr_scl_enable;

  cannot_comply_o <= (scl_i xor (not curr_scl_enable)) and should_change;

  should_rise <= (gen_rising_i or gen_continuous_i) and not scl_i;
  should_fall <= (gen_falling_i or gen_continuous_i) and scl_i;
  should_change <= should_rise or should_fall;
  can_change <= '1' when curr_stable_count = MIN_STABLE_CYCLES else '0';

  -- requests a change of the SCL, not of SCL enable
  req_change <= can_change and should_change;
  change <= req_change and (scl_i xor exp_scl);

  exp_scl <= '1' when should_rise = '1' and req_change = '1' else
             '0' when should_fall = '1' and req_change = '1' else
             not curr_scl_enable;

  next_scl_enable <= curr_scl_enable xor change;

  scl_changing <= scl_rising_i or scl_falling_i;

  next_stable_count <=  0 when scl_changing = '1' else
                        curr_stable_count + 1 when can_change = '0' and curr_stable_count < MIN_STABLE_CYCLES else
                        curr_stable_count;

  set_regs: process (clk_i) is
  begin  -- process set_regs
    if rising_edge(clk_i) then          -- rising clock edge
      if rst_in = '0' then              -- synchronous reset (active low)
        curr_stable_count <= 0;
        curr_scl_enable <= '0';
      else
        curr_stable_count <= next_stable_count;
        curr_scl_enable <= next_scl_enable;
      end if;
    end if;
  end process set_regs;

end architecture a1;
