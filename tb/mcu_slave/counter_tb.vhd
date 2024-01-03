library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library mcu_slave;

library utils;

library i2c_tb;
use i2c_tb.tb_pkg.all;
use i2c_tb.tb_i2c_pkg.all;
use i2c_tb.tb_i2c_master_pkg.all;

entity counter_tb is

  generic (
    runner_cfg : string);

end entity counter_tb;

architecture tb of counter_tb is
  constant ADDRESS : std_logic_vector(6 downto 0) := "1110100";
  constant CLK_PERIOD : time := 10 ns;
  signal rst_n : std_logic := '0';
  signal rst : std_logic;

  signal not_scl : std_logic;

  signal err_noack          : std_logic;
  signal bus_busy, dev_busy : std_logic;

  signal one : std_logic := '1';
begin  -- architecture tb
  uut : entity mcu_slave.counter
    generic map (
      DELAY => 1)
    port map (
      clk_i       => clk,
      rst_i       => rst,
      rst_on      => open,
      err_noack_o => err_noack,
      dev_busy_o  => dev_busy,
      bus_busy_o  => bus_busy,
      sda_io      => sda,
      scl_io      => scl
    );

  -- pull up
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
      if run("wrapping_counting") then
        i2c_master_start(ADDRESS, '1', scl, sda);

        for i in 0 to 99 loop
          i2c_master_receive(std_logic_vector(to_unsigned(i, 8)), scl, sda);
        end loop;  -- i

        -- starting over
        i2c_master_receive("00000000", scl, sda);
        i2c_master_receive("00000001", scl, sda);

        i2c_master_stop(scl, sda);
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process main;

end architecture tb;
