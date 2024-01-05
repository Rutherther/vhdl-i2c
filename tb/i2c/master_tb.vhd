library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;

library i2c;

use work.tb_pkg.all;
use work.tb_i2c_pkg.all;
use work.tb_i2c_master_pkg.all;
use work.tb_i2c_slave_pkg.all;

entity master_tb is

  generic (
    runner_cfg : string);

end entity master_tb;

architecture tb of master_tb is
  constant CLK_PERIOD : time := 10 ns;
  signal rst_n : std_logic := '0';

  signal master_sda_enable : std_logic;
  signal master_sda : std_logic;

  signal slave_address : std_logic_vector(6 downto 0);

  signal master_scl_enable : std_logic;
  signal master_scl : std_logic;

  signal dev_busy, bus_busy : std_logic;
  signal err_noack_address, err_noack_data, err_arbitration, err_general : std_logic;
  signal rw : std_logic;

  signal master_stop, master_start, master_run : std_logic := '0';
  signal waiting : std_logic;

  signal rx_confirm : std_logic := '0';

  signal tx_valid : std_logic := '0';
  signal tx_data : std_logic_vector(7 downto 0) := (others => '0');

  signal one  : std_logic := '1';
  signal zero : std_logic := '0';

  constant SCL_MIN_STABLE_CYCLES : natural := 10;
  constant TIMEOUT : time := SCL_MIN_STABLE_CYCLES * CLK_PERIOD * 2;
begin  -- architecture tb

  clk <= not clk after CLK_PERIOD / 2;
  rst_n <= '1' after 2 * CLK_PERIOD;

  sda <= 'H';
  scl <= 'H';

  sda <= '0' when master_sda_enable = '1' else 'Z';
  scl <= '0' when master_scl_enable = '1' else 'Z';

  master_sda <= '1' when sda = 'H' else sda;
  master_scl <= '1' when scl = 'H' else scl;

  uut : entity i2c.master
    generic map (
      SCL_FALLING_DELAY     => 1,
      SCL_MIN_STABLE_CYCLES => SCL_MIN_STABLE_CYCLES)
    port map (
      clk_i               => clk,
      rst_in              => rst_n,
--
      slave_address_i     => slave_address,
--
      generate_ack_i      => '1',
      expect_ack_i        => '1',
--
      rx_valid_o          => rx_valid,
      rx_data_o           => rx_data,
      rx_confirm_i        => rx_confirm,
--
      tx_ready_o          => tx_ready,
      tx_valid_i          => tx_valid,
      tx_data_i           => tx_data,
      tx_clear_buffer_i   => '0',
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
      bus_busy_o          => bus_busy,
      waiting_o           => waiting,
--
      sda_i               => master_sda,
      scl_i               => master_scl,
      sda_enable_o        => master_sda_enable,
      scl_enable_o        => master_scl_enable);

  -- stable sda_enable when scl high
  -- TODO ensure active only when no start/stop
  -- conditions should be generated...
  -- sda_stability_check: check_stable(clk, one, scl, not_scl, master_sda_enable);

  main: process is
    procedure request_start(
      constant address : in std_logic_vector(6 downto 0);
      constant rw_i : in std_logic;
      constant stop : in std_logic := '0') is
    begin  -- procedure request_start
      slave_address <= address;
      rw <= rw_i;

      master_start <= '1';
      master_stop <= stop;
      master_run <= '1';
      wait until falling_edge(clk);
      master_start <= '0';
      master_stop <= '0';
    end procedure request_start;

    procedure request_stop is
    begin  -- procedure request_stop
      master_start <= '0';
      master_stop <= '1';
      master_run <= '0';
      wait until falling_edge(clk);
      master_stop <= '0';
    end procedure request_stop;

    procedure check_errors (
      constant exp_noack_address : in std_logic := '0';
      constant exp_noack_data    : in std_logic := '0';
      constant exp_arbitration   : in std_logic := '0';
      constant exp_general : in std_logic := '0') is
    begin  -- procedure check_errors
      check_equal(err_noack_address, exp_noack_address, "Noack address error not as expected.");
      check_equal(err_noack_data, exp_noack_data, "Noack data error not as expected.");
      check_equal(err_arbitration, exp_arbitration, "Arbitration error not as expected.");
      check_equal(err_general, exp_general, "Gneral error not as expected.");
    end procedure check_errors;
  begin  -- process main
    wait until rst_n = '1';
    wait until falling_edge(clk);

    test_runner_setup(runner, runner_cfg);
    set_stop_level(failure);

    while test_suite loop
      if run("simple_read") then
        request_start("1110101", '1', stop => '1');
        i2c_slave_check_start("1110101", '1', TIMEOUT, scl, sda);
        i2c_slave_transmit("11101010", TIMEOUT, scl => scl, sda => sda);
        rx_read_data("11101010", rx_confirm);
        check_errors;
        i2c_slave_check_stop(TIMEOUT, scl, sda);
        check_errors;
      elsif run("simple_write") then
        request_start("1110101", '0', stop => '1');
        tx_write_data("11101010", tx_data, tx_valid);
        i2c_slave_check_start("1110101", '0', TIMEOUT, scl, sda);
        i2c_slave_receive("11101010", TIMEOUT, scl, sda);
        check_errors;
        i2c_slave_check_stop(TIMEOUT, scl, sda);
        check_errors;
      elsif run("multi_read") then
        request_start("1110101", '1');
        i2c_slave_check_start("1110101", '1', TIMEOUT, scl, sda);
        i2c_slave_transmit("11101010", TIMEOUT, scl => scl, sda => sda);
        rx_read_data("11101010", rx_confirm);

        i2c_slave_transmit("00001111", TIMEOUT, scl => scl, sda => sda);
        rx_read_data("00001111", rx_confirm);
        i2c_slave_transmit("11110000", TIMEOUT, scl => scl, sda => sda);
        rx_read_data("11110000", rx_confirm);
        request_stop;
        check_errors;
        i2c_slave_check_stop(TIMEOUT, scl, sda);
        check_errors;
      elsif run("multi_write") then
        tx_write_data("11101010", tx_data, tx_valid);
        tx_write_data("00011100", tx_data, tx_valid);
        request_start("1110101", '0');
        i2c_slave_check_start("1110101", '0', TIMEOUT, scl, sda);
        i2c_slave_receive("11101010", TIMEOUT, scl, sda);
        tx_write_data("00000000", tx_data, tx_valid);
        i2c_slave_receive("00011100", TIMEOUT, scl, sda);
        i2c_slave_receive("00000000", TIMEOUT, scl, sda);
        request_stop;
        check_errors;
        i2c_slave_check_stop(TIMEOUT, scl, sda);
        check_errors;
      elsif run("waiting") then
        request_start("1110101", '0');
        i2c_slave_check_start("1110101", '0', TIMEOUT, scl, sda);
        check_errors;
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        for i in 0 to 100 loop
          check_equal(waiting, '1');
          check_equal(scl, '0');
          wait until falling_edge(clk);
        end loop;  -- i

        check_errors;
        tx_write_data("00000000", tx_data, tx_valid);
        check_equal(waiting, '0');
        i2c_slave_receive("00000000", 2 * TIMEOUT, scl, sda);
        request_stop;
        check_errors;
        i2c_slave_check_stop(TIMEOUT, scl, sda);
        check_errors;
      elsif run("write_read") then
        tx_write_data("11101010", tx_data, tx_valid);
        tx_write_data("00001111", tx_data, tx_valid);
        request_start("0001011", '0');
        i2c_slave_check_start("0001011", '0', TIMEOUT, scl, sda);
        i2c_slave_receive("11101010", TIMEOUT, scl, sda);
        i2c_slave_receive("00001111", TIMEOUT, scl, sda);
        check_errors;
        request_start("0001011", '1', stop => '1');
        i2c_slave_check_start("0001011", '1', 2 * TIMEOUT, scl, sda);
        check_errors;
        i2c_slave_transmit("00010101", TIMEOUT, scl, sda);
        rx_read_data("00010101", rx_confirm);
        check_errors;
        i2c_slave_check_stop(TIMEOUT, scl, sda);
        check_errors;
      elsif run("lost_arbitration_early") then
        request_start("1110101", '0', stop => '1');
        i2c_master_start("0000000", '0', scl, sda, exp_ack => '0');
        check_errors(exp_arbitration => '1');
      elsif run("lost_arbitration_late") then
        request_start("1110101", '0', stop => '1');
        tx_write_data("11101010", tx_data, tx_valid);
        i2c_slave_check_start("1110101", '0', TIMEOUT, scl, sda);

        sda <= '0';
        wait_for_scl_rise(timeout, scl);
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        scl_fall(scl); -- have to do manually (simulate another master)
        sda <= 'Z';

        check_errors(exp_arbitration => '1');
      elsif run("unexpected_start") then
        request_start("1110101", '0', stop => '1');
        tx_write_data("11101010", tx_data, tx_valid);
        i2c_slave_check_start("1110101", '0', TIMEOUT, scl, sda);

        wait_for_scl_rise(timeout, scl);
        wait_for_scl_fall(timeout, scl);
        wait_for_scl_rise(timeout, scl);
        wait until falling_edge(clk);
        sda <= '0'; -- start
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        check_errors(exp_general => '1');
      elsif run("noack_address") then
        request_start("1110101", '0');
        tx_write_data("11101010", tx_data, tx_valid);
        i2c_slave_check_start("1110101", '0', TIMEOUT, scl, sda, ack => '0');
        check_errors(exp_noack_address => '1');
        i2c_slave_check_stop(TIMEOUT, scl, sda);
        check_errors(exp_noack_address => '1');
      elsif run("noack_data") then
        request_start("1110101", '0');
        tx_write_data("11101010", tx_data, tx_valid);
        i2c_slave_check_start("1110101", '0', TIMEOUT, scl, sda);
        i2c_slave_receive("11101010", TIMEOUT, scl, sda, ack => '0');
        check_errors(exp_noack_data => '1');
        i2c_slave_check_stop(TIMEOUT, scl, sda);
        check_errors(exp_noack_data => '1');
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process main;
end architecture tb;
