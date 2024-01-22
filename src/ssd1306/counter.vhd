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

  constant DIGITS : natural := 3;
  signal count : std_logic_vector(DIGITS * 4 - 1 downto 0);
begin  -- architecture a+

  tx_clear_buffer <= '0';
  rw <= '0';
  master_run <= '1';
  rst_n <= not rst_sync;
  waiting_o <= waiting;
  dev_busy_o <= dev_busy;

  err_noack_data_o <= err_noack_data;
  err_noack_address_o <= err_noack_address;
  err_arbitration_o <= err_arbitration;
  err_general_o <= err_general;
  any_err <= err_general or err_arbitration or err_noack_address or err_noack_data;

  counter_master_logic: entity work.ssd1306_counter_master_logic
    generic map (
      DIGITS       => DIGITS,
      I2C_CLK_FREQ => I2C_CLK_FREQ)
    port map (
      clk_i => i2c_clk,
      rst_in => rst_n,
      start_i => start_i,
      count_i => count,
      tx_valid_o => tx_valid,
      tx_ready_i => tx_ready,
      tx_data_o => tx_data,
      dev_busy_i => dev_busy,
      waiting_i => waiting,
      any_err_i => any_err,
      state_o    => state_o,
      substate_o => substate_o);

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

end architecture a1;
