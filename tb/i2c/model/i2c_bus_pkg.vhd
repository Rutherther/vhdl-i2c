library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

-- except for wait_until_idle,
-- the procedures take 0 simulation time.
-- wait_until_idle will take time until all
-- operations requested on the i2c were
-- performed.

package i2c_bus_pkg is
  constant free_bus_msg : msg_type_t := new_msg_type("free bus");
  constant set_scl_freq_msg : msg_type_t := new_msg_type("scl freq");
  constant gen_start_cond_msg : msg_type_t := new_msg_type("gen start cond");
  constant gen_stop_cond_msg : msg_type_t := new_msg_type("gen stop cond");
  constant gen_clocks_msg : msg_type_t := new_msg_type("gen clocks");
  constant send_data_msg : msg_type_t := new_msg_type("send data");
  constant send_data_clocks_msg : msg_type_t := new_msg_type("send data and clocks");

  constant auto_ack_msg : msg_type_t := new_msg_type("auto acknowledge");

  constant wait_start_cond_msg : msg_type_t := new_msg_type("wait start cond");
  constant wait_stop_cond_msg : msg_type_t := new_msg_type("wait stop cond");
  constant wait_clocks_msg : msg_type_t := new_msg_type("wait clocks");

  constant check_data_msg : msg_type_t := new_msg_type("check data");
  constant check_data_clocks_msg : msg_type_t := new_msg_type("check data and gen clocks");

  constant wait_until_idle_msg : msg_type_t := new_msg_type("wait until idle");

  impure function get_actor (
    constant inst_name : string)
    return actor_t;

  procedure free_bus (
    signal net : inout network_t;
    constant actor : in actor_t);

  procedure set_scl_frequency (
    signal net : inout network_t;
    constant frequency : in real;
    constant actor : in actor_t);

  procedure gen_start_cond (
    signal net : inout network_t;
    constant timeout : in time;
    constant actor : in actor_t);

  procedure gen_stop_cond (
    signal net : inout network_t;
    constant timeout : in time;
    constant actor : in actor_t);

  procedure gen_clocks (
    signal net : inout network_t;
    constant times : in natural;
    constant timeout : in time;
    constant actor : in actor_t);

  procedure send_data (
    signal net : inout network_t;
    constant data : in std_logic_vector;
    constant timeout : in time;
    constant actor : in actor_t);

  procedure send_ack (
    signal net : inout network_t;
    constant timeout : in time;
    constant actor : in actor_t);

  procedure send_ack_and_clock (
    signal net : inout network_t;
    constant timeout : in time;
    constant actor : in actor_t);

  procedure send_data_and_clock (
    signal net : inout network_t;
    constant data : in std_logic_vector;
    constant timeout : in time;
    constant actor : in actor_t);

  procedure wait_for_start_cond (
    signal net : inout network_t;
    constant timeout : in time;
    constant actor : in actor_t);

  procedure wait_for_stop_cond (
    signal net : inout network_t;
    constant timeout : in time;
    constant actor : in actor_t);

  procedure wait_for_clocks (
    signal net : inout network_t;
    constant times : in natural;
    constant timeout : in time;
    constant actor : in actor_t);

  procedure check_data (
    signal net : inout network_t;
    constant exp_data : in std_logic_vector;
    constant timeout : in time;
    constant actor : in actor_t);

  procedure check_data_gen_clock (
    signal net : inout network_t;
    constant exp_data : in std_logic_vector;
    constant timeout : in time;
    constant actor : in actor_t);

  procedure check_ack_gen_clock (
    signal net : inout network_t;
    constant ack : in std_logic := '1';
    constant timeout : in time;
    constant actor : in actor_t);

  procedure check_ack (
    signal net : inout network_t;
    constant ack : in std_logic := '1';
    constant timeout : in time;
    constant actor : in actor_t);

  procedure set_auto_ack (
    signal net : inout network_t;
    constant auto_ack : in boolean;
    constant address : in std_logic_vector(6 downto 0);
    constant bytes_count : in natural;
    constant actor : in actor_t);

  procedure wait_until_idle (
    signal net : inout network_t;
    constant actor : in actor_t);

end package i2c_bus_pkg;

package body i2c_bus_pkg is

  impure function get_actor (
    constant inst_name : string)
    return actor_t is
  begin
    return find(inst_name);
  end function get_actor;

  procedure free_bus (
    signal net : inout network_t;
    constant actor : in actor_t) is
    variable msg : msg_t := new_msg(free_bus_msg);
  begin
    send(net, actor, msg);
  end procedure free_bus;

  procedure set_scl_frequency (
    signal net : inout network_t;
    constant frequency : in real;
    constant actor : in actor_t) is
    variable msg : msg_t := new_msg(set_scl_freq_msg);
  begin
    push(msg, frequency);
    send(net, actor, msg);
  end procedure set_scl_frequency;

  procedure gen_start_cond (
    signal net : inout network_t;
    constant timeout : in time;
    constant actor : in actor_t) is
    variable msg : msg_t := new_msg(gen_start_cond_msg);
  begin
    push(msg, timeout);
    send(net, actor, msg);
  end procedure gen_start_cond;

  procedure gen_stop_cond (
    signal net : inout network_t;
    constant timeout : in time;
    constant actor : in actor_t) is
    variable msg : msg_t := new_msg(gen_stop_cond_msg);
  begin
    push(msg, timeout);
    send(net, actor, msg);
  end procedure gen_stop_cond;

  procedure gen_clocks (
    signal net : inout network_t;
    constant times : in natural;
    constant timeout : in time;
    constant actor : in actor_t) is
    variable msg : msg_t := new_msg(gen_clocks_msg);
  begin
    push(msg, times);
    push(msg, timeout);
    send(net, actor, msg);
  end procedure gen_clocks;

  procedure send_data (
    signal net : inout network_t;
    constant data : in std_logic_vector;
    constant timeout : in time;
    constant actor : in actor_t) is
    variable msg : msg_t := new_msg(send_data_msg);
    variable msg_data : std_logic_vector(1023 downto 0);
  begin
    msg_data(data'length - 1 downto 0) := data(data'range);
    push(msg, data'length);
    push(msg, msg_data);
    push(msg, timeout);
    send(net, actor, msg);
  end procedure send_data;

  procedure send_ack (
    signal net : inout network_t;
    constant timeout : in time;
    constant actor : in actor_t) is
  begin
    send_data(net, "0", timeout, actor);
  end procedure send_ack;

  procedure send_ack_and_clock (
    signal net : inout network_t;
    constant timeout : in time;
    constant actor : in actor_t) is
  begin
    send_data_and_clock(net, "0", timeout, actor);
  end procedure send_ack_and_clock;

  procedure send_data_and_clock (
    signal net : inout network_t;
    constant data : in std_logic_vector;
    constant timeout : in time;
    constant actor : in actor_t) is
    variable msg : msg_t := new_msg(send_data_clocks_msg);
    variable msg_data : std_logic_vector(1023 downto 0);
  begin
    msg_data(data'length - 1 downto 0) := data(data'range);
    push(msg, data'length);
    push(msg, msg_data);
    push(msg, timeout);
    send(net, actor, msg);
  end procedure send_data_and_clock;

  procedure wait_for_start_cond (
    signal net : inout network_t;
    constant timeout : in time;
    constant actor : in actor_t) is
    variable msg : msg_t := new_msg(wait_start_cond_msg);
  begin
    push(msg, timeout);
    send(net, actor, msg);
  end procedure wait_for_start_cond;

  procedure wait_for_stop_cond (
    signal net : inout network_t;
    constant timeout : in time;
    constant actor : in actor_t) is
    variable msg : msg_t := new_msg(wait_stop_cond_msg);
  begin
    push(msg, timeout);
    send(net, actor, msg);
  end procedure wait_for_stop_cond;

  procedure wait_for_clocks (
    signal net : inout network_t;
    constant times : in natural;
    constant timeout : in time;
    constant actor : in actor_t) is
    variable msg : msg_t := new_msg(wait_clocks_msg);
  begin
    push(msg, times);
    push(msg, timeout);
    send(net, actor, msg);
  end procedure wait_for_clocks;

  procedure check_data (
    signal net : inout network_t;
    constant exp_data : in std_logic_vector;
    constant timeout : in time;
    constant actor : in actor_t) is
    variable msg_data : std_logic_vector(1023 downto 0);
    variable msg : msg_t := new_msg(check_data_msg);
  begin
    msg_data(exp_data'length - 1 downto 0) := exp_data(exp_data'range);
    push(msg, exp_data'length);
    push(msg, msg_data);
    push(msg, timeout);
    send(net, actor, msg);
  end procedure check_data;

  procedure check_data_gen_clock (
    signal net : inout network_t;
    constant exp_data : in std_logic_vector;
    constant timeout : in time;
    constant actor : in actor_t) is
    variable msg_data : std_logic_vector(1023 downto 0);
    variable msg : msg_t := new_msg(check_data_clocks_msg);
  begin
    msg_data(exp_data'length - 1 downto 0) := exp_data(exp_data'range);
    push(msg, exp_data'length);
    push(msg, msg_data);
    push(msg, timeout);
    send(net, actor, msg);
  end procedure check_data_gen_clock;

  procedure check_ack_gen_clock (
    signal net : inout network_t;
    constant ack : in std_logic := '1';
    constant timeout : in time;
    constant actor : in actor_t) is
    variable v_vector : std_logic_vector(0 downto 0) := (0 => not ack);
  begin
    check_data_gen_clock(net, v_vector, timeout, actor);
  end procedure check_ack_gen_clock;

  procedure check_ack (
    signal net : inout network_t;
    constant ack : in std_logic := '1';
    constant timeout : in time;
    constant actor : in actor_t) is
    variable v_vector : std_logic_vector(0 downto 0) := (0 => not ack);
  begin
    check_data(net, v_vector, timeout, actor);
  end procedure check_ack;

  procedure set_auto_ack (
    signal net : inout network_t;
    constant auto_ack : in boolean;
    constant address : in std_logic_vector(6 downto 0);
    constant bytes_count : in natural;
    constant actor : in actor_t) is
    variable msg : msg_t := new_msg(auto_ack_msg);
  begin
    push(msg, auto_ack);
    push(msg, address);
    push(msg, bytes_count);
    send(net, actor, msg);
  end procedure set_auto_ack;

  procedure wait_until_idle (
    signal net : inout network_t;
    constant actor : in actor_t) is
    variable msg : msg_t := new_msg(wait_until_idle_msg);
    variable ack : boolean;
  begin
    request(net, actor, msg, ack);
  end procedure wait_until_idle;

end package body i2c_bus_pkg;
