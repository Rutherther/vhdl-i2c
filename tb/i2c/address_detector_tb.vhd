library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

use work.i2c_bus_pkg;

library i2c;

entity address_detector_tb is

  generic (
    runner_cfg : string);

end entity address_detector_tb;

architecture tb of address_detector_tb is
  signal clk : std_logic := '0';
  constant CLK_PERIOD : time := 1 us;
  constant SCL_FREQ : real := 100_000.0;

  signal rst_n : std_logic := '0';

  signal dev_sda : std_logic;
  signal scl_rising, scl_falling : std_logic := '0';

  signal scl : std_logic;
  signal sda : std_logic;

  signal start : std_logic;

  signal address : std_logic_vector(6 downto 0);
  signal success, fail, rw : std_logic;

  signal sda_enable : std_logic;

  signal one : std_logic := '1';

  constant bus_inst_name : string := "i2c_bus_mod";
  constant bus_actor : actor_t := i2c_bus_pkg.get_actor(bus_inst_name);

  constant monitor_inst_name : string := "monitor";
  constant monitor_actor : actor_t := i2c_bus_pkg.get_actor(monitor_inst_name);
begin  -- architecture tb

  clk <= not clk after CLK_PERIOD / 2;
  rst_n <= '1' after 2 * CLK_PERIOD;

  sda <= 'H';
  scl <= 'H';

  sda <= '0' when sda_enable = '1' else 'Z';

  dev_sda <= '1' when sda = 'H' else sda;

  uut : entity i2c.address_detector
    port map (
      clk_i                 => clk,
      rst_in                => rst_n,
      store_address_i       => '1',
      address_i             => address,
      scl_rising            => scl_rising,
      scl_falling_delayed_i => scl_falling,
      sda_i                 => dev_sda,
      sda_enable_o          => sda_enable,
      start_i               => start,
      rw_o                  => rw,
      success_o             => success,
      fail_o                => fail);

  bus_mod : entity work.i2c_bus_mod
    generic map (
      inst_name        => bus_inst_name,
      default_scl_freq => SCL_FREQ)
    port map (
      sda_io        => sda,
      scl_io        => scl,

      clk_i         => clk,
      scl_falling_o => scl_falling,
      scl_rising_o  => scl_rising);

  -- monitor_mod : entity work.i2c_bus_mod
  --   generic map (
  --     inst_name        => monitor_inst_name,
  --     default_scl_freq => SCL_FREQ)
  --   port map (
  --     sda_io        => sda,
  --     scl_io        => scl,

  --     clk_i         => '0',
  --     scl_falling_o => open,
  --     scl_rising_o  => open);

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

        i2c_bus_pkg.gen_start_cond(net, 1 ms, bus_actor);
        i2c_bus_pkg.send_data_and_clock(net, "11000110", 1 ms, bus_actor);
        i2c_bus_pkg.check_ack_gen_clock(net, '1', 1 ms, bus_actor);

        start <= '1';
        wait until falling_edge(clk);
        start <= '0';

        i2c_bus_pkg.wait_until_idle(net, bus_actor);

        check_equal(success, '1');
        check_equal(fail, '0');

        i2c_bus_pkg.gen_stop_cond(net, 1 ms, bus_actor);
        i2c_bus_pkg.wait_until_idle(net, bus_actor);

      elsif run("read") then
        address <= "1100011";
        check_equal(success, '0');
        check_equal(fail, '0');

        i2c_bus_pkg.gen_start_cond(net, 1 ms, bus_actor);
        i2c_bus_pkg.send_data_and_clock(net, "11000111", 1 ms, bus_actor);
        i2c_bus_pkg.check_ack_gen_clock(net, '1', 1 ms, bus_actor);

        start <= '1';
        wait until falling_edge(clk);
        start <= '0';

        i2c_bus_pkg.wait_until_idle(net, bus_actor);

        check_equal(success, '1');
        check_equal(fail, '0');
        check_equal(rw, '1');
      elsif run("write") then
        address <= "1100011";
        check_equal(success, '0');
        check_equal(fail, '0');

        i2c_bus_pkg.gen_start_cond(net, 1 ms, bus_actor);
        i2c_bus_pkg.send_data_and_clock(net, "11000110", 1 ms, bus_actor);
        i2c_bus_pkg.check_ack_gen_clock(net, '1', 1 ms, bus_actor);

        start <= '1';
        wait until falling_edge(clk);
        start <= '0';

        i2c_bus_pkg.wait_until_idle(net, bus_actor);

        check_equal(success, '1');
        check_equal(fail, '0');
        check_equal(rw, '0');
      elsif run("not_matching") then
        address <= "1100011";
        check_equal(success, '0');
        check_equal(fail, '0');

        i2c_bus_pkg.gen_start_cond(net, 1 ms, bus_actor);
        i2c_bus_pkg.send_data_and_clock(net, "11100011", 1 ms, bus_actor);
        i2c_bus_pkg.check_ack_gen_clock(net, '0', 1 ms, bus_actor);

        start <= '1';
        wait until falling_edge(clk);
        start <= '0';

        i2c_bus_pkg.wait_until_idle(net, bus_actor);

        check_equal(success, '0');
        check_equal(fail, '1');
      elsif run("not_matching_then_matching") then
        address <= "1100011";
        check_equal(success, '0');
        check_equal(fail, '0');

        i2c_bus_pkg.gen_start_cond(net, 1 ms, bus_actor);
        i2c_bus_pkg.send_data_and_clock(net, "11100011", 1 ms, bus_actor);
        i2c_bus_pkg.check_ack_gen_clock(net, '0', 1 ms, bus_actor);
        i2c_bus_pkg.gen_stop_cond(net, 1 ms, bus_actor);

        start <= '1';
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        start <= '0';

        i2c_bus_pkg.wait_until_idle(net, bus_actor);

        check_equal(success, '0');
        check_equal(fail, '1');

        i2c_bus_pkg.gen_start_cond(net, 1 ms, bus_actor);
        i2c_bus_pkg.send_data_and_clock(net, "11000110", 1 ms, bus_actor);
        i2c_bus_pkg.check_ack_gen_clock(net, '1', 1 ms, bus_actor);
        i2c_bus_pkg.gen_stop_cond(net, 1 ms, bus_actor);

        start <= '1';
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        start <= '0';

        i2c_bus_pkg.wait_until_idle(net, bus_actor);

        check_equal(success, '1');
        check_equal(fail, '0');
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process main;

  test_runner_watchdog(runner, 10 ms);
end architecture tb;
