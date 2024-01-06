library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library i2c;
library utils;

use work.ssd1306_pkg.all;

entity ssd1306_counter is

  generic (
    CLK_FREQ       : integer   := 100000000;  -- Input clock frequency
    I2C_CLK_FREQ   : integer   := 10000000; -- 12500000;
    COUNT_FREQ     : integer := 1;
    DELAY : integer := 20;
    EXPECT_ACK : std_logic := '1';
    SCL_MIN_STABLE_CYCLES : natural := 50);

  port (
    clk_i  : in std_logic;
    rst_i : in std_logic;

    start_i : in std_logic;

    err_noack_data_o : out std_logic;
    err_noack_address_o : out std_logic;
    err_arbitration_o : out std_logic;
    err_general_o : out std_logic;

    state_o : out std_logic_vector(3 downto 0);
    substate_o : out std_logic_vector(2 downto 0);

    bus_busy_o : out std_logic;
    dev_busy_o : out std_logic;
    waiting_o : out std_logic;

    sda_io : inout std_logic;
    scl_io : inout std_logic);

end entity ssd1306_counter;

architecture a1 of ssd1306_counter is
  constant ADDRESS : std_logic_vector(6 downto 0) := "0111100";

  signal rst_n : std_logic;
  signal rst_sync : std_logic;

  signal i2c_clk : std_logic;

  signal master_start, master_stop, master_run : std_logic;
  signal rw : std_logic;

  signal tx_valid, tx_ready, tx_clear_buffer : std_logic;
  signal tx_data : std_logic_vector(7 downto 0);

  signal rx_valid, rx_confirm : std_logic;
  signal rx_data : std_logic_vector(7 downto 0);

  signal err_noack_data : std_logic;
  signal err_noack_address : std_logic;
  signal err_arbitration : std_logic;
  signal err_general : std_logic;
  signal any_err : std_logic;

  signal waiting : std_logic;
  signal dev_busy : std_logic;

  signal sda, scl : std_logic;
  signal sda_enable, scl_enable : std_logic;

  type state_t is (IDLE, INIT_DISPLAY, INIT_ADDRESSING_MODE, ZERO_OUT_RAM, SET_ADR_ZERO, DIGIT_N, SEC_DELAY);
  signal curr_state : state_t;
  signal next_state : state_t;

  signal curr_digit : natural;
  signal next_digit : natural;

  type substate_t is (IDLE, START, DATA, STOP, ALT);
  signal curr_substate : substate_t;
  signal next_substate : substate_t;

  constant DIGITS : natural := 3;
  signal count : std_logic_vector(DIGITS * 4 - 1 downto 0);

  signal digit_data : data_arr_t(0 to 8);

  signal curr_index : natural;
  signal next_index : natural;
  signal max_index : natural;
begin  -- architecture a+

  state_o <= std_logic_vector(to_unsigned(state_t'pos(curr_state), 4));
  substate_o <= std_logic_vector(to_unsigned(substate_t'pos(curr_substate), 3));

  tx_clear_buffer <= '0';
  master_run <= '1';
  rst_n <= not rst_sync;
  waiting_o <= waiting;
  dev_busy_o <= dev_busy;

  err_noack_data_o <= err_noack_data;
  err_noack_address_o <= err_noack_address;
  err_arbitration_o <= err_arbitration;
  err_general_o <= err_general;
  any_err <= err_general or err_arbitration or err_noack_address or err_noack_data;

  rw <= '0';

  max_index <= SSD1306_INIT'length when curr_state = INIT_DISPLAY else
               SSD1306_HORIZONTAL_ADDRESSING_MODE'length when curr_state = INIT_ADDRESSING_MODE else
               9 when curr_state = DIGIT_N else
               SSD1306_CURSOR_TO_ZERO'length when curr_state = SET_ADR_ZERO else
               I2C_CLK_FREQ/2 when curr_state = SEC_DELAY else
               SSD1306_ZERO_LEN when curr_state = ZERO_OUT_RAM else
               0;

  next_index <= 0 when curr_substate = IDLE else
                (curr_index + 1) when curr_substate = ALT and curr_index < max_index else
                (curr_index + 1) when tx_ready = '1' and curr_index < max_index and curr_substate = DATA else
                curr_index;

  tx_valid <= '1' when tx_ready = '1' and curr_index < max_index and curr_substate = DATA else '0';

  tx_data <= SSD1306_INIT(curr_index) when curr_state = INIT_DISPLAY and curr_index < max_index else
             SSD1306_HORIZONTAL_ADDRESSING_MODE(curr_index) when curr_state = INIT_ADDRESSING_MODE and curr_index < max_index else
             SSD1306_ZERO(0) when curr_state = ZERO_OUT_RAM and curr_index = 0 else
             SSD1306_ZERO(1) when curr_state = ZERO_OUT_RAM and curr_index /= 0 else
             SSD1306_CURSOR_TO_ZERO(curr_index) when curr_state = SET_ADR_ZERO and curr_index < max_index else
             digit_data(curr_index) when curr_state = DIGIT_N and curr_index < max_index else
             "00000000";

  next_digit <= 0 when curr_state /= DIGIT_N else
                (curr_digit + 1) when curr_state = DIGIT_N and curr_substate = STOP and curr_digit < DIGITS - 1 else
                curr_digit;

  digit_data <= ssd1306_bcd_digit_data(count(((DIGITS - 1 - curr_digit) + 1) * 4 - 1 downto (DIGITS - 1 - curr_digit) * 4));

  master_start <= '1' when curr_substate = START else '0';
  master_stop <= '1' when curr_substate = STOP else '0';

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

    if any_err = '1' then
      next_state <= IDLE;
    end if;
  end process set_next_state;

  set_next_substate: process (all) is
  begin  -- process set_next_state
    next_substate <= curr_substate;

    if curr_state /= IDLE and curr_state /= SEC_DELAY then
      if curr_substate = IDLE then
        if dev_busy = '0' then
          next_substate <= START;
        end if;
      elsif curr_substate = START then
        next_substate <= DATA;
      elsif curr_substate = DATA and curr_index = max_index then
        if waiting = '1' then
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

  counter: entity utils.counter
    generic map (
      MAX      => 10,
      DIGITS   => DIGITS,
      IN_FREQ  => CLK_FREQ,
      OUT_FREQ => COUNT_FREQ)
    port map (
      clk_i   => clk_i,
      rst_in  => rst_n,
      value_o => count);

  divider: entity utils.clock_divider
    generic map (
      IN_FREQ  => CLK_FREQ,
      OUT_FREQ => I2C_CLK_FREQ)
    port map (
      clk_i    => clk_i,
      clk_o    => i2c_clk);

  i2c_master: entity i2c.master
    generic map (
      SCL_FALLING_DELAY     => DELAY,
      SCL_MIN_STABLE_CYCLES => SCL_MIN_STABLE_CYCLES)
    port map (
      clk_i               => i2c_clk,
      rst_in              => rst_n,
--
      slave_address_i     => ADDRESS,
--
      generate_ack_i      => '1',
      expect_ack_i        => EXPECT_ACK,
--
      rx_valid_o          => rx_valid,
      rx_data_o           => rx_data,
      rx_confirm_i        => rx_confirm,
--
      tx_ready_o          => tx_ready,
      tx_valid_i          => tx_valid,
      tx_data_i           => tx_data,
      tx_clear_buffer_i   => tx_clear_buffer,
--
      err_noack_data_o    => err_noack_data,
      err_noack_address_o => err_noack_address,
      err_arbitration_o   => err_arbitration,
      err_general_o       => err_general,
--
      stop_i              => master_stop,
      start_i             => master_start,
      run_i               => master_run,
      rw_i                => rw,
--
      dev_busy_o          => dev_busy,
      bus_busy_o          => bus_busy_o,
      waiting_o           => waiting,
--
      sda_i               => sda,
      scl_i               => scl,
      sda_enable_o        => sda_enable,
      scl_enable_o        => scl_enable);

  sync_reset: entity utils.metastability_filter
    port map (
      clk_i    => clk_i,
      signal_i => rst_i,
      signal_o => rst_sync);

  sda_open_buffer: entity utils.open_drain_buffer
    port map (
      pad_io   => sda_io,
      enable_i => sda_enable,
      state_o  => sda);
  scl_open_buffer: entity utils.open_drain_buffer
    port map (
      pad_io   => scl_io,
      enable_i => scl_enable,
      state_o  => scl);

  set_regs: process (i2c_clk) is
  begin  -- process set_regs
    if rising_edge(i2c_clk) then          -- rising clock edge
      if rst_n = '0' then                 -- synchronous reset (active low)
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
