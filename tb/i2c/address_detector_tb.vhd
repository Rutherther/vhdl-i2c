library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;

library i2c;

entity address_detector_tb is

  generic (
    runner_cfg : string);

end entity address_detector_tb;

architecture tb of address_detector_tb is
  signal clk : std_logic := '0';
  constant CLK_PERIOD : time := 10 ns;

  signal rst_n : std_logic := '0';

  signal scl_pulse : std_logic := '0';
  signal scl_falling_pulse : std_logic := '0';
  signal sda : std_logic;
  signal scl : std_logic := '0';

  signal start : std_logic;

  signal address : std_logic_vector(6 downto 0);
  signal success, fail, rw : std_logic;

  signal sda_enable : std_logic;

  shared variable trigger_scl_pulse : std_logic := '0';
  signal triggered_scl_pulse : std_logic := '0';
  shared variable trigger_start : std_logic := '0';

  signal one : std_logic := '1';
begin  -- architecture tb

  clk <= not clk after CLK_PERIOD / 2;
  rst_n <= '1' after 2 * CLK_PERIOD;

  uut : entity i2c.address_detector
    port map (
      clk_i                 => clk,
      rst_in                => rst_n,
      address_i             => address,
      scl_pulse_i           => scl_pulse,
      scl_falling_delayed_i => scl_falling_pulse,
      sda_i                 => sda,
      sda_enable_o          => sda_enable,
      start_i               => start,
      rw_o                  => rw,
      success_o             => success,
      fail_o                => fail);

  do_trigger_scl_pulse: process is
  begin  -- process trigger_scl_pulse
    wait until rising_edge(clk);
    if trigger_scl_pulse = '1' then
        scl_pulse <= '1';
        scl_falling_pulse <= '0';
        wait until rising_edge(clk);
        scl_pulse <= '0';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        scl_falling_pulse <= '1';
        wait until rising_edge(clk);
        scl_falling_pulse <= '0';
        trigger_scl_pulse := '0';

        wait until rising_edge(clk);

        triggered_scl_pulse <= '1';
        wait for 0 ns;
        triggered_scl_pulse <= '0';
    end if;
  end process do_trigger_scl_pulse;

  do_trigger_start: process is
  begin  -- process trigger_scl_pulse
    wait until rising_edge(clk);
    if trigger_start = '1' then
        start <= '1';
        wait until rising_edge(clk);
        wait for 0 ns;
        start <= '0';
        trigger_start := '0';
    end if;
  end process do_trigger_start;

  main: process is
  begin  -- process main
    wait until rst_n = '1';
    wait until falling_edge(clk);

    test_runner_setup(runner, runner_cfg);
    set_stop_level(failure);

    while test_suite loop
      if run("matching") then
        address <= "1100011";
        check_equal(success, '0');
        check_equal(fail, '0');

        trigger_start := '1';
        wait for 0 ns;
        wait until falling_edge(start);
        report "ah";

        sda <= '1';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);


        sda <= '1';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);


        sda <= '0';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);


        sda <= '0';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);


        sda <= '0';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);


        sda <= '1';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);


        sda <= '1';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);


        sda <= 'X'; -- rw
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);


        check_equal(sda_enable, '1');
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);

        wait until falling_edge(clk);
        check_equal(sda_enable, '0');

        check_equal(success, '1');
        check_equal(fail, '0');

      elsif run("read") then
        address <= "1100011";
        check_equal(success, '0');
        check_equal(fail, '0');

        trigger_start := '1';
        wait until falling_edge(start);
        sda <= '1';
        trigger_scl_pulse := '1';
        wait until rising_edge(triggered_scl_pulse);

        sda <= '1';
        trigger_scl_pulse := '1';
        wait until rising_edge(triggered_scl_pulse);

        sda <= '0';
        trigger_scl_pulse := '1';
        wait until rising_edge(triggered_scl_pulse);

        sda <= '0';
        trigger_scl_pulse := '1';
        wait until rising_edge(triggered_scl_pulse);

        sda <= '0';
        trigger_scl_pulse := '1';
        wait until rising_edge(triggered_scl_pulse);

        sda <= '1';
        trigger_scl_pulse := '1';
        wait until rising_edge(triggered_scl_pulse);

        sda <= '1';
        trigger_scl_pulse := '1';
        wait until rising_edge(triggered_scl_pulse);

        sda <= '1'; -- rw
        trigger_scl_pulse := '1';
        wait until rising_edge(triggered_scl_pulse);

        check_equal(sda_enable, '1');   -- ack
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);


        check_equal(success, '1');
        check_equal(fail, '0');
        check_equal(rw, '1');
      elsif run("write") then
        address <= "1100011";
        check_equal(success, '0');
        check_equal(fail, '0');

        trigger_start := '1';
        wait until falling_edge(start);
        sda <= '1';
        trigger_scl_pulse := '1';
        wait until rising_edge(triggered_scl_pulse);

        sda <= '1';
        trigger_scl_pulse := '1';
        wait until rising_edge(triggered_scl_pulse);

        sda <= '0';
        trigger_scl_pulse := '1';
        wait until rising_edge(triggered_scl_pulse);

        sda <= '0';
        trigger_scl_pulse := '1';
        wait until rising_edge(triggered_scl_pulse);

        sda <= '0';
        trigger_scl_pulse := '1';
        wait until rising_edge(triggered_scl_pulse);

        sda <= '1';
        trigger_scl_pulse := '1';
        wait until rising_edge(triggered_scl_pulse);

        sda <= '1';
        trigger_scl_pulse := '1';
        wait until rising_edge(triggered_scl_pulse);

        sda <= '0'; -- rw
        trigger_scl_pulse := '1';
        wait until rising_edge(triggered_scl_pulse);


        check_equal(sda_enable, '1');   -- ack
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);


        check_equal(success, '1');
        check_equal(fail, '0');
        check_equal(rw, '0');
      elsif run("not_matching") then
        address <= "1110011";
        check_equal(success, '0');
        check_equal(fail, '0');

        trigger_start := '1';
        wait until falling_edge(start);
        sda <= '1';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);

        sda <= '1';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);

        sda <= '0';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);

        sda <= '0';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '1');
        wait until rising_edge(triggered_scl_pulse);

        sda <= '0';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '1');
        wait until rising_edge(triggered_scl_pulse);

        sda <= '1';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '1');
        wait until rising_edge(triggered_scl_pulse);

        sda <= '1';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '1');
        wait until rising_edge(triggered_scl_pulse);

        sda <= '1'; -- rw
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '1');
        wait until rising_edge(triggered_scl_pulse);


        check_equal(success, '0');
        check_equal(fail, '1');
      elsif run("not_matching_then_matching") then
        address <= "1110011";
        check_equal(success, '0');
        check_equal(fail, '0');

        trigger_start := '1';
        wait until falling_edge(start);
        sda <= '1';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);

        sda <= '1';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);

        sda <= '0';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);

        sda <= '0';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '1');
        wait until rising_edge(triggered_scl_pulse);

        sda <= '0';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '1');
        wait until rising_edge(triggered_scl_pulse);

        sda <= '1';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '1');
        wait until rising_edge(triggered_scl_pulse);

        sda <= '1';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '1');
        wait until rising_edge(triggered_scl_pulse);

        sda <= '1'; -- rw
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '1');
        wait until rising_edge(triggered_scl_pulse);


        check_equal(success, '0');
        check_equal(fail, '1');

        wait until falling_edge(clk);

        trigger_start := '1';

        address <= "1100011";
        check_equal(success, '0');
        check_equal(fail, '1');

        trigger_start := '1';
        wait until falling_edge(start);

        sda <= '1';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);


        sda <= '1';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);


        sda <= '0';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);

        sda <= '0';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);

        sda <= '0';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);

        sda <= '1';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);

        sda <= '1';
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);

        sda <= 'X'; -- rw
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);

        check_equal(sda_enable, '1');   -- ack
        trigger_scl_pulse := '1';
        check_equal(success, '0');
        check_equal(fail, '0');
        wait until rising_edge(triggered_scl_pulse);

        check_equal(success, '1');
        check_equal(fail, '0');
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process main;

  stability_check: check_stable(clk, one, scl_pulse, scl_falling_pulse, sda_enable);
end architecture tb;
