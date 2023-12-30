library ieee;
use ieee.std_logic_1164.all;

library i2c;

library vunit_lib;
context vunit_lib.vunit_context;

entity startstop_condition_detector_tb is

  generic (
    runner_cfg : string);

end entity startstop_condition_detector_tb;

architecture tb of startstop_condition_detector_tb is
  signal clk : std_logic := '0';
  constant CLK_PERIOD : time := 10 ns;

  signal rst_n : std_logic := '0';

  signal sda, scl : std_logic;

  signal start, stop : std_logic;
begin  -- architecture tb
  uut: entity i2c.startstop_condition_detector
    port map (
      clk_i   => clk,
      sda_i   => sda,
      scl_i   => scl,
      start_o => start,
      stop_o  => stop);

  clk <= not clk after CLK_PERIOD / 2;
  rst_n <= '1' after 2 * CLK_PERIOD;

  main: process is
  begin  -- process
    sda <= '1';
    wait until rising_edge(clk);
    scl <= '1';
    wait until rst_n = '1';
    wait until falling_edge(clk);

    test_runner_setup(runner, runner_cfg);
    set_stop_level(failure);

    while test_suite loop
      if run("scl_high_start_stop") then
        -- start
        sda <= '0';
        wait until rising_edge(clk);
        check_equal(start, '1');
        check_equal(stop, '0');
        sda <= '1';
        wait until rising_edge(clk);
        check_equal(start, '0');
        check_equal(stop, '1');
        sda <= '1';
        wait until rising_edge(clk);
        check_equal(start, '0');
        check_equal(stop, '0');
        sda <= '1';
      elsif run("scl_low") then
        scl <= '0';
        sda <= '0';
        wait until falling_edge(clk);
        check_equal(start, '0');
        check_equal(stop, '0');
        sda <= '1';
        wait until falling_edge(clk);
        check_equal(start, '0');
        check_equal(stop, '0');
        sda <= '1';
        wait until falling_edge(clk);
        check_equal(start, '0');
        check_equal(stop, '0');
        sda <= '1';
      elsif run("scl_low_then_high") then
        scl <= '0';
        sda <= '0';
        wait until rising_edge(clk);
        check_equal(start, '0');
        check_equal(stop, '0');
        sda <= '1';
        wait until rising_edge(clk);
        check_equal(start, '0');
        check_equal(stop, '0');
        sda <= '1';
        wait until rising_edge(clk);
        check_equal(start, '0');
        check_equal(stop, '0');
        sda <= '1';
        wait until rising_edge(clk);
        scl <= '1';
        wait until rising_edge(clk);
        sda <= '0';
        wait until rising_edge(clk);
        check_equal(start, '1');
        check_equal(stop, '0');
        sda <= '1';
        wait until rising_edge(clk);
        check_equal(start, '0');
        check_equal(stop, '1');
        sda <= '1';
        wait until rising_edge(clk);
        check_equal(start, '0');
        check_equal(stop, '0');
        sda <= '1';
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process main;

end architecture tb;
