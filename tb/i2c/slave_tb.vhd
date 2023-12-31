library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;

library i2c;

use work.tb_pkg.all;
use work.tb_i2c_pkg.all;
use work.tb_i2c_master_pkg.all;

entity slave_tb is

  generic (
    runner_cfg : string);

end entity slave_tb;

architecture tb of slave_tb is
  constant CLK_PERIOD : time := 10 ns;
  signal rst_n : std_logic := '0';

  signal slave_sda_enable : std_logic;
  signal slave_sda : std_logic;

  signal address : std_logic_vector(6 downto 0);

  signal not_scl : std_logic;
  signal slave_scl_enable : std_logic;
  signal slave_scl : std_logic;

  signal dev_busy, bus_busy : std_logic;
  signal err_noack, err_sda : std_logic;
  signal rw : std_logic;

  signal rx_confirm : std_logic := '0';

  signal tx_valid : std_logic := '0';
  signal tx_data : std_logic_vector(7 downto 0) := (others => '0');

  signal one  : std_logic := '1';
  signal zero : std_logic := '0';
begin  -- architecture tb

  clk <= not clk after CLK_PERIOD / 2;
  rst_n <= '1' after 2 * CLK_PERIOD;

  sda <= 'H';
  scl <= 'H';

  sda <= '0' when slave_sda_enable = '1' else 'Z';
  scl <= '0' when slave_scl_enable = '1' else 'Z';

  slave_sda <= '1' when sda = 'H' else sda;
  slave_scl <= '1' when scl = 'H' else scl;

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

      err_noack_o  => err_noack,
      err_sda_o    => err_sda,
      rw_o         => rw,
      dev_busy_o   => dev_busy,
      bus_busy_o   => bus_busy,
      sda_i        => slave_sda,
      scl_i        => slave_scl,
      sda_enable_o => slave_sda_enable,
      scl_enable_o => slave_scl_enable);

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

        i2c_master_start("1100001", '1', scl, sda);

        tx_write_data("11010100", tx_data, tx_valid);
        tx_write_data("00110011", tx_data, tx_valid);

        i2c_master_receive("11010100", scl, sda);
        check_equal(rw, '1');
        check_equal(dev_busy, '1');

        i2c_master_receive("00110011", scl, sda);
        i2c_master_stop(scl, sda);
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        check_equal(dev_busy, '0');
        check_equal(bus_busy, '0');
      elsif run("simple_write") then
        address <= "1100000";
        i2c_master_start("1100000", '0', scl, sda);
        i2c_master_transmit("11010100", scl, sda);
        check_equal(rw, '0');
        check_equal(dev_busy, '1');

        rx_read_data("11010100", rx_confirm);
        i2c_master_transmit("11001100", scl, sda);
        rx_read_data("11001100", rx_confirm);
        i2c_master_stop(scl, sda);
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        check_equal(dev_busy, '0');
        check_equal(bus_busy, '0');
      elsif run("different_address") then
        address <= "1111000";
        i2c_master_start("1100000", '0', scl, sda, exp_ack => '0');
        i2c_master_transmit("11010100", scl, sda, exp_ack => '0');

        check_equal(dev_busy, '0');
        check_equal(bus_busy, '1');
        i2c_master_stop(scl, sda);

        wait until falling_edge(clk);
        wait until falling_edge(clk);
        check_equal(dev_busy, '0');
        check_equal(bus_busy, '0');
      elsif run("read_noack") then
        address <= "1100001";

        i2c_master_start("1100001", '1', scl, sda);

        tx_write_data("11010100", tx_data, tx_valid);

        check_equal(err_noack, '0');

        i2c_master_receive("11010100", scl, sda, ack => '0');
        check_equal(rw, '1');

        check_equal(err_noack, '1');

        i2c_master_stop(scl, sda);

        wait until falling_edge(clk);
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        check_equal(err_noack, '0');

        wait until falling_edge(clk);
        wait until falling_edge(clk);
        check_equal(dev_busy, '0');
        check_equal(bus_busy, '0');
      elsif run("read_unexpected_sda") then
        address <= "1100001";

        i2c_master_start("1100001", '1', scl, sda);

        tx_write_data("11010100", tx_data, tx_valid);

        scl_fall(scl);
        sda <= '0';

        scl_rise(scl);

        check_equal(err_sda, '1');

        i2c_master_stop(scl, sda);

        wait until falling_edge(clk);
        wait until falling_edge(clk);
        wait until falling_edge(clk);

        check_equal(err_sda, '0');
        check_equal(dev_busy, '0');
        check_equal(bus_busy, '0');
      elsif run("write_read") then
        address <= "1100000";
        i2c_master_start("1100000", '0', scl, sda);
        i2c_master_transmit("11010100", scl, sda);
        check_equal(rw, '0');
        check_equal(dev_busy, '1');

        rx_read_data("11010100", rx_confirm);

        i2c_master_start("1100000", '1', scl, sda);

        tx_write_data("11010100", tx_data, tx_valid);
        i2c_master_receive("11010100", scl, sda);
        check_equal(rw, '1');
        check_equal(dev_busy, '1');

        tx_write_data("00001111", tx_data, tx_valid);
        i2c_master_receive("00001111", scl, sda);

        i2c_master_stop(scl, sda);
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        check_equal(dev_busy, '0');
        check_equal(bus_busy, '0');
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process main;
end architecture tb;
