library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;

library i2c;

entity slave_tb is

  generic (
    runner_cfg : string);

end entity slave_tb;

architecture tb of slave_tb is
  signal clk : std_logic := '0';
  constant CLK_PERIOD : time := 10 ns;
  signal rst_n : std_logic := '0';

  signal sda : std_logic;
  signal sda_override : std_logic := '0';
  signal slave_sda_enable : std_logic;

  signal address : std_logic_vector(6 downto 0);

  signal not_scl, scl : std_logic;
  signal scl_override : std_logic := '0';
  signal slave_scl_enable : std_logic;

  signal dev_busy, bus_busy : std_logic;
  signal err_noack : std_logic;
  signal rw : std_logic;

  signal rx_valid : std_logic;
  signal rx_confirm : std_logic := '0';
  signal rx_data : std_logic_vector(7 downto 0) := (others => '0');

  signal tx_valid : std_logic := '0';
  signal tx_ready : std_logic;
  signal tx_data : std_logic_vector(7 downto 0) := (others => '0');

  procedure scl_fall (
    signal scl_override : inout std_logic) is
  begin  -- procedure scl_rise
    scl_override <= '1';
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    wait until falling_edge(clk);
  end procedure scl_fall;

  procedure scl_rise (
    signal scl_override : inout std_logic) is
  begin  -- procedure scl_rise
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    scl_override <= '0';
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    wait until falling_edge(clk);
  end procedure scl_rise;

  procedure scl_pulse (
    signal scl_override : inout std_logic) is
  begin  -- procedure scl_rise
    scl_rise(scl_override);
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    scl_fall(scl_override);
  end procedure scl_pulse;

  procedure sda_fall (
    signal sda_override : inout std_logic;
    constant assert_no_condition : in std_logic := '1') is
  begin  -- procedure scl_rise
    if assert_no_condition = '1' and sda /= '0' then
      check_equal(scl, '0', "Cannot change sda as that would trigger start condition.", failure);
    end if;

    sda_override <= '1';
    wait until falling_edge(clk);
  end procedure sda_fall;

  procedure sda_rise (
    signal sda_override : inout std_logic;
    constant assert_no_condition : in std_logic := '1') is
  begin  -- procedure scl_rise
    if assert_no_condition = '1' and sda /= '0' then
      check_equal(scl, '0', "Cannot change sda as that would trigger stop condition.", failure);
    end if;

    sda_override <= '0';
    wait until falling_edge(clk);
  end procedure sda_rise;

  procedure tx_write_data (
    constant data   : in    std_logic_vector(7 downto 0);
    signal tx_data : inout std_logic_vector(7 downto 0);
    signal tx_valid : inout std_logic
    ) is
  begin
    check_equal(tx_ready, '1');
    tx_data <= data;
    tx_valid <= '1';
    wait until falling_edge(clk);
    tx_valid <= '0';
  end procedure tx_write_data;

  procedure rx_read_data (
    constant exp_data : in std_logic_vector(7 downto 0);
    signal rx_confirm_read : inout std_logic
    ) is
  begin
    check_equal(rx_valid, '1');
    check_equal(rx_data, exp_data);
    rx_confirm_read <= '1';
    wait until falling_edge(clk);
    rx_confirm_read <= '0';
  end procedure rx_read_data;

  procedure i2c_stop_tx (
    signal scl_override : inout std_logic;
    signal sda_override : inout std_logic) is
  begin  -- procedure stop_tx

    scl_fall(scl_override);
    sda_fall(sda_override);
    scl_rise(scl_override);

    -- stop condition
    sda_rise(sda_override, '0');

  end procedure i2c_stop_tx;

  procedure i2c_transmit (
    constant data   : in    std_logic_vector(7 downto 0);
    signal scl_override : inout std_logic;
    signal sda_override : inout std_logic;
    constant stop_condition : in std_logic := '0';
    constant exp_ack : in std_logic := '1') is

  begin  -- procedure transmit
    check_equal(scl_override, '0', "Cannot start sending when scl is not in default state (1).", failure);
    check_equal(scl, '1', "Cannot start sending when scl is not in default state (1). Seems like the slave is clock stretching. This is not supported by transmit since data have to be supplied or read.", failure);

    scl_fall(scl_override);

    -- data
    for i in 7 downto 0 loop
      sda_override <= not data(i);
      scl_pulse(scl_override);
    end loop;  -- i

    sda_override <= '0';
    scl_rise(scl_override);
    if exp_ack = '1' then
      check_equal(sda, '0');
    elsif exp_ack = '0' then
      check_equal(sda, '1');
    end if;

    if stop_condition = '1' then
      if sda = '0' then
        -- keep sda low
        sda_override <= '1';
      end if;

      i2c_stop_tx(scl_override, sda_override);

    end if;
  end procedure i2c_transmit;

  procedure i2c_receive (
    constant exp_data       : in    std_logic_vector(7 downto 0);
    signal scl_override     : inout std_logic;
    signal sda_override     : inout std_logic;
    constant ack            : in    std_logic := '1';
    constant stop_condition : in    std_logic := '0') is

  begin  -- procedure transmit
    check_equal(scl_override, '0', "Cannot start receiving when scl is not in default state (1).", failure);
    check_equal(scl, '1', "Cannot start receiving when scl is not in default state (1). Seems like the slave is clock stretching. This is not supported by transmit since data have to be supplied or read.", failure);

    scl_fall(scl_override);
    sda_override <= '0';

    -- data
    for i in 7 downto 0 loop
      scl_rise(scl_override);
      check_equal(sda, exp_data(i));
      scl_fall(scl_override);
    end loop;  -- i

    if ack = '1' then
      sda_override <= '1';
    end if;

    scl_rise(scl_override);

    if stop_condition = '1' then
      if sda = '0' then
        -- keep sda low
        sda_override <= '1';
      end if;

      i2c_stop_tx(scl_override, sda_override);

    end if;
  end procedure i2c_receive;

  procedure i2c_start_tx (
    constant address : in    std_logic_vector(6 downto 0);
    constant rw      : in    std_logic;
    signal scl_override : inout std_logic;
    signal sda_override : inout std_logic;
    constant exp_ack : in std_logic := '1') is
  begin
    if scl = '1' and sda = '0' then
      scl_fall(scl_override);
    end if;

    if sda = '0' then
      sda_rise(sda_override);
    end if;

    if scl = '0' then
      scl_rise(scl_override);
    end if;

    check_equal(sda, '1', "Cannot start sending when sda is not in default state (1).", failure);
    check_equal(scl, '1', "Cannot start sending when scl is not in default state (1).", failure);

    -- start condition
    sda_fall(sda_override, '0');

    i2c_transmit(address & rw, scl_override, sda_override, stop_condition => '0', exp_ack => exp_ack);

  end procedure i2c_start_tx;

  signal one  : std_logic := '1';
  signal zero : std_logic := '0';
begin  -- architecture tb

  clk <= not clk after CLK_PERIOD / 2;
  rst_n <= '1' after 2 * CLK_PERIOD;

  scl <= not scl_override and not slave_scl_enable;
  sda <= not sda_override and not slave_sda_enable;

  not_scl <= not scl;

  uut: entity i2c.slave
    generic map (
      SCL_FALLING_DELAY => 1)
    port map (
      clk_i          => clk,
      rst_in         => rst_n,
      address_i      => address,
      generate_ack_i => '1',
      expect_ack_i   => '1',

      rx_valid_o     => rx_valid,
      rx_data_o      => rx_data,
      rx_confirm_i   => rx_confirm,
      rx_stretch_i   => '0',

      tx_ready_o     => tx_ready,
      tx_valid_i     => tx_valid,
      tx_data_i      => tx_data,
      tx_stretch_i   => '0',
      tx_clear_buffer_i => '0',

      err_noack_o    => err_noack,
      rw_o           => rw,
      dev_busy_o     => dev_busy,
      bus_busy_o     => bus_busy,
      sda_i          => sda,
      scl_i          => scl,
      sda_enable_o   => slave_sda_enable,
      scl_enable_o   => slave_scl_enable);

  -- stable sda_enable when scl high
  sda_stability_check: check_stable(clk, one, scl, not_scl, slave_sda_enable);

  main: process is
  begin  -- process main
    wait until rst_n = '1';
    wait until falling_edge(clk);

    test_runner_setup(runner, runner_cfg);
    set_stop_level(failure);

    while test_suite loop
      if run("simple_read") then
        address <= "1100001";

        i2c_start_tx("1100001", '1', scl_override, sda_override);

        tx_write_data("11010100", tx_data, tx_valid);
        tx_write_data("00110011", tx_data, tx_valid);

        i2c_receive("11010100", scl_override, sda_override);
        check_equal(rw, '1');
        check_equal(dev_busy, '1');

        i2c_receive("00110011", scl_override, sda_override);
        i2c_stop_tx(scl_override, sda_override);
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        check_equal(dev_busy, '0');
        check_equal(bus_busy, '0');
      elsif run("simple_write") then
        address <= "1100000";
        i2c_start_tx("1100000", '0', scl_override, sda_override);
        i2c_transmit("11010100", scl_override, sda_override);
        check_equal(rw, '0');
        check_equal(dev_busy, '1');

        rx_read_data("11010100", rx_confirm);
        i2c_transmit("11001100", scl_override, sda_override);
        rx_read_data("11001100", rx_confirm);
        i2c_stop_tx(scl_override, sda_override);
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        check_equal(dev_busy, '0');
        check_equal(bus_busy, '0');
      elsif run("different_address") then
        address <= "1111000";
        i2c_start_tx("1100000", '0', scl_override, sda_override, exp_ack => '0');
        i2c_transmit("11010100", scl_override, sda_override, exp_ack => '0');

        check_equal(dev_busy, '0');
        check_equal(bus_busy, '1');
        i2c_stop_tx(scl_override, sda_override);

        wait until falling_edge(clk);
        wait until falling_edge(clk);
        check_equal(dev_busy, '0');
        check_equal(bus_busy, '0');
      elsif run("read_noack") then
        address <= "1100001";

        i2c_start_tx("1100001", '1', scl_override, sda_override);

        tx_write_data("11010100", tx_data, tx_valid);

        check_equal(err_noack, '0');

        i2c_receive("11010100", scl_override, sda_override, ack => '0');
        check_equal(rw, '1');
        check_equal(dev_busy, '1');

        check_equal(err_noack, '1');

        i2c_stop_tx(scl_override, sda_override);

        wait until falling_edge(clk);
        wait until falling_edge(clk);
        check_equal(dev_busy, '0');
        check_equal(bus_busy, '0');
      elsif run("write_read") then
        address <= "1100000";
        i2c_start_tx("1100000", '0', scl_override, sda_override);
        i2c_transmit("11010100", scl_override, sda_override);
        check_equal(rw, '0');
        check_equal(dev_busy, '1');

        rx_read_data("11010100", rx_confirm);

        i2c_start_tx("1100000", '1', scl_override, sda_override);

        tx_write_data("11010100", tx_data, tx_valid);
        i2c_receive("11010100", scl_override, sda_override);
        check_equal(rw, '1');
        check_equal(dev_busy, '1');

        tx_write_data("00001111", tx_data, tx_valid);
        i2c_receive("00001111", scl_override, sda_override);

        i2c_stop_tx(scl_override, sda_override);
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        check_equal(dev_busy, '0');
        check_equal(bus_busy, '0');
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process main;
end architecture tb;
