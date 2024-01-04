library ieee;
use ieee.std_logic_1164.all;

library utils;

entity master is
  generic (
    SCL_FALLING_DELAY : natural := 5;
    SCL_MIN_STABLE_CYCLES : natural := 10);

  port (
    clk_i               : in  std_logic;  -- Synchronous clock
    rst_in              : in  std_logic;  -- Synchronous reset (active low)
    -- address
    slave_address_i     : in  std_logic_vector(6 downto 0);  -- Address of the
    -- ack control
    generate_ack_i      : in  std_logic;
    expect_ack_i        : in  std_logic;
    -- rx
    rx_valid_o          : out std_logic;  -- Data in rx_data are valid
    rx_data_o           : out std_logic_vector(7 downto 0);  -- Received data
    rx_confirm_i        : in  std_logic;  -- Confirm data from rx_data are read
    -- tx
    tx_ready_o          : out std_logic;  -- Transmitter ready for new data
    tx_valid_i          : in  std_logic;  -- Are data in tx_data valid? Should be
                                          -- a pulse for one cycle only
    tx_data_i           : in  std_logic_vector(7 downto 0);  -- Data to transmit
    tx_clear_buffer_i   : in  std_logic;
    -- errors
    err_noack_data_o    : out std_logic;
    err_noack_address_o : out std_logic;
    err_arbitration_o   : out std_logic;
    err_general_o       : out std_logic;
    -- state
    stop_i              : in  std_logic;
    start_i             : in  std_logic;
    run_i               : in  std_logic;
    rw_o                : out std_logic;  -- 1 - read, 0 - write
    dev_busy_o          : out std_logic;  -- Communicating with master
    bus_busy_o          : out std_logic;  -- Bus is busy, someone else is communicating
    waiting_o           : out std_logic;  -- Waiting for data or read data

    -- i2c
    sda_i        : in  std_logic;  -- I2C SDA line
    scl_i        : in  std_logic;  -- I2C SCL line
    sda_enable_o : out std_logic;  -- Pull down sda
    scl_enable_o : out std_logic);      -- Pull down scl

end entity master;

architecture a1 of master is
  signal sync_sda, sync_scl                  : std_logic;
  signal start_condition, stop_condition     : std_logic;
  signal scl_rising, scl_falling : std_logic;

  signal transmitting, receiving : std_logic;

  signal tx_sda_enable : std_logic;
  signal tx_scl_stretch : std_logic;
  signal tx_noack, tx_unexpected_sda : std_logic;
  signal tx_done : std_logic;

  signal rx_sda_enable : std_logic;
  signal rx_scl_stretch : std_logic;
  signal rx_done : std_logic;

  signal bus_busy : std_logic;

  signal adr_gen : std_logic;
  signal adr_sda_enable : std_logic;
  signal adr_noack : std_logic;
  signal adr_unexpected_sda : std_logic;
  signal adr_done : std_logic;
  signal adr_gen_start : std_logic;

  signal cond_gen : std_logic;
  signal cond_gen_sda_enable : std_logic;
  signal cond_gen_start : std_logic;
  signal cond_gen_stop : std_logic;
  signal cond_gen_req_scl_fall : std_logic;
  signal cond_gen_req_scl_rise : std_logic;
  signal cond_gen_done : std_logic;

  signal scl_gen_scl_enable : std_logic;
  signal scl_gen_req_continuous : std_logic;

  signal rw : std_logic;
  signal rst_i2c : std_logic;

  signal scl_falling_delayed : std_logic;
  signal waiting_for_data : std_logic;
  signal scl_gen_falling : std_logic;
begin  -- architecture a1
  rw_o <= rw;
  dev_busy_o <= transmitting or receiving;
  bus_busy_o <= bus_busy;
  waiting_for_data <= tx_scl_stretch or rx_scl_stretch;
  waiting_o <= waiting_for_data;

  scl_enable_o <= scl_gen_scl_enable;

  scl_gen_falling <= cond_gen_req_scl_fall when cond_gen = '1' else
                     tx_scl_stretch when transmitting = '1' else
                     rx_scl_stretch when transmitting = '1' else
                     '0';

  sda_enable_o <= tx_sda_enable when transmitting = '1' else
                  rx_sda_enable when receiving = '1' else
                  cond_gen_sda_enable when cond_gen = '1' else
                  adr_sda_enable when adr_gen = '1' else
                  '0';

  scl_falling_delayer: entity utils.delay
    generic map (
      DELAY => SCL_FALLING_DELAY)
    port map (
      clk_i    => clk_i,
      rst_in   => rst_in,
      signal_i => scl_falling,
      signal_o => scl_falling_delayed);

  scl_edge_detector: entity utils.sync_edge_detector
    port map (
      clk_i          => clk_i,
      signal_i       => sync_scl,
      rising_edge_o  => scl_rising,
      falling_edge_o => scl_falling);

  sda_sync: entity utils.metastability_filter
    port map (
      clk_i    => clk_i,
      signal_i => sda_i,
      signal_o => sync_sda);

  scl_sync: entity utils.metastability_filter
    port map (
      clk_i    => clk_i,
      signal_i => scl_i,
      signal_o => sync_scl);

  condition_detector: entity work.startstop_condition_detector
    port map (
      clk_i  => clk_i,
      sda_i   => sync_sda,
      scl_i   => sync_scl,
      start_o => start_condition,
      stop_o  => stop_condition);

  condition_generator : entity work.startstop_condition_generator
    generic map (
      DELAY => SCL_FALLING_DELAY)
    port map (
      clk_i                 => clk_i,
      rst_in                => rst_in,
      sda_i                 => sda_i,
      scl_rising_i          => scl_rising,
      scl_falling_i         => scl_falling,
      scl_falling_delayed_i => scl_falling_delayed,
      sda_enable_o          => cond_gen_sda_enable,
      start_condition_i     => start_condition,
      stop_condition_i      => stop_condition,
      gen_start_i           => cond_gen_start,
      gen_stop_i            => cond_gen_stop,
      req_scl_fall_o        => cond_gen_req_scl_fall,
      req_scl_rise_o        => cond_gen_req_scl_rise,
      done_o                => cond_gen_done);

  scl_generator : entity work.scl_generator
    generic map (
      MIN_STABLE_CYCLES => SCL_MIN_STABLE_CYCLES)
    port map (
      clk_i            => clk_i,
      rst_in           => rst_in,
      scl_i            => scl_i,
      scl_rising_i     => scl_rising,
      scl_falling_i    => scl_falling,
      gen_continuous_i => scl_gen_req_continuous,
      gen_rising_i     => cond_gen_req_scl_rise,
      gen_falling_i    => scl_gen_falling,
      scl_enable_o     => scl_gen_scl_enable,
      cannot_comply_o  => open);

  -- rx
  rx : entity work.rx
    port map (
      clk_i                 => clk_i,
      rst_in                => rst_in,
      start_read_i          => receiving,
      generate_ack_i        => generate_ack_i,
      rst_i2c_i             => rst_i2c,
      scl_rising            => scl_rising,
      scl_falling_delayed_i => scl_falling_delayed,
      scl_stretch_o         => rx_scl_stretch,
      sda_i                 => sda_i,
      sda_enable_o          => rx_sda_enable,
      read_valid_o          => rx_valid_o,
      read_ready_o          => open,
      read_data_o           => rx_data_o,
      done_o                => rx_done,
      confirm_read_i        => rx_confirm_i);

  -- tx
  tx : entity work.tx
    port map (
      clk_i                 => clk_i,
      rst_in                => rst_in,
      clear_buffer_i        => tx_clear_buffer_i,
      start_write_i         => transmitting,
      rst_i2c_i             => rst_i2c,
      scl_rising_i          => scl_rising,
      scl_falling_delayed_i => scl_falling_delayed,
      scl_stretch_o         => tx_scl_stretch,
      sda_i                 => sda_i,
      sda_enable_o          => tx_sda_enable,
      unexpected_sda_o      => tx_unexpected_sda,
      noack_o               => tx_noack,
      ready_o               => tx_ready_o,
      valid_i               => tx_valid_i,
      done_o                => tx_done,
      write_data_i          => tx_data_i);

  address_generator : entity work.address_generator
    port map (
      clk_i                 => clk_i,
      rst_in                => rst_in,
      address_i             => slave_address_i,
      scl_rising_i          => scl_rising,
      scl_falling_delayed_i => scl_falling_delayed,
      sda_enable_o          => adr_sda_enable,
      sda_i                 => sync_sda,
      noack_o               => adr_noack,
      unexpected_sda_o      => adr_unexpected_sda,
      done_o                => adr_done,
      start_i               => adr_gen_start,
      rw_i                  => rw);

  state_machine : entity work.master_state
    port map (
      clk_i                    => clk_i,
      rst_in                   => rst_in,
      rst_i2c_o                => rst_i2c,
--
      start_i                  => start_i,
      stop_i                   => stop_i,
      run_i                    => run_i,
      rw_i                     => rw,
--
      expect_ack_i             => expect_ack_i,
      noack_address_i          => adr_noack,
      noack_data_i             => tx_noack,
      unexpected_sda_address_i => adr_unexpected_sda,
      unexpected_sda_data_i    => tx_unexpected_sda,
--
      err_noack_address_o      => err_noack_address_o,
      err_noack_data_o         => err_noack_data_o,
      err_arbitration_o        => err_arbitration_o,
      err_general_o            => err_general_o,
--
      start_condition_i        => start_condition,
      stop_condition_i         => stop_condition,
--
      waiting_for_data_i       => waiting_for_data,
      rx_done_i                => rx_done,
      tx_done_i                => tx_done,
--
      address_gen_start_o      => adr_gen_start,
      address_gen_done_i       => adr_done,
--
      req_start_o              => cond_gen_start,
      req_stop_o               => cond_gen_stop,
      req_cond_done_i          => cond_gen_done,
--
      req_scl_continuous_o     => scl_gen_req_continuous,
--
      cond_gen_o               => cond_gen,
      address_gen_o            => adr_gen,
      receive_o                => receiving,
      transmit_o               => transmitting,
      bus_busy_o               => bus_busy);

end architecture a1;
