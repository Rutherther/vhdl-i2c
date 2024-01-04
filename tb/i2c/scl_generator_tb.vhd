library ieee;
use ieee.std_logic_1164.all;

library i2c;

library vunit_lib;
context vunit_lib.vunit_context;

entity scl_generator_tb is

  generic (
    runner_cfg : string);

end entity scl_generator_tb;

architecture tb of scl_generator_tb is
  signal clk : std_logic := '0';
  constant CLK_PERIOD : time := 10 ns;

  signal rst_n : std_logic := '0';

  signal scl : std_logic := 'H';
  signal slave_scl : std_logic;
  signal scl_rising : std_logic := '0';
  signal scl_falling : std_logic := '0';

  signal scl_enable : std_logic := '0';
  signal gen_continuous, gen_rising, gen_falling : std_logic := '0';
  signal cannot_comply : std_logic;

  signal stable_cannot_comply : std_logic := '1';

  constant DELAY : natural := 5;
  signal one : std_logic := '1';
  signal zero : std_logic := '0';
begin  -- architecture tb

  clk <= not clk after CLK_PERIOD/2;
  rst_n <= '1' after 2*CLK_PERIOD;

  scl <= 'H';
  scl <= '0' when scl_enable = '1' else 'Z';

  slave_scl <= '1' when scl = 'H' else 'Z';
  slave_scl <= scl;

  cannot_comply_stable: check_stable(clk, stable_cannot_comply, one, zero, cannot_comply);

  uut: entity i2c.scl_generator
    generic map (
      MIN_STABLE_CYCLES => DELAY)
    port map (
      clk_i            => clk,
      rst_in           => rst_n,
      scl_i            => slave_scl,
      scl_rising_i     => scl_rising,
      scl_falling_i    => scl_falling,
      gen_continuous_i => gen_continuous,
      gen_rising_i     => gen_rising,
      gen_falling_i    => gen_falling,
      scl_enable_o     => scl_enable,
      cannot_comply_o  => cannot_comply);

  main: process is
    procedure wait_delay(constant delay : in integer) is
    begin  -- procedure wait_delay
      for i in 0 to delay loop
        wait until falling_edge(clk);
      end loop;  -- i
      wait until falling_edge(clk);
    end procedure wait_delay;

    procedure req_clear is
    begin  -- procedure req_rising
      gen_falling <= '0';
      gen_continuous <= '0';
      gen_rising <= '0';
    end procedure req_clear;

    procedure req_rising is
    begin  -- procedure req_rising
      req_clear;
      gen_rising <= '1';
    end procedure req_rising;

    procedure req_falling is
    begin  -- procedure req_falling
      req_clear;
      gen_falling <= '1';
    end procedure req_falling;

    procedure req_continuous is
    begin  -- procedure req_
      req_clear;
      gen_continuous <= '1';
    end procedure req_continuous;
  begin  -- process main
    wait until rst_n = '1';
    wait until falling_edge(clk);

    check_equal(scl, 'H', "begin SCL not high");

    test_runner_setup(runner, runner_cfg);

    while test_suite loop
        if run("continuous") then
        req_continuous;

        for i in 0 to 10 loop
            wait_delay(DELAY);
            check_equal(scl, '0');
            wait_delay(DELAY);
            check_equal(scl, 'H');
        end loop;  -- i
        elsif run("falling") then
          req_falling;
          wait_delay(DELAY);

          check_equal(scl, '0');
          req_clear;

          for i in 0 to 10 loop
            check_equal(scl, '0');
          end loop;  -- i
        elsif run("falling_rising") then
          req_falling;
          wait_delay(DELAY);

          check_equal(scl, '0');
          req_rising;
          wait_delay(DELAY);
          req_clear;

          for i in 0 to 10 loop
            check_equal(scl, 'H');
          end loop;  -- i
        elsif run("rising_scl_low") then
          scl <= '0'; -- pull down
          req_rising;

          stable_cannot_comply <= '0';
          wait_delay(1);
          check_equal(cannot_comply, '1');
        elsif run("falling_rising_scl_low") then
          req_falling;
          wait_delay(DELAY);
          scl <= '0'; -- pull down
          req_rising;

          stable_cannot_comply <= '0';
          wait_delay(DELAY);
          check_equal(cannot_comply, '1');
          check_equal(scl_enable, '0');
        end if;
    end loop;

    test_runner_cleanup(runner);
  end process main;

  set_scl_rising: process is
  begin  -- process scl_rising
    wait until rising_edge(scl);
    scl_rising <= '1';
    wait until falling_edge(clk);
    scl_rising <= '0';
  end process set_scl_rising;

  set_scl_falling: process is
  begin  -- process scl_rising
    wait until falling_edge(scl);
    scl_falling <= '1';
    wait until falling_edge(clk);
    scl_falling <= '0';
  end process set_scl_falling;

end architecture tb;
