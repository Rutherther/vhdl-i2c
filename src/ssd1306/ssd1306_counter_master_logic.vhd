library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library i2c;

use work.ssd1306_pkg.all;

entity ssd1306_counter_master_logic is
  generic (
    DIGITS : natural;
    I2C_CLK_FREQ : integer);
  port (
    clk_i : in std_logic;
    rst_in : in std_logic;

    start_i : in std_logic;

    count_i : in std_logic_vector(DIGITS*4 - 1 downto 0);

    master_start_o : out std_logic;
    master_stop_o : out std_logic;

    tx_valid_o : out std_logic;
    tx_ready_i : in std_logic;
    tx_data_o : out std_logic_vector(7 downto 0);

    dev_busy_i : in std_logic;
    waiting_i : in std_logic;
    any_err_i : in std_logic;

    state_o : out std_logic_vector(3 downto 0);
    substate_o : out std_logic_vector(2 downto 0));

end entity ssd1306_counter_master_logic;

architecture a1 of ssd1306_counter_master_logic is
  type state_t is (IDLE, INIT_DISPLAY, INIT_ADDRESSING_MODE, ZERO_OUT_RAM, SET_ADR_ZERO, DIGIT_N, SEC_DELAY);
  signal curr_state : state_t;
  signal next_state : state_t;

  signal curr_digit : natural;
  signal next_digit : natural;

  type substate_t is (IDLE, START, DATA, STOP, ALT);
  signal curr_substate : substate_t;
  signal next_substate : substate_t;

  signal digit_data : data_arr_t(0 to 8);

  signal curr_index : natural;
  signal next_index : natural;
  signal max_index : natural;

begin  -- architecture a1

  state_o <= std_logic_vector(to_unsigned(state_t'pos(curr_state), 4));
  substate_o <= std_logic_vector(to_unsigned(substate_t'pos(curr_substate), 3));


  max_index <= SSD1306_INIT'length when curr_state = INIT_DISPLAY else
               SSD1306_HORIZONTAL_ADDRESSING_MODE'length when curr_state = INIT_ADDRESSING_MODE else
               9 when curr_state = DIGIT_N else
               SSD1306_CURSOR_TO_ZERO'length when curr_state = SET_ADR_ZERO else
               I2C_CLK_FREQ/2 when curr_state = SEC_DELAY else
               SSD1306_ZERO_LEN when curr_state = ZERO_OUT_RAM else
               0;

  next_index <= 0 when curr_substate = IDLE else
                (curr_index + 1) when curr_substate = ALT and curr_index < max_index else
                (curr_index + 1) when tx_ready_i = '1' and curr_index < max_index and curr_substate = DATA else
                curr_index;

  tx_valid_o <= '1' when tx_ready_i = '1' and curr_index < max_index and curr_substate = DATA else '0';

  tx_data_o <= SSD1306_INIT(curr_index) when curr_state = INIT_DISPLAY and curr_index < max_index else
             SSD1306_HORIZONTAL_ADDRESSING_MODE(curr_index) when curr_state = INIT_ADDRESSING_MODE and curr_index < max_index else
             SSD1306_ZERO(0) when curr_state = ZERO_OUT_RAM and curr_index = 0 else
             SSD1306_ZERO(1) when curr_state = ZERO_OUT_RAM and curr_index /= 0 else
             SSD1306_CURSOR_TO_ZERO(curr_index) when curr_state = SET_ADR_ZERO and curr_index < max_index else
             digit_data(curr_index) when curr_state = DIGIT_N and curr_index < max_index else
             "00000000";

  next_digit <= 0 when curr_state /= DIGIT_N else
                (curr_digit + 1) when curr_state = DIGIT_N and curr_substate = STOP and curr_digit < DIGITS - 1 else
                curr_digit;

  digit_data <= ssd1306_bcd_digit_data(count_i(((DIGITS - 1 - curr_digit) + 1) * 4 - 1 downto (DIGITS - 1 - curr_digit) * 4));

  master_start_o <= '1' when curr_substate = START else '0';
  master_stop_o <= '1' when curr_substate = STOP else '0';

  set_next_state: process (all) is
  begin  -- process set_next_state
    next_state <= curr_state;

    if curr_state = IDLE then
      next_state <= INIT_DISPLAY;
    elsif curr_state = INIT_DISPLAY then
      if curr_substate = STOP then
        next_state <= INIT_ADDRESSING_MODE;
      end if;
    elsif curr_state = INIT_ADDRESSING_MODE then
      if curr_substate = STOP then
        next_state <= ZERO_OUT_RAM;
      end if;
    elsif curr_state = ZERO_OUT_RAM then
      if curr_substate = STOP then
        next_state <= SET_ADR_ZERO;
      end if;
    elsif curr_state = SET_ADR_ZERO then
      if curr_substate = STOP then
        next_state <= DIGIT_N;
      end if;
    elsif curr_state = DIGIT_N then
      if curr_substate = STOP and curr_digit = DIGITS - 1 then
        next_state <= SEC_DELAY;
      end if;
    elsif curr_state = SEC_DELAY then
      if curr_index = max_index then
        next_state <= SET_ADR_ZERO;
      end if;
    end if;

    if any_err_i = '1' then
      next_state <= IDLE;
    end if;
    
    if start_i = '1' then
        next_state <= IDLE;
    end if;
  end process set_next_state;

  set_next_substate: process (all) is
  begin  -- process set_next_state
    next_substate <= curr_substate;

    if curr_state /= IDLE and curr_state /= SEC_DELAY then
      if curr_substate = IDLE then
        if dev_busy_i = '0' then
          next_substate <= START;
        end if;
      elsif curr_substate = START then
        next_substate <= DATA;
      elsif curr_substate = DATA and curr_index = max_index then
        if waiting_i = '1' then
          next_substate <= STOP;
        end if;
      elsif curr_substate = STOP then
        next_substate <= IDLE;
      elsif curr_substate = ALT then
        next_substate <= IDLE;
      end if;
    else
      next_substate <= ALT;
    end if;
  end process set_next_substate;

  set_regs: process (clk_i) is
  begin  -- process set_regs
    if rising_edge(clk_i) then          -- rising clock edge
      if rst_in = '0' then                 -- synchronous reset (active low)
        curr_state <= IDLE;
        curr_substate <= IDLE;
        curr_digit <= 0;
        curr_index <= 0;
      else
        curr_state <= next_state;
        curr_substate <= next_substate;
        curr_digit <= next_digit;
        curr_index <= next_index;
      end if;
    end if;
  end process set_regs;

end architecture a1;
