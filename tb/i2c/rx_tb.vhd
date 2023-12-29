library ieee;
use ieee.std_logic_1164.all;

library i2c;

library vunit_lib;
context vunit_lib.vunit_context;

entity rx_tb is

  generic (
    runner_cfg : string);

end entity rx_tb;

architecture a1 of rx_tb is
  signal clk : std_logic := '0';
  constant CLK_PERIOD : time := 10 ns;

  signal rst_n : std_logic := '0';

  signal sda : std_logic := '0';
  signal scl_rising_pulse, scl_falling_pulse : std_logic := '0';

  signal start_read : std_logic := '0';
  signal valid, ready : std_logic;
  signal scl_stretch : std_logic;

  signal confirm_read : std_logic := '0';
  signal read_data : std_logic_vector(7 downto 0);

  procedure trigger_scl_pulse(
    signal scl_rising_pulse : inout std_logic;
    signal scl_falling_pulse : inout std_logic) is
  begin  -- procedure trigger_scl_pulse
    scl_rising_pulse <= '0';
    scl_falling_pulse <= '0';
    wait until falling_edge(clk);
    scl_rising_pulse <= '1';
    wait until falling_edge(clk);
    scl_rising_pulse <= '0';
    scl_falling_pulse <= '1';
    wait until falling_edge(clk);
    scl_rising_pulse <= '0';
    scl_falling_pulse <= '0';
  end procedure trigger_scl_pulse;

  procedure transmit (
    constant data            : in    std_logic_vector(7 downto 0);
    constant check_valid     : in    std_logic;
    constant check_ready     : in    std_logic;
    signal start_read        : inout std_logic;
    signal sda               : inout std_logic;
    signal scl_rising_pulse  : inout std_logic;
    signal scl_falling_pulse : inout std_logic) is
  begin  -- procedure a
    start_read <= '1';
    wait until falling_edge(clk);
    start_read <= '0';
    for i in 7 downto 0 loop
      if check_valid /= 'Z' then
        check_equal(valid, check_valid);
      end if;

      if check_ready /= 'Z' then
        check_equal(ready, check_ready);
      end if;

      check(scl_stretch = '0', "Cannot send when stretch is active", failure);

      sda <= data(i);
      trigger_scl_pulse(scl_rising_pulse, scl_falling_pulse);
    end loop;  -- i
  end procedure transmit;
begin  -- architecture a1
  uut : entity i2c.rx
    port map (
      clk_i          => clk,
      rst_in         => rst_n,
      start_read_i   => start_read,
      scl_pulse_i    => scl_rising_pulse,
      sda_i          => sda,
      scl_stretch_o  => scl_stretch,
      read_valid_o   => valid,
      read_ready_o   => ready,
      read_data_o    => read_data,
      confirm_read_i => confirm_read);

  clk <= not clk after CLK_PERIOD / 2;
  rst_n <= '1' after 2 * CLK_PERIOD;

  main: process is
  begin  -- process
    wait until rst_n = '1';
    wait until falling_edge(clk);
    test_runner_setup(runner, runner_cfg);
    set_stop_level(failure);

    while test_suite loop
      if run("simple") then
        transmit("11010100", '0', '1', start_read, sda, scl_rising_pulse, scl_falling_pulse);
        check_equal(valid, '1');
        check_equal(ready, '1');
        check_equal(scl_stretch, '0');
        check_equal(read_data, std_logic_vector'("11010100"));

        confirm_read <= '1';
        wait until falling_edge(clk);
        confirm_read <= '0';
        check_equal(valid, '0');
        check_equal(ready, '1');
      elsif run("twice") then
        transmit("11010100", '0', '1', start_read, sda, scl_rising_pulse, scl_falling_pulse);
        check_equal(valid, '1');
        check_equal(ready, '1');
        check_equal(scl_stretch, '0');
        check_equal(read_data, std_logic_vector'("11010100"));
        confirm_read <= '1';
        wait until falling_edge(clk);
        confirm_read <= '0';
        check_equal(valid, '0');
        check_equal(ready, '1');

        transmit("00111100", '0', '1', start_read, sda, scl_rising_pulse, scl_falling_pulse);
        check_equal(valid, '1');
        check_equal(ready, '1');
        check_equal(scl_stretch, '0');
        check_equal(read_data, std_logic_vector'("00111100"));
        confirm_read <= '1';
        wait until falling_edge(clk);
        confirm_read <= '0';
        check_equal(valid, '0');
        check_equal(ready, '1');
      elsif run("stretching") then
        transmit("11010100", '0', '1', start_read, sda, scl_rising_pulse, scl_falling_pulse);
        check_equal(valid, '1');
        check_equal(ready, '1');
        check_equal(scl_stretch, '0');
        check_equal(read_data, std_logic_vector'("11010100"));

        transmit("10000001", '1', '1', start_read, sda, scl_rising_pulse, scl_falling_pulse);
        check_equal(valid, '1');
        check_equal(ready, '0');
        check_equal(scl_stretch, '0');
        check_equal(read_data, std_logic_vector'("11010100"));

        start_read <= '1';
        wait until falling_edge(clk);
        start_read <= '0';

        check_equal(read_data, std_logic_vector'("11010100"));
        check_equal(valid, '1');
        check_equal(ready, '0');
        check_equal(scl_stretch, '1');

        for i in 0 to 5 loop
          wait until falling_edge(clk);
          check_equal(scl_stretch, '1');
        end loop;  -- i

        confirm_read <= '1';
        wait until falling_edge(clk);
        check_equal(read_data, std_logic_vector'("10000001"));
        check_equal(valid, '1');
        check_equal(ready, '1');
        check_equal(scl_stretch, '0');
        wait until falling_edge(clk);
        check_equal(valid, '0');
        check_equal(ready, '1');
        check_equal(scl_stretch, '0');

        transmit("00000011", '0', '1', start_read, sda, scl_rising_pulse, scl_falling_pulse);
        check_equal(read_data, std_logic_vector'("00000011"));
        check_equal(valid, '1');
        check_equal(ready, '1');
        check_equal(scl_stretch, '0');
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

end architecture a1;
