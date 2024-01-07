library ieee;
use ieee.std_logic_1164.all;

library utils;

entity slave is
  generic (
    SCL_FALLING_DELAY : natural := 5);

  port (
    clk_i        : in std_logic;        -- Synchronous clock
    rst_in       : in std_logic;        -- Synchronous reset (active low)

    -- address
    address_i      : in std_logic_vector(6 downto 0);  -- Address of the slave
    generate_ack_i : in std_logic;
    expect_ack_i   : in std_logic;

    -- rx
    rx_valid_o   : out std_logic;       -- Data in rx_data are valid
    rx_data_o    : out std_logic_vector(7 downto 0);  -- Received data
    rx_confirm_i : in std_logic;        -- Confirm data from rx_data are read
    rx_stretch_i : in std_logic;

    -- tx
    tx_ready_o        : out std_logic;  -- Transmitter ready for new data
    tx_valid_i        : in  std_logic;  -- Are data in tx_data valid? Should be
                                        -- a pulse for one cycle only
    tx_data_i         : in  std_logic_vector(7 downto 0);  -- Data to transmit
    tx_stretch_i      : in  std_logic;
    tx_clear_buffer_i : in  std_logic;

    -- errors
    err_noack_o  : out std_logic;
    err_sda_o  : out std_logic;

    -- state
    rw_o         : out std_logic;       -- 1 - read, 0 - write
    dev_busy_o   : out std_logic;       -- Communicating with master
    bus_busy_o   : out std_logic;       -- Bus is busy, someone else is communicating
    waiting_o    : out std_logic;       -- Waiting for data or read data

    sda_i        : in std_logic;        -- I2C SDA line
    scl_i        : in std_logic;        -- I2C SCL line

    sda_enable_o : out std_logic;       -- Pull down sda
    scl_enable_o : out std_logic);      -- Pull down scl

end entity slave;

architecture a1 of slave is
  signal sync_sda, sync_scl                  : std_logic;
  signal start_condition, stop_condition     : std_logic;
  signal scl_rising, scl_falling : std_logic;

  signal transmitting, receiving : std_logic;

  signal tx_sda_enable : std_logic;
  signal tx_scl_stretch : std_logic;
  signal tx_noack, tx_unexpected_sda : std_logic;

  signal rx_sda_enable : std_logic;
  signal rx_scl_stretch : std_logic;

  signal address_detect_sda_enable : std_logic;

  signal bus_busy : std_logic;

  signal address_detect_activate : std_logic;
  signal address_detect_success : std_logic;
  signal address_detect_fail : std_logic;
  signal address_detect_store : std_logic;
  signal address_detection : std_logic;

  signal rw : std_logic;
  signal rst_i2c : std_logic;

  signal scl_falling_delayed : std_logic;
begin  -- architecture a1
  rw_o <= rw;
  dev_busy_o <= transmitting or receiving;
  bus_busy_o <= bus_busy;
  waiting_o <= tx_scl_stretch or rx_scl_stretch;

  scl_enable_o <= tx_scl_stretch when transmitting = '1' and tx_stretch_i = '1' and scl_i = '0' else
                  rx_scl_stretch when receiving = '1' and rx_stretch_i = '1' and scl_i = '0' else
                  '0';

  sda_enable_o <= tx_sda_enable when transmitting = '1' else
                  rx_sda_enable when receiving = '1' else
                  address_detect_sda_enable when address_detection = '1' else
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

  -- rx
  rx : entity work.rx
    port map (
      clk_i                 => clk_i,
      rst_in                => rst_in,
      start_read_i          => receiving,
      generate_ack_i        => generate_ack_i,
      rst_i2c_i             => rst_i2c,
      scl_rising           => scl_rising,
      scl_falling_delayed_i => scl_falling_delayed,
      scl_stretch_o         => rx_scl_stretch,
      sda_i                 => sda_i,
      sda_enable_o          => rx_sda_enable,
      read_valid_o          => rx_valid_o,
      read_ready_o          => open,
      read_data_o           => rx_data_o,
      confirm_read_i        => rx_confirm_i);

  -- tx
  tx : entity work.tx
    port map (
      clk_i                 => clk_i,
      rst_in                => rst_in,
      clear_buffer_i        => tx_clear_buffer_i,
      start_write_i         => transmitting,
      rst_i2c_i             => rst_i2c,
      scl_rising_i    => scl_rising,
      scl_falling_delayed_i => scl_falling_delayed,
      scl_stretch_o         => tx_scl_stretch,
      sda_i                 => sda_i,
      sda_enable_o          => tx_sda_enable,
      unexpected_sda_o      => tx_unexpected_sda,
      noack_o               => tx_noack,
      ready_o               => tx_ready_o,
      valid_i               => tx_valid_i,
      write_data_i          => tx_data_i);

  address_detector : entity work.address_detector
    port map (
      clk_i                 => clk_i,
      rst_in                => rst_in,
      address_i             => address_i,
      store_address_i       => address_detect_store,
      scl_rising            => scl_rising,
      scl_falling_delayed_i => scl_falling_delayed,
      sda_enable_o          => address_detect_sda_enable,
      sda_i                 => sync_sda,
      start_i               => address_detect_activate,
      rw_o                  => rw,
      success_o             => address_detect_success,
      fail_o                => address_detect_fail);

  state_machine : entity work.i2c_slave_state
    port map (
      clk_i                    => clk_i,
      rst_in                   => rst_in,
      rst_i2c_o                => rst_i2c,
      start_condition_i        => start_condition,
      stop_condition_i         => stop_condition,
      err_noack_o              => err_noack_o,
      err_sda_o                => err_sda_o,
      unexpected_sda_i         => tx_unexpected_sda,
      expect_ack_i             => expect_ack_i,
      noack_i                  => tx_noack,
      rw_i                     => rw,
      address_detect_success_i => address_detect_success,
      address_detect_fail_i    => address_detect_fail,
      address_detect_start_o   => address_detect_activate,
      address_detect_store_o   => address_detect_store,
      address_detect_o         => address_detection,
      receive_o                => receiving,
      transmit_o               => transmitting,
      bus_busy_o               => bus_busy);

end architecture a1;
