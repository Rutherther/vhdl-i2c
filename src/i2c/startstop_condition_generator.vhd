library ieee;
use ieee.std_logic_1164.all;

library utils;

entity startstop_condition_generator is

  generic (
    DELAY : integer range 0 to 31);

  port (
    clk_i                 : in  std_logic;
    rst_in                : in  std_logic;

    sda_i                 : in  std_logic;
    scl_rising_i          : in  std_logic;
    scl_falling_i         : in  std_logic;
    scl_falling_delayed_i : in  std_logic;
    sda_enable_o          : out std_logic;

    start_condition_i     : in  std_logic;
    stop_condition_i      : in  std_logic;

    gen_start_i           : in  std_logic;
    gen_stop_i            : in  std_logic;

    req_scl_fall_o        : out std_logic;
    req_scl_rise_o        : out std_logic;

    done_o                : out std_logic);

end entity startstop_condition_generator;

architecture a1 of startstop_condition_generator is
  -- 1. prepare sda to NOT condition level,
  -- 2. request to rise the scl line,
  -- 3. generate the condition - set sda to condition level,
  -- 4. request to fall the scl line (this is to allow for disengaging sda_enable
  -- and take it from another entity instead, without communicating the current
  -- level.),
  -- 5. done!
  type state_t is (IDLE, PREREQ_SCL_FALL, PREPARE_SDA, REQ_SCL_RISE, GEN_COND, REQ_SCL_FALL, DONE);
  signal curr_state : state_t := IDLE;
  signal next_state : state_t;

  signal curr_count : integer range 0 to DELAY;
  signal next_count : integer range 0 to DELAY;

  signal curr_scl : std_logic;
  signal next_scl : std_logic;

  signal curr_count_en : std_logic;
  signal next_count_en : std_logic;

  signal request_sda : std_logic;
  signal any_request : std_logic;
begin  -- architecture a1
  any_request <= gen_start_i or gen_stop_i;
  request_sda <= '0' when gen_start_i = '1' else
                 '1' when gen_stop_i = '1' else
                 'X';

  done_o <= '1' when curr_state = DONE else '0';

  req_scl_rise_o <= '1' when curr_state = REQ_SCL_RISE else '0';
  req_scl_fall_o <= '1' when curr_state = REQ_SCL_FALL or curr_state = PREREQ_SCL_FALL else '0';

  sda_enable_o <= not request_sda when curr_state = PREPARE_SDA or curr_state = REQ_SCL_RISE else
                  request_sda when curr_state = GEN_COND or curr_state = REQ_SCL_FALL else
                  '0';

  next_scl <= '1' when scl_rising_i = '1' else
              '0' when scl_falling_delayed_i = '1' else
              curr_scl;

  next_count <= 0 when curr_state /= next_state else
                curr_count + 1 when curr_count < DELAY and curr_count_en = '1' else
                curr_count;

  set_next_state: process (all) is
  begin  -- process set_next_state
    next_state <= curr_state;
    next_count_en <= curr_count_en;

    if curr_state = IDLE then
      next_count_en <= '0';

      if any_request = '1' then
        if curr_scl = '1' and sda_i /= not request_sda then
          next_state <= PREREQ_SCL_FALL;
        elsif curr_scl = '1' then
          next_state <= GEN_COND;
        elsif sda_i = not request_sda then
          next_state <= REQ_SCL_RISE;
        else
          next_state <= PREPARE_SDA;
        end if;
      end if;
    elsif curr_state = PREREQ_SCL_FALL then
      if scl_falling_i = '1' then
        next_count_en <= '1';
      elsif curr_count = DELAY then
        next_state <= DONE;
        next_count_en <= '0';
      end if;
    elsif curr_state = PREPARE_SDA then
      next_count_en <= '1';

      if curr_scl = '1' then
        -- cannot do anything :(
      elsif curr_count = DELAY then
        next_state <= REQ_SCL_RISE;
      elsif curr_scl = '1' then
        next_state <= GEN_COND;
        next_count_en <= '0';
      end if;
    elsif curr_state = REQ_SCL_RISE then
      if scl_rising_i = '1' then
        next_count_en <= '1';
      elsif curr_count = DELAY then
        next_state <= GEN_COND;
        next_count_en <= '0';
      end if;
    elsif curr_state = GEN_COND then
      -- assume correct condition here. If it's the wrong one,
      -- state entity should take care of that. (abort)
      if start_condition_i = '1' or stop_condition_i = '1' then
        next_count_en <= '1';
      elsif curr_count = DELAY then
        next_state <= REQ_SCL_FALL;
        next_count_en <= '0';
      end if;
    elsif curr_state = REQ_SCL_FALL then
      if scl_falling_i = '1' then
        next_count_en <= '1';
      elsif curr_count = DELAY then
        next_state <= DONE;
        next_count_en <= '0';
      end if;
    elsif curr_state = DONE then
      next_count_en <= '0';
      if any_request = '0' then
        next_state <= IDLE;
      end if;
    end if;
  end process set_next_state;

  set_regs: process (clk_i) is
  begin  -- process set_regs
    if rising_edge(clk_i) then          -- rising clock edge
      if rst_in = '0' then              -- synchronous reset (active low)
        curr_state <= IDLE;
        curr_count <= 0;
        curr_count_en <= '0';
      else
        curr_state <= next_state;
        curr_count <= next_count;
        curr_count_en <= next_count_en;
      end if;
    end if;
  end process set_regs;

end architecture a1;
