library ieee;
use ieee.std_logic_1164.all;

library i2c;

library vunit_lib;
context vunit_lib.vunit_context;

entity tx_tb is

  generic (
    runner_cfg : string);

end entity tx_tb;

architecture a1 of tx_tb is
  signal clk : std_logic := '0';
  constant CLK_PERIOD : time := 10 ns;

  signal rst_n : std_logic := '0';

  signal sda, scl : std_logic := '0';
  signal scl_rising_pulse, scl_falling_pulse : std_logic := '0';

  signal start_write : std_logic := '0';
  signal valid, ready : std_logic := '0';
  signal write_data : std_logic_vector(7 downto 0);
  signal scl_stretch : std_logic;

  signal validate_sda_stable_when_scl_high : std_logic := '0';

  procedure trigger_scl_pulse(
    signal scl : inout std_logic;
    signal scl_rising_pulse : inout std_logic;
    signal scl_falling_pulse : inout std_logic) is
  begin  -- procedure trigger_scl_pulse
    scl_falling_pulse <= scl;
    scl_rising_pulse <= '0';
    scl <= '0';
    wait until falling_edge(clk);
    scl <= '1';
    scl_falling_pulse <= '0';
    scl_rising_pulse <= '1';
    wait until falling_edge(clk);
    scl_rising_pulse <= '0';
    wait until falling_edge(clk);
    scl <= '0';
    scl_falling_pulse <= '1';
    wait until falling_edge(clk);
    scl_rising_pulse <= '0';
    scl_falling_pulse <= '0';
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    wait until falling_edge(clk);
  end procedure trigger_scl_pulse;

  procedure trigger_scl_rise(
    signal scl : inout std_logic;
    signal scl_rising_pulse : inout std_logic;
    signal scl_falling_pulse : inout std_logic) is
  begin  -- procedure trigger_scl_pulse
    check_equal(scl, '0');
    wait until falling_edge(clk);
    scl <= '1';
    scl_rising_pulse <= '1';
    scl_falling_pulse <= '0';
    wait until falling_edge(clk);
    scl_rising_pulse <= '0';
    scl_falling_pulse <= '0';
  end procedure trigger_scl_rise;

  procedure check_received_data (
    constant data : in std_logic_vector(7 downto 0);
    constant check_ready : in std_logic;
    signal scl : inout std_logic;
    signal scl_rising_pulse : inout std_logic;
    signal scl_falling_pulse : inout std_logic) is
  begin
    check(scl_stretch = '0', "Cannot send when stretch is active", failure);
    wait until falling_edge(clk);

    if scl = '1' then
      scl <= '0';
      scl_falling_pulse <= '1';
      scl_rising_pulse <= '0';
      wait until falling_edge(clk);
      scl_falling_pulse <= '0';
      scl_rising_pulse <= '0';
    end if;

    for i in 7 downto 0 loop
      check_equal(sda, data(i));

      if check_ready /= 'Z' then
        check_equal(ready, check_ready);
      end if;

      check(scl_stretch = '0', "Cannot send when stretch is active", failure);

      trigger_scl_pulse(scl, scl_rising_pulse, scl_falling_pulse);
    end loop;  -- i
  end procedure check_received_data;

begin  -- architecture a1
  uut : entity i2c.tx
    generic map (
      DELAY_SDA_FOR => 1)
    port map (
      clk_i          => clk,
      rst_in         => rst_n,
      start_write_i => start_write,
      ss_condition_i => '0',
      scl_stretch_o  => scl_stretch,
      scl_rising_pulse_i => scl_rising_pulse,
      scl_falling_pulse_i => scl_falling_pulse,
      sda_o => sda,
      ready_o => ready,
      valid_i => valid,
      write_data_i => write_data);

  clk <= not clk after CLK_PERIOD / 2;
  rst_n <= '1' after 2 * CLK_PERIOD;

  main: process is
  begin  -- process
    scl <= '1';
    wait until rst_n = '1';
    wait until falling_edge(clk);
    test_runner_setup(runner, runner_cfg);
    set_stop_level(failure);


    while test_suite loop
      if run("simple") then
        valid <= '1';
        write_data <= "11010100";
        check_equal(ready, '1');
        start_write <= '1';
        wait until falling_edge(clk);
        valid <= '0';
        check_received_data("11010100", '1', scl, scl_rising_pulse, scl_falling_pulse);
        check_equal(sda, '1');
      elsif run("twice") then
        valid <= '1';
        write_data <= "11010100";
        check_equal(ready, '1');
        start_write <= '1';
        wait until falling_edge(clk);
        write_data <= "00101011";
        check_equal(ready, '1');
        wait until falling_edge(clk);
        valid <= '0';
        check_equal(ready, '0');

        check_received_data("11010100", '0', scl, scl_rising_pulse, scl_falling_pulse);
        wait until falling_edge(clk);
        check_received_data("00101011", '1', scl, scl_rising_pulse, scl_falling_pulse);
        check_equal(sda, '1');
      elsif run("three") then
        valid <= '1';
        write_data <= "11010100";
        check_equal(ready, '1');
        start_write <= '1';
        wait until falling_edge(clk);
        write_data <= "00101011";
        check_equal(ready, '1');
        wait until falling_edge(clk);
        valid <= '0';
        check_equal(ready, '0');

        check_received_data("11010100", '0', scl, scl_rising_pulse, scl_falling_pulse);
        wait until falling_edge(clk);
        check_equal(ready, '1');
        write_data <= "00001111";
        valid <= '1';
        wait until falling_edge(clk);
        valid <= '0';
        check_received_data("00101011", '0', scl, scl_rising_pulse, scl_falling_pulse);
        check_received_data("00001111", '1', scl, scl_rising_pulse, scl_falling_pulse);
        check_equal(sda, '1');
      elsif run("stretching") then
        start_write <= '1';
        check_equal(scl_stretch, '0');
        wait until falling_edge(clk);
        for i in 0 to 5 loop
            check_equal(scl_stretch, '1');
            wait until falling_edge(clk);
        end loop;  -- i

        valid <= '1';
        write_data <= "11001100";
        wait until falling_edge(clk);
        valid <= '0';
        check_equal(scl_stretch, '0');
        check_received_data("11001100", '1', scl, scl_rising_pulse, scl_falling_pulse);
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

  stability_check: check_stable(clk, validate_sda_stable_when_scl_high, scl_rising_pulse, scl_falling_pulse, sda);
end architecture a1;
