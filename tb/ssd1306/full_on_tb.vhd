library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library ssd1306;

library utils;

library i2c_tb;
use i2c_tb.tb_pkg.all;
use i2c_tb.tb_i2c_pkg.all;
use i2c_tb.tb_i2c_slave_pkg.all;

entity full_on_tb is

  generic (
    runner_cfg : string);

end entity full_on_tb;

architecture tb of full_on_tb is
  constant ADDRESS : std_logic_vector(6 downto 0) := "0111100";
  constant CLK_PERIOD : time := 10 ns;

  signal rst_n : std_logic := '0';
  signal rst : std_logic;

  signal not_scl : std_logic;

  signal err_noack_data, err_noack_address, err_arbitration, err_general : std_logic;
  signal bus_busy, dev_busy : std_logic;

  signal one : std_logic := '1';
  constant SCL_MIN_STABLE_CYCLES : natural := 10;
  constant TIMEOUT : time := SCL_MIN_STABLE_CYCLES * CLK_PERIOD * 4;
begin  -- architecture tb
  uut : entity ssd1306.full_on
    generic map (
      CLK_FREQ => 10000000,
      I2C_CLK_FREQ => 10000000,
      DELAY => 1,
      SCL_MIN_STABLE_CYCLES => SCL_MIN_STABLE_CYCLES)
    port map (
      clk_i               => clk,
      rst_i               => rst,
      start_i => '1',
      err_noack_data_o    => err_noack_data,
      err_noack_address_o => err_noack_address,
      err_arbitration_o   => err_arbitration,
      err_general_o       => err_general,
      dev_busy_o          => dev_busy,
      bus_busy_o          => bus_busy,
      sda_io              => sda,
      scl_io              => scl
    );

  sda <= 'H';
  scl <= 'H';

  not_scl <= not scl;

  clk <= not clk after CLK_PERIOD / 2;
  rst_n <= '1' after 6 * CLK_PERIOD;
  rst <= not rst_n;

  -- TODO: allow conditions from master...
  -- sda_stability_check: check_stable(clk, one, scl, not_scl, sda);

  main: process is
  begin  -- process main
    wait until rst_n = '1';
    wait for 2 * CLK_PERIOD;
    wait until falling_edge(clk);
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("start") then
        i2c_slave_check_start(ADDRESS, '0', TIMEOUT, scl, sda);
        i2c_slave_receive(X"80", TIMEOUT, scl, sda);
        i2c_slave_receive(X"A8", TIMEOUT, scl, sda);
        i2c_slave_receive(X"80", TIMEOUT, scl, sda);
        i2c_slave_receive(X"3F", TIMEOUT, scl, sda);
        i2c_slave_receive(X"80", TIMEOUT, scl, sda);
        -- stop because no ack
        i2c_slave_check_stop(TIMEOUT * 10, scl, sda);
      elsif run("last") then
        i2c_slave_check_start(ADDRESS, '0', TIMEOUT, scl, sda);
        for i in 0 to 35 loop
            i2c_slave_receive(X"ZZ", TIMEOUT, scl, sda);
        end loop;  -- i
        i2c_slave_receive(X"80", TIMEOUT, scl, sda);
        i2c_slave_receive(X"A5", TIMEOUT, scl, sda);
        i2c_slave_check_stop(TIMEOUT, scl, sda);
      elsif run("every_second_X80") then
        i2c_slave_check_start(ADDRESS, '0', TIMEOUT, scl, sda);
        for i in 0 to 18 loop
            i2c_slave_receive(X"80", TIMEOUT, scl, sda);
            i2c_slave_receive(X"ZZ", TIMEOUT, scl, sda);
        end loop;  -- i
        i2c_slave_check_stop(TIMEOUT, scl, sda);
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process main;

end architecture tb;
