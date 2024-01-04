library ieee;
use ieee.std_logic_1164.all;

library i2c;
library vunit_lib;
context vunit_lib.vunit_context;

entity startstop_condition_generator_tb is

  generic (
    runner_cfg : string);

end entity startstop_condition_generator_tb;

architecture tb of startstop_condition_generator_tb is
  signal clk : std_logic := '0';
  constant CLK_PERIOD : time := 10 ns;

  signal rst_n : std_logic := '0';

  signal sda : std_logic := 'H';
  signal slave_sda : std_logic := 'H';
  signal sda_enable : std_logic;

  signal scl : std_logic := 'H';
  signal not_scl : std_logic;

  signal scl_rising : std_logic := '0';
  signal scl_falling : std_logic := '0';
  signal scl_falling_delayed : std_logic := '0';

  signal gen_start, gen_stop : std_logic := '0';
  signal req_scl_rise, req_scl_fall : std_logic := '0';

  signal start_condition : std_logic := '0';
  signal stop_condition : std_logic := '0';

  signal done : std_logic := '0';

  constant DELAY : natural := 5;
  constant TIMEOUT : time := DELAY * CLK_PERIOD * 2;
  signal one : std_logic := '1';
  signal zero : std_logic := '0';
begin  -- architecture tb

  clk <= not clk after CLK_PERIOD/2;
  rst_n <= '1' after 2*CLK_PERIOD;

  sda <= 'H';
  sda <= '0' when sda_enable = '1' else 'Z';

  slave_sda <= '1' when sda = 'H' else sda;

  not_scl <= not scl;
  scl <= 'H';

  uut : entity i2c.startstop_condition_generator
    generic map (
      DELAY => DELAY)
    port map (
      clk_i                 => clk,
      rst_in                => rst_n,
      sda_i                 => slave_sda,
      sda_enable_o          => sda_enable,
      scl_rising_i          => scl_rising,
      scl_falling_i         => scl_falling,
      scl_falling_delayed_i => scl_falling_delayed,
      start_condition_i     => start_condition,
      stop_condition_i      => stop_condition,
      gen_start_i           => gen_start,
      gen_stop_i            => gen_stop,
      req_scl_fall_o        => req_scl_fall,
      req_scl_rise_o        => req_scl_rise,
      done_o                => done);

  main: process is
    procedure wait_delay(constant delay : in integer) is
    begin  -- procedure wait_delay
      for i in 0 to delay loop
        wait until falling_edge(clk);
      end loop;  -- i
      wait until falling_edge(clk);
    end procedure wait_delay;

    procedure req_clear is
    begin  -- procedure req_clear
      gen_start <= '0';
      gen_stop <= '0';
    end procedure req_clear;

    procedure req_start is
    begin  -- procedure req_start
      req_clear;
      gen_start <= '1';
    end procedure req_start;

    procedure req_stop is
    begin  -- procedure req_start
      req_clear;
      gen_stop <= '1';
    end procedure req_stop;

    procedure wait_start_condition(nowait: std_logic := '0') is
    begin  -- procedure wait_start_condition
      check_equal(start_condition, '0', "Got start condition already when supposed to wait for it.");
      wait until rising_edge(start_condition) or rising_edge(stop_condition) for TIMEOUT;
      check_equal(stop_condition, '0', "Got stop condition instead of start.");
      check_equal(start_condition, '1', "Waiting for start condition timed out.");
      wait until falling_edge(clk);
    end procedure wait_start_condition;

    procedure wait_stop_condition is
    begin  -- procedure wait_start_condition
      check_equal(stop_condition, '0', "Got stop condition already when supposed to wait for it.");
      wait until rising_edge(stop_condition) or rising_edge(start_condition) for TIMEOUT;
      check_equal(start_condition, '0', "Got start condition instead of stop.");
      check_equal(stop_condition, '1', "Waiting for stop condition timed out.");
      wait until falling_edge(clk);
    end procedure wait_stop_condition;

    procedure wait_done is
    begin  -- procedure wait_done
      wait until rising_edge(done) for TIMEOUT;
      check_equal(done, '1', "Expected done.");
      wait until falling_edge(clk);
    end procedure wait_done;
    
    procedure comply_scl_rise(constant time_out: time := TIMEOUT) is
    begin  -- procedure comply_scl_rise
      wait until req_scl_rise = '1' or req_scl_fall = '1' for time_out;
      check_equal(req_scl_rise, '1', "Should want rise");
      check_equal(req_scl_fall, '0', "Should want rise, not fall");
      scl <= 'Z';
      wait until falling_edge(clk);
    end procedure comply_scl_rise;

    procedure comply_scl_fall is
    begin  -- procedure comply_scl_rise
      wait until req_scl_fall = '1' or req_scl_rise = '1' for TIMEOUT;
      check_equal(req_scl_fall, '1', "Should want fall");
      check_equal(req_scl_rise, '0', "Should want fall, not rise");
      scl <= '0';
      wait until falling_edge(clk);
    end procedure comply_scl_fall;

    procedure check_no_reqs is
    begin  -- procedure check_no_reqs
      check_equal(sda_enable, '0', "Should not hold sda enable after everything done.");
      wait until req_scl_fall = '1' or req_scl_rise = '1' or start_condition = '1' or stop_condition = '1' for TIMEOUT;
      check_equal(req_scl_fall, '0', "SCL fall was requested even though there shouldn't be any more requests.");
      check_equal(req_scl_rise, '0', "SCL rise was requested even though there shouldn't be any more requests.");
      check_equal(start_condition, '0', "Start condition triggered even though there shouldn't be any more conditions.");
      check_equal(stop_condition, '0', "Stop condition triggered even though there shouldn't be any more conditions.");
      check_equal(sda_enable, '0', "Should not hold sda enable after everything done.");
      wait until falling_edge(clk);
    end procedure check_no_reqs;
  begin  -- process main
    wait until rst_n = '1';
    wait until falling_edge(clk);

    check_equal(scl, 'H', "begin SCL not high");

    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("start") then

        req_start;
        wait_start_condition;
        comply_scl_fall;
        wait_done;
        check_no_reqs;

      elsif run("start_from_wrong_sda") then

        sda <= '0';
        req_start;
        comply_scl_fall;
        sda <= 'H';-- cannot hold SDA from outside
        comply_scl_rise(2*TIMEOUT);
        wait_start_condition;
        comply_scl_fall;
        wait_done;
        req_clear;
        check_no_reqs;

      elsif run("repeated_start") then

        scl <= '0';
        wait until falling_edge(scl_falling_delayed);
        req_start;
        comply_scl_rise;
        wait_start_condition;
        comply_scl_fall;
        wait_done;
        req_clear;
        check_no_reqs;

      elsif run("stop") then
        scl <= '0';
        wait until falling_edge(scl_falling_delayed);
        req_stop;
        comply_scl_rise;
        wait_stop_condition;
        wait_done;
        req_clear;
        check_no_reqs;

      elsif run("stop_from_high_scl") then
        sda <= '0';
        req_stop;
        wait for TIMEOUT;
        -- is not holding sda low
        check_equal(sda_enable, '0');
        -- that means sda would be
        -- high if not held by the
        -- testbench
        sda <= 'Z';
        wait_done;
        check_no_reqs;
      elsif run("stop_from_high_scl_wrong_sda") then
        req_stop;
        comply_scl_fall;
        comply_scl_rise(2*TIMEOUT);
        wait_stop_condition;
        wait_done;
        req_clear;
        check_no_reqs;
      elsif run("start_start_stop") then

        req_start;
        wait_start_condition;
        comply_scl_fall;
        wait_done;

        req_clear;
        wait until falling_edge(clk);

        check_equal(scl, '0');

        req_start;
        comply_scl_rise;
        wait_start_condition;
        comply_scl_fall;
        wait_done;

        req_clear;
        wait until falling_edge(clk);

        check_equal(scl, '0');

        req_stop;
        comply_scl_rise;
        wait_stop_condition;
        wait_done;
        check_no_reqs;

        check_equal(scl, 'H');

      elsif run("start_stop_start") then
        req_start;
        wait_start_condition;
        comply_scl_fall;
        wait_done;

        req_clear;
        wait until falling_edge(clk);

        check_equal(scl, '0');

        req_stop;
        comply_scl_rise;
        wait_stop_condition;
        wait_done;

        req_clear;
        wait until falling_edge(clk);

        check_equal(scl, 'H');

        req_start;
        wait_start_condition;
        comply_scl_fall;
        wait_done;
        check_no_reqs;
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process main;

  set_scl_rising: process is
  begin  -- process scl_rising
    wait until rising_edge(scl);
    scl_rising <= '1';
    wait until falling_edge(clk);
    wait until rising_edge(clk);
    scl_rising <= '0';
  end process set_scl_rising;

  set_scl_falling: process is
  begin  -- process scl_rising
    wait until falling_edge(scl);
    scl_falling <= '1';
    wait until rising_edge(clk);
    wait until falling_edge(clk);
    scl_falling <= '0';
  end process set_scl_falling;

  set_delayed_scl_falling: process is
  begin  -- process scl_rising
    wait until falling_edge(scl);
    wait until falling_edge(clk);
    scl_falling_delayed <= '1';
    wait until rising_edge(clk);
    wait until falling_edge(clk);
    scl_falling_delayed <= '0';
  end process set_delayed_scl_falling;

  set_start_condition: process is
  begin  -- process scl_rising
    wait until falling_edge(sda);
    if scl = 'H' then
        start_condition <= '1';
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        start_condition <= '0';
    end if;
  end process set_start_condition;

  set_stop_condition: process is
  begin  -- process scl_rising
    wait until rising_edge(sda);
    if scl = 'H' then
        stop_condition <= '1';
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        stop_condition <= '0';
    end if;
  end process set_stop_condition;

end architecture tb;
