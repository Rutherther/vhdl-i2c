library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
-- use vunit_lib.check_pkg.all;
context vunit_lib.vunit_context;

use work.tb_pkg.all;
use work.tb_i2c_pkg.all;

package tb_i2c_master_pkg is

  procedure i2c_master_stop (
    signal scl_override : inout std_logic;
    signal sda_override : inout std_logic);

  procedure i2c_master_transmit (
    constant data   : in    std_logic_vector(7 downto 0);
    signal scl_override : inout std_logic;
    signal sda_override : inout std_logic;
    constant stop_condition : in std_logic := '0';
    constant exp_ack : in std_logic := '1');

  procedure i2c_master_receive (
    constant exp_data       : in    std_logic_vector(7 downto 0);
    signal scl_override     : inout std_logic;
    signal sda_override     : inout std_logic;
    constant ack            : in    std_logic := '1';
    constant stop_condition : in    std_logic := '0');

  procedure i2c_master_start (
    constant address    : in    std_logic_vector(6 downto 0);
    constant rw         : in    std_logic;
    signal scl_override : inout std_logic;
    signal sda_override : inout std_logic;
    constant exp_ack    : in    std_logic := '1');

end package tb_i2c_master_pkg;

package body tb_i2c_master_pkg is

  procedure i2c_master_stop (
    signal scl_override : inout std_logic;
    signal sda_override : inout std_logic) is
  begin  -- procedure stop_tx

    scl_fall(scl_override);
    sda_fall(sda_override);
    scl_rise(scl_override);

    -- stop condition
    sda_rise(sda_override, '0');

  end procedure i2c_master_stop;

  procedure i2c_master_transmit (
    constant data   : in    std_logic_vector(7 downto 0);
    signal scl_override : inout std_logic;
    signal sda_override : inout std_logic;
    constant stop_condition : in std_logic := '0';
    constant exp_ack : in std_logic := '1') is

  begin  -- procedure transmit
    check_equal(scl_override, '0', "Cannot start sending when scl is not in default state (1).", failure);
    check_equal(scl, '1', "Cannot start sending when scl is not in default state (1). Seems like the slave is clock stretching. This is not supported by transmit since data have to be supplied or read.", failure);

    scl_fall(scl_override);

    -- data
    for i in 7 downto 0 loop
      sda_override <= not data(i);
      scl_pulse(scl_override);
    end loop;  -- i

    sda_override <= '0';
    scl_rise(scl_override);
    if exp_ack = '1' then
      check_equal(sda, '0', "No acknowledge");
    elsif exp_ack = '0' then
      check_equal(sda, '1', "There was acknowledge even though there shouldn't have been");
    end if;

    if stop_condition = '1' then
      if sda = '0' then
        -- keep sda low
        sda_override <= '1';
      end if;

      i2c_master_stop(scl_override, sda_override);

    end if;
  end procedure i2c_master_transmit;

  procedure i2c_master_receive (
    constant exp_data       : in    std_logic_vector(7 downto 0);
    signal scl_override     : inout std_logic;
    signal sda_override     : inout std_logic;
    constant ack            : in    std_logic := '1';
    constant stop_condition : in    std_logic := '0') is

  begin  -- procedure transmit
    check_equal(scl_override, '0', "Cannot start receiving when scl is not in default state (1).", failure);
    check_equal(scl, '1', "Cannot start receiving when scl is not in default state (1). Seems like the slave is clock stretching. This is not supported by transmit since data have to be supplied or read.", failure);

    scl_fall(scl_override);
    sda_override <= '0';

    -- data
    for i in 7 downto 0 loop
      scl_rise(scl_override);
      check_equal(sda, exp_data(i), "Received data (sda) not as expected");
      scl_fall(scl_override);
    end loop;  -- i

    if ack = '1' then
      sda_override <= '1';
    end if;

    scl_rise(scl_override);

    if stop_condition = '1' then
      if sda = '0' then
        -- keep sda low
        sda_override <= '1';
      end if;

      i2c_master_stop(scl_override, sda_override);

    end if;
  end procedure i2c_master_receive;

  procedure i2c_master_start (
    constant address : in    std_logic_vector(6 downto 0);
    constant rw      : in    std_logic;
    signal scl_override : inout std_logic;
    signal sda_override : inout std_logic;
    constant exp_ack : in std_logic := '1') is
  begin
    if scl = '1' and sda = '0' then
      scl_fall(scl_override);
    end if;

    if sda = '0' then
      sda_rise(sda_override);
    end if;

    if scl = '0' then
      scl_rise(scl_override);
    end if;

    check_equal(sda, '1', "Cannot start sending when sda is not in default state (1).", failure);
    check_equal(scl, '1', "Cannot start sending when scl is not in default state (1).", failure);

    -- start condition
    sda_fall(sda_override, '0');

    i2c_master_transmit(address & rw, scl_override, sda_override, stop_condition => '0', exp_ack => exp_ack);

  end procedure i2c_master_start;

end package body tb_i2c_master_pkg;
