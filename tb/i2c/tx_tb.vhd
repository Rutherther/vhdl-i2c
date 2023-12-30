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

  signal sda : std_logic;
  signal sda_override : std_logic := '0';
  signal sda_enable, scl : std_logic := '0';
  signal scl_rising_pulse, scl_falling_pulse : std_logic := '0';

  signal start_write : std_logic := '0';
  signal valid, ready : std_logic := '0';
  signal write_data : std_logic_vector(7 downto 0);
  signal scl_stretch : std_logic;

  signal err_noack : std_logic;

  signal validate_sda_stable_when_scl_high : std_logic := '0';
  signal check_noerr : std_logic := '0';
  signal zero : std_logic := '0';

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
    constant trigger_ack : in std_logic;
    signal sda_override : inout std_logic;
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
      check_equal(sda_enable, not data(i));

      if check_ready /= 'Z' then
        check_equal(ready, check_ready);
      end if;

      check(scl_stretch = '0', "Cannot send when stretch is active", failure);

      trigger_scl_pulse(scl, scl_rising_pulse, scl_falling_pulse);
    end loop;  -- i

    -- ack
    if trigger_ack = '1' then
      sda_override <= '1';
    end if;

    trigger_scl_pulse(scl, scl_rising_pulse, scl_falling_pulse);

    if trigger_ack = '1' then
      sda_override <= '0';
    end if;
  end procedure check_received_data;

begin  -- architecture a1
  uut : entity i2c.tx
    port map (
      clk_i                 => clk,
      rst_in                => rst_n,
      start_write_i         => start_write,
      ss_condition_i        => '0',
      expect_ack_i          => '1',
      err_noack_o           => err_noack,
      scl_stretch_o         => scl_stretch,
      scl_rising_pulse_i    => scl_rising_pulse,
      scl_falling_delayed_i => scl_falling_pulse,
      sda_enable_o          => sda_enable,
      sda_i                 => sda,
      ready_o               => ready,
      valid_i               => valid,
      write_data_i          => write_data);

  clk <= not clk after CLK_PERIOD / 2;
  rst_n <= '1' after 2 * CLK_PERIOD;

  sda <= '0' when sda_override = '1' else
         not sda_enable;

  main: process is
  begin  -- process
    scl <= '1';
    wait until rst_n = '1';
    wait until falling_edge(clk);
    check_noerr <= '1';
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
        check_received_data("11010100", '1', '1', sda_override, scl, scl_rising_pulse, scl_falling_pulse);
        check_equal(sda_enable, '0');
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

        check_received_data("11010100", '0', '1', sda_override, scl, scl_rising_pulse, scl_falling_pulse);
        wait until falling_edge(clk);
        check_received_data("00101011", '1', '1', sda_override, scl, scl_rising_pulse, scl_falling_pulse);
        check_equal(sda_enable, '0');
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

        check_received_data("11010100", '0', '1', sda_override,  scl, scl_rising_pulse, scl_falling_pulse);
        wait until falling_edge(clk);
        check_equal(ready, '1');
        write_data <= "00001111";
        valid <= '1';
        wait until falling_edge(clk);
        valid <= '0';
        check_received_data("00101011", '0', '1', sda_override,  scl, scl_rising_pulse, scl_falling_pulse);
        check_received_data("00001111", '1', '1', sda_override,  scl, scl_rising_pulse, scl_falling_pulse);
        check_equal(sda_enable, '0');
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
        check_received_data("11001100", '1', '1', sda_override,  scl, scl_rising_pulse, scl_falling_pulse);
      elsif run("no_ack") then
        valid <= '1';
        write_data <= "11010100";
        check_equal(ready, '1');
        start_write <= '1';
        wait until falling_edge(clk);
        valid <= '0';
        check_noerr <= '0'; -- disable no err check
        check_received_data("11010100", '1', '0', sda_override, scl, scl_rising_pulse, scl_falling_pulse);
        check_equal(err_noack, '1');
        check_equal(sda_enable, '0');
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

  no_err: check_stable(clk, check_noerr, check_noerr, zero, err_noack);
  stability_check: check_stable(clk, validate_sda_stable_when_scl_high, scl_rising_pulse, scl_falling_pulse, sda_enable);
end architecture a1;
