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
  type state_t is (OBSERVE, CHANGING, CHANGED);
  signal curr_state : state_t;
  signal next_state : state_t;

  signal should_fall : std_logic;
  signal should_rise : std_logic;
  signal should_change : std_logic;

  signal can_change : std_logic;

  signal scl_changing : std_logic;

  signal curr_scl : std_logic;
  signal next_scl : std_logic;

  signal curr_stable_count : integer range 0 to MIN_STABLE_CYCLES;
  signal next_stable_count : integer range 0 to MIN_STABLE_CYCLES;

  signal curr_scl_enable : std_logic := '0';
  signal next_scl_enable : std_logic;

  signal curr_requested_change : std_logic;
  signal next_requested_change : std_logic;
begin  -- architecture a1

  cannot_comply_o <= '1' when curr_state = CHANGING and scl_changing /= '1' else '0';
  scl_enable_o <= curr_scl_enable;

  scl_changing <= scl_rising_i or scl_falling_i;

  should_rise <= (gen_rising_i or gen_continuous_i and not gen_falling_i) and not curr_scl;
  should_fall <= (gen_falling_i or gen_continuous_i and not gen_rising_i) and curr_scl;
  should_change <= should_rise or should_fall;
  can_change <= '1' when curr_stable_count = MIN_STABLE_CYCLES else '0';

  next_scl <= scl_i;

  set_next_state: process (all) is
  begin  -- process set_next_state
    next_state <= curr_state;
    next_scl_enable <= curr_scl_enable;

    if curr_state = CHANGING then
      if scl_changing = '1' then
        next_state <= OBSERVE;
      end if;
    elsif can_change = '1' and should_change = '1' then
      if should_fall = '1' then
        next_scl_enable <= '1';
        next_state <= CHANGING;
      elsif should_rise = '1' then
        next_scl_enable <= '0';
        next_state <= CHANGING;
      end if;
    end if;
  end process set_next_state;

  next_stable_count <=  0 when scl_changing = '1' else
                        curr_stable_count + 1 when can_change = '0' and curr_stable_count < MIN_STABLE_CYCLES else
                        curr_stable_count;

  set_regs: process (clk_i) is
  begin  -- process set_regs
    if rising_edge(clk_i) then          -- rising clock edge
      if rst_in = '0' then              -- synchronous reset (active low)
        curr_stable_count <= 0;
        curr_scl_enable <= '0';
        curr_requested_change <= '0';
        curr_state <= OBSERVE;
        curr_scl <= '1';
      else
        curr_stable_count <= next_stable_count;
        curr_scl_enable <= next_scl_enable;
        curr_requested_change <= next_requested_change;
        curr_state <= next_state;
        curr_scl <= next_scl;
      end if;
    end if;
  end process set_regs;

end architecture a1;
