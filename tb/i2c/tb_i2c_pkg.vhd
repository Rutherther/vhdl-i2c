library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
-- use vunit_lib.check_pkg.all;
context vunit_lib.vunit_context;

use work.tb_pkg.all;

package tb_i2c_pkg is

  signal sda : std_logic;
  signal scl : std_logic;

  signal tx_ready : std_logic;
  signal rx_valid : std_logic;
  signal rx_data : std_logic_vector(7 downto 0);

  procedure scl_fall (
    signal scl_override : inout std_logic);

  procedure scl_rise (
    signal scl_override : inout std_logic);

  procedure scl_pulse (
    signal scl_override : inout std_logic);

  procedure sda_fall (
    signal sda_override : inout std_logic;
    constant assert_no_condition : in std_logic := '1');

  procedure sda_rise (
    signal sda_override : inout std_logic;
    constant assert_no_condition : in std_logic := '1');

  procedure tx_write_data (
    constant data   : in    std_logic_vector(7 downto 0);
    signal tx_data : inout std_logic_vector(7 downto 0);
    signal tx_valid : inout std_logic);

  procedure rx_read_data (
    constant exp_data : in std_logic_vector(7 downto 0);
    signal rx_confirm_read : inout std_logic);

end package tb_i2c_pkg;

package body tb_i2c_pkg is

  procedure scl_fall (
    signal scl_override : inout std_logic) is
  begin  -- procedure scl_rise
    scl_override <= '1';
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    wait until falling_edge(clk);
  end procedure scl_fall;

  procedure scl_rise (
    signal scl_override : inout std_logic) is
  begin  -- procedure scl_rise
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    scl_override <= '0';
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    wait until falling_edge(clk);
  end procedure scl_rise;

  procedure scl_pulse (
    signal scl_override : inout std_logic) is
  begin  -- procedure scl_rise
    scl_rise(scl_override);
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    scl_fall(scl_override);
  end procedure scl_pulse;

  procedure sda_fall (
    signal sda_override : inout std_logic;
    constant assert_no_condition : in std_logic := '1') is
  begin  -- procedure scl_rise
    if assert_no_condition = '1' and sda /= '0' then
      check_equal(scl, '0', "Cannot change sda as that would trigger start condition.", failure);
    end if;

    sda_override <= '1';
    wait until falling_edge(clk);
  end procedure sda_fall;

  procedure sda_rise (
    signal sda_override : inout std_logic;
    constant assert_no_condition : in std_logic := '1') is
  begin  -- procedure scl_rise
    if assert_no_condition = '1' and sda /= '0' then
      check_equal(scl, '0', "Cannot change sda as that would trigger stop condition.", failure);
    end if;

    sda_override <= '0';
    wait until falling_edge(clk);
  end procedure sda_rise;

  procedure tx_write_data (
    constant data   : in    std_logic_vector(7 downto 0);
    signal tx_data : inout std_logic_vector(7 downto 0);
    signal tx_valid : inout std_logic
    ) is
  begin
    check_equal(tx_ready, '1');
    tx_data <= data;
    tx_valid <= '1';
    wait until falling_edge(clk);
    tx_valid <= '0';
  end procedure tx_write_data;

  procedure rx_read_data (
    constant exp_data : in std_logic_vector(7 downto 0);
    signal rx_confirm_read : inout std_logic
    ) is
  begin
    check_equal(rx_valid, '1');
    check_equal(rx_data, exp_data);
    rx_confirm_read <= '1';
    wait until falling_edge(clk);
    rx_confirm_read <= '0';
  end procedure rx_read_data;

end package body tb_i2c_pkg;
