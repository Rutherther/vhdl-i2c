library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
-- use vunit_lib.check_pkg.all;
context vunit_lib.vunit_context;

use work.tb_pkg.all;
use work.tb_i2c_pkg.all;

package tb_i2c_slave_pkg is

  procedure i2c_slave_check_start (
    constant address : in std_logic_vector(6 downto 0);
    constant rw : in std_logic;
    constant timeout : in time;
    signal scl : inout std_logic;
    signal sda : inout std_logic;
    constant ack : in std_logic := '1');

  procedure i2c_slave_check_stop (
    constant timeout : in time;
    signal scl : inout std_logic;
    signal sda : inout std_logic);

  procedure i2c_slave_transmit (
    constant data        : in    std_logic_vector(7 downto 0);
    constant scl_timeout : in    time;
    signal scl           : inout std_logic;
    signal sda           : inout std_logic;
    constant exp_ack     : in    std_logic := '1');

  procedure i2c_slave_receive (
    constant exp_data       : in    std_logic_vector(7 downto 0);
    constant scl_timeout    : in    time;
    signal scl              : inout std_logic;
    signal sda              : inout std_logic;
    constant ack            : in    std_logic := '1');

end package tb_i2c_slave_pkg;

package body tb_i2c_slave_pkg is

  procedure i2c_slave_check_start (
    constant address : in std_logic_vector(6 downto 0);
    constant rw : in std_logic;
    constant timeout : in time;
    signal scl : inout std_logic;
    signal sda : inout std_logic;
    constant ack : in std_logic := '1') is
    begin
      wait_for_start_condition(timeout, scl, sda);
      i2c_slave_receive(address & rw, timeout, scl, sda, ack);
    end procedure i2c_slave_check_start;

  procedure i2c_slave_check_stop (
    constant timeout : in time;
    signal scl : inout std_logic;
    signal sda : inout std_logic) is
  begin
    wait_for_stop_condition(timeout, scl, sda);
  end procedure i2c_slave_check_stop;

  procedure i2c_slave_transmit (
    constant data        : in    std_logic_vector(7 downto 0);
    constant scl_timeout : in    time;
    signal scl           : inout std_logic;
    signal sda           : inout std_logic;
    constant exp_ack     : in    std_logic := '1') is

  begin  -- procedure transmit
    if scl = 'H' then
        wait_for_scl_fall(scl_timeout, scl);
    end if;

    -- data
    for i in 7 downto 0 loop
      wait until falling_edge(clk);
      sda <= '0' when data(i) = '0' else 'Z';
      wait_for_scl_rise(scl_timeout, scl);
      wait_for_scl_fall(scl_timeout, scl);
    end loop;  -- i

    wait until falling_edge(clk);
    sda <= 'Z';
    wait_for_scl_rise(scl_timeout, scl);

    if exp_ack = '1' then
      check_equal(sda, '0', "No acknowledge");
    elsif exp_ack = '0' then
      check_equal(sda, 'H', "There was acknowledge even though there shouldn't have been");
    end if;

    -- TODO consider removing this?
    wait_for_scl_fall(scl_timeout, scl);
    wait until falling_edge(clk);
    sda <= 'Z';
  end procedure i2c_slave_transmit;

  procedure i2c_slave_receive (
    constant exp_data       : in    std_logic_vector(7 downto 0);
    constant scl_timeout    : in    time;
    signal scl              : inout std_logic;
    signal sda              : inout std_logic;
    constant ack            : in    std_logic := '1') is

  begin  -- procedure transmit
    if scl = 'H' then
      wait_for_scl_fall(scl_timeout, scl);
    end if;

    sda <= 'Z';

    -- data
    for i in 7 downto 0 loop
      wait_for_scl_rise(scl_timeout, scl);
      if exp_data(i) = '1' then
        check(sda = '1' or sda = 'H', result("Received data (sda) not as expected."));
      else
        check(sda = '0' or sda = 'L', result("Received data (sda) not as expected."));
      end if;
      wait_for_scl_fall(scl_timeout, scl);
    end loop;  -- i

    if ack = '1' then
      sda <= '0';
    end if;

    wait_for_scl_rise(scl_timeout, scl);
    wait_for_scl_fall(scl_timeout, scl);

    sda <= 'Z';
  end procedure i2c_slave_receive;

end package body tb_i2c_slave_pkg;
