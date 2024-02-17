library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

use work.i2c_bus_pkg.all;

entity i2c_bus_mod is

  generic (
    inst_name : string;
    default_stretch_timeout: time;
    default_scl_freq: real);

  port (
    sda_io : inout std_logic;
    scl_io : inout std_logic);

end entity i2c_bus_mod;

architecture behav of i2c_bus_mod is
  constant logger : logger_t := get_logger("i2c_bus_mod::" & inst_name);
  constant checker : checker_t := new_checker(logger);

  signal s_free_sda_req : event_t := new_event("free sda");
  signal s_free_scl_req : event_t := new_event("free scl");

  signal s_start_cond_req : event_t := new_event("start cond gen");
  signal s_stop_cond_req : event_t := new_event("stop cond gen");

  signal s_data_req : event_t := new_event("gen data");
  signal s_clk_req : event_t := new_event("gen data");

  signal s_scl_stretch_timeout : time := default_stretch_timeout;
  signal s_scl_frequency : real := default_scl_freq;

  signal s_request_clks_count : natural;
  signal s_request_data : std_logic_vector(1023 downto 0);

  signal s_auto_ack_req : event_t := new_event("auto ack");
  signal s_auto_ack_address : std_logic_vector(6 downto 0);
  signal s_auto_ack_active : boolean;
  signal s_auto_ack_count : natural;

  procedure wait_for_start (
    signal sda        : inout std_logic;
    signal scl        : inout std_logic;
    constant timeout : in time);

  procedure wait_for_stop (
    signal sda        : inout std_logic;
    signal scl        : inout std_logic;
    constant timeout : in time);

  procedure wait_for_clock (
    signal sda        : inout std_logic;
    signal scl        : inout std_logic;
    constant timeout : in time);

  procedure write_bit (
    signal sda        : inout std_logic;
    signal scl        : inout std_logic;
    constant data     : in    std_logic;
    constant timeout  : in    time;
    variable continue : inout boolean);

  function read_bit (
    signal sda        : inout std_logic;
    signal scl        : inout std_logic;
    constant data     : in    std_logic;
    constant timeout  : in    time;
    variable continue : inout boolean) return std_logic;

  function read_data (
    signal sda        : inout std_logic;
    signal scl        : inout std_logic;
    constant timeout  : in    time;
    variable continue : inout boolean) return std_logic_vector;

begin  -- architecture behav

  message_handler: process is
    constant self : actor_t := new_actor(inst_name);

    variable msg : msg_t;
    variable msg_type : msg_type_t;
  begin  -- process message_handler
    receive(net, self, msg);
    msg_type := message_type(msg);

    if msg_type = free_bus_msg then
      notify(s_free_scl_req);
      notify(s_free_sda_req);
    elsif msg_type = set_scl_freq_msg then
      v_frequency := pop(msg);
      s_scl_frequency <= v_frequency;
      s_scl_period <= get_period(v_frequency);
    elsif msg_type = gen_start_cond_msg then
      notify(s_start_cond_req);
      wait until is_active(s_start_cond_done);
    elsif msg_type = gen_stop_cond_msg then
      s_timeout <= pop(msg);
      notify(s_stop_cond_req);
      wait until is_active(s_stop_cond_done);
    elsif msg_type = gen_clocks_msg then
      s_clk_count <= pop(msg);
      s_timeout <= pop(msg);
      notify(s_gen_clk_req);
      wait until is_active(s_gen_clk_done);
    elsif msg_type = send_data_msg then
      s_data_count <= pop(msg);
      s_data <= pop(msg);
      s_timeout <= pop(msg);
      notify(s_data_req);
      wait until is_active(s_data_req);
    elsif msg_type = send_data_clocks_msg then
      v_count := pop(msg);
      s_data_count <= v_count;
      s_clk_count <= v_count;
      s_data <= pop(msg);
      s_timeout <= pop(msg);
      notify(s_gen_clk_req, s_data_clk_req);
      wait until is_active(s_gen_clk_done);
    elsif msg_type = auto_ack_msg then
      s_auto_ack_active <= pop(msg);
      s_auto_ack_address <= pop(msg);
      s_auto_ack_count <= pop(msg);
      notify(s_auto_ack_req);
    elsif msg_type = wait_start_cond_msg then
      wait_for_start(sda_io, scl_io, pop(msg));
    elsif msg_type = wait_stop_cond_msg then
      wait_for_stop(sda_io, scl_io, pop(msg));
    elsif msg_type = wait_clocks_msg then
      v_count := pop(msg);
      v_timeout := pop(msg);
      for i in 1 to v_count loop
        wait_for_clock(sda_io, scl_io, v_timeout);
      end loop;  -- i
    elsif msg_type = check_data_msg then
      s_data_count <= pop(msg);
      s_data_exp <= pop(msg);
      s_timeout <= pop(msg);
      notify(s_check_data_req);
      wait until is_active(s_check_data_done);
    elsif msg_type = check_data_clocks_msg then
      v_count := pop(msg);
      s_data_count <= v_count;
      s_clk_count <= v_count;
      s_data_exp <= pop(msg);
      s_timeout <= pop(msg);
      notify(s_gen_clk_req, s_check_data_req);
      wait until is_active(s_gen_clk_done);
    elsif msg_type = wait_until_idle then
      acknowledge(net, msg, true);
    end if;

  end process message_handler;

end architecture behav;
