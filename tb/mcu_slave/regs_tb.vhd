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

entity regs_tb is

  generic (
    runner_cfg : string);

end entity regs_tb;

architecture tb of regs_tb is
  constant ADDRESS : std_logic_vector(6 downto 0) := "1110101";
  constant CLK_PERIOD : time := 10 ns;
  constant REGS_COUNT : integer := 20;

  signal rst_n : std_logic := '0';
  signal rst : std_logic;

  signal not_scl : std_logic;

  signal err_noack          : std_logic;
  signal bus_busy, dev_busy : std_logic;

  signal one : std_logic := '1';
begin  -- architecture tb
  uut : entity mcu_slave.regs
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

  sda <= 'H';
  scl <= 'H';

  not_scl <= not scl;

  clk <= not clk after CLK_PERIOD / 2;
  rst_n <= '1' after 2 * CLK_PERIOD;
  rst <= not rst_n;

  -- TODO: allow conditions from master...
  -- sda_stability_check: check_stable(clk, one, scl, not_scl, sda);

  main: process is
  begin  -- process main
    wait until rst_n = '1';
    wait until falling_edge(clk);
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("write_all_ones_read") then
        i2c_master_start(ADDRESS, '0', scl, sda);

        -- seek address 0
        i2c_master_transmit("00000000", scl, sda);
        for i in 0 to REGS_COUNT - 1 loop
          i2c_master_transmit("00000001", scl, sda);
        end loop;  -- i

        i2c_master_start(ADDRESS, '1', scl, sda);
        for i in 0 to REGS_COUNT - 1 loop
          i2c_master_receive("00000001", scl, sda);
        end loop;  -- i

        i2c_master_stop(scl, sda);
      elsif run("write_sequence_read") then
        i2c_master_start(ADDRESS, '0', scl, sda);

        i2c_master_transmit("00000000", scl, sda);
        for i in 0 to REGS_COUNT - 1 loop
          i2c_master_transmit(std_logic_vector(to_unsigned(i, 8)), scl, sda);
        end loop;  -- i

        i2c_master_stop(scl, sda);

        i2c_master_start(ADDRESS, '0', scl, sda);
        -- seek address 0
        i2c_master_transmit("00000000", scl, sda);
        i2c_master_start(ADDRESS, '1', scl, sda);

        for i in 0 to REGS_COUNT - 1 loop
          i2c_master_receive(std_logic_vector(to_unsigned(i, 8)), scl, sda);
        end loop;  -- i

        i2c_master_stop(scl, sda);
      elsif run("write_five_read_all") then
        i2c_master_start(ADDRESS, '0', scl, sda);

        -- seek address 5
        i2c_master_transmit("00000101", scl, sda);

        for i in 0 to 4 loop
          i2c_master_transmit(std_logic_vector(to_unsigned(i, 8)), scl, sda);
        end loop;  -- i

        i2c_master_stop(scl, sda);

        i2c_master_start(ADDRESS, '0', scl, sda);
        -- seek address 0
        i2c_master_transmit("00000000", scl, sda);
        i2c_master_start(ADDRESS, '1', scl, sda);

        for i in 0 to 4 loop
          i2c_master_receive("00000000", scl, sda);
        end loop;  -- i

        for i in 0 to 4 loop
          i2c_master_receive(std_logic_vector(to_unsigned(i, 8)), scl, sda);
        end loop;  -- i

        for i in 10 to REGS_COUNT - 1 loop
          i2c_master_receive("00000000", scl, sda);
        end loop;  -- i

        i2c_master_stop(scl, sda);
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process main;

end architecture tb;
