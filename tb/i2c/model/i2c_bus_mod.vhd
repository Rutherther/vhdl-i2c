library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

use work.i2c_bus_pkg.all;

entity i2c_bus_mod is

  generic (
    inst_name : string;
    default_scl_freq: real);

  port (
    sda_io        : inout std_logic;
    scl_io        : inout std_logic;
    clk_i         : in    std_logic;
    scl_rising_o  : out   std_logic;
    scl_falling_o : out   std_logic);

end entity i2c_bus_mod;

architecture behav of i2c_bus_mod is
  constant logger : logger_t := get_logger("i2c_bus_mod::" & inst_name);
  constant checker : checker_t := new_checker(logger);

  function get_period (
    constant frequency : in real) return time is
  begin  -- procedure get_period
    return (1_000_000_000.0 / frequency) * 1 ns;
  end function get_period;

  signal s_free_sda_req : event_t := new_event(inst_name & "free sda");
  signal s_free_scl_req : event_t := new_event(inst_name & "free scl");

  signal s_start_cond_req : event_t := new_event(inst_name & "start cond gen");
  signal s_start_cond_done : event_t := new_event(inst_name & "start cond done");

  signal s_stop_cond_req : event_t := new_event(inst_name & "stop cond gen");
  signal s_stop_cond_done : event_t := new_event(inst_name & "stop cond done");

  signal s_check_data_req : event_t := new_event(inst_name & "check data req");
  signal s_check_data_done : event_t := new_event(inst_name & "check data done");

  signal s_data_req : event_t := new_event(inst_name & "gen data");
  signal s_data_done : event_t := new_event(inst_name & "data done");

  signal s_clk_req : event_t := new_event(inst_name & "gen clk");
  signal s_clk_done : event_t := new_event(inst_name & "clk done");

  signal s_scl_frequency : real := default_scl_freq;
  signal s_scl_period : time := get_period(default_scl_freq);

  signal s_auto_ack_req : event_t := new_event(inst_name & "auto ack");
  signal s_auto_ack_address : std_logic_vector(6 downto 0);
  signal s_auto_ack_active : boolean;
  signal s_auto_ack_count : natural;

  signal s_data_count : natural;
  signal s_data : std_logic_vector(1023 downto 0);

  signal s_clk_count : natural;
  signal s_clk_start : std_logic;

  signal s_timeout : time;

  signal s_byte_sent : event_t := new_event(inst_name & "byte sent");
  signal s_start_cond : event_t := new_event(inst_name & "start cond");
  signal s_bus_busy : std_logic;
  signal s_read_byte : std_logic_vector(7 downto 0);
  signal s_bits_since_start_cond : natural := 0;

  procedure wait_for_start (
    signal sda        : inout std_logic;
    signal scl        : inout std_logic;
    variable timeout  : inout time) is
    constant v_now : time := now;
  begin
    wait until scl = 'H' and falling_edge(sda) for timeout;

    if scl /= 'H' or not falling_edge(sda) then
      failure(logger, "Timed out when waiting for start condition!");
    else
      timeout := timeout - (now - v_now);
    end if;
  end procedure wait_for_start;

  procedure wait_for_stop (
    signal sda        : inout std_logic;
    signal scl        : inout std_logic;
    variable timeout  : inout time) is
    constant v_now : time := now;
  begin
    wait until scl = 'H' and rising_edge(sda) for timeout;

    if scl /= 'H' or not rising_edge(sda) then
      error(logger, "Timed out when waiting for stop condition!");
    else
      timeout := timeout - (now - v_now);
    end if;
  end procedure wait_for_stop;

  procedure wait_for_clock (
    signal sda        : inout std_logic;
    signal scl        : inout std_logic;
    variable timeout  : inout time) is
    variable v_now : time := now;
  begin
    -- TODO: start or stop condition?
    wait until rising_edge(scl) for timeout;

    if not rising_edge(scl) then
      error(logger, "Timed out when waiting for clock!");
    else
      timeout := timeout - (now - v_now);
    end if;
  end procedure wait_for_clock;

  procedure write_bit (
    signal sda        : inout std_logic;
    signal scl        : inout std_logic;
    constant data     : in    std_logic;
    variable timeout  : inout time;
    variable continue : inout boolean) is
    variable v_now : time := now;
  begin
    if scl = 'H' then
      wait until (sda'event and scl = 'H') or falling_edge(scl) for timeout;
    end if;

    if sda'event and scl = 'H' then
      wait for 0 ns;
      error(logger, "Got start or stop condition when trying to write a bit!");
      continue := false;
      return;
    elsif falling_edge(scl) then
      -- nop
      wait for s_scl_period / 4;
      timeout := timeout - (now - v_now);
    elsif scl = '0' then
    else
      error(logger, "Timed out when waiting for falling edge of scl to write a bit!");
      continue := false;
      -- timeout
      return;
    end if;

    if data = '1' then
      sda <= 'Z';
    else
      sda <= data;
    end if;

    -- wait for next clock
    wait until (sda'event and scl = 'H') or falling_edge(scl) for timeout;

    if sda'event and scl = 'H' then
      wait for 0 ns;
      error(logger, "Got start or stop condition when trying to write a bit!");
      continue := false;
      sda <= 'Z';
    elsif falling_edge(scl) then
      wait for s_scl_period / 4;
      sda <= 'Z';
    else
      continue := false;
      error(logger, "Could not get rising edge of scl to write data.");
    end if;

  end procedure write_bit;

  procedure read_bit (
    signal sda        : inout std_logic;
    signal scl        : inout std_logic;
    variable data     : out std_logic;
    variable timeout  : inout time;
    variable continue : inout boolean) is
    variable v_now : time := now;
  begin
    if not continue then
      data := 'X';
      return;
    end if;

    wait until (sda'event and scl = 'H') or rising_edge(scl) for timeout;

    if sda'event and scl = 'H' then
      -- start / stop condition. Cannot read further.
      error(logger, "Got start or stop condition when trying to read a bit!");
      continue := false;
      data := 'X';
      return;
    elsif rising_edge(scl) then
      if sda = 'H' then
        data := '1';
        return;
      end if;

      timeout := timeout - (now - v_now);
      data := sda;
      return;
    else
      -- timeout
      error(logger, "Timed out when waiting for rising edge to read a bit!");
      continue := false;
    end if;

  end procedure read_bit;

  procedure read_data (
    signal sda        : inout std_logic;
    signal scl        : inout std_logic;
    constant count    : in    natural;
    variable data     : out   std_logic_vector;
    variable timeout  : inout time;
    variable continue : inout boolean) is
  begin
    for i in (count - 1) downto 0 loop
      read_bit(sda, scl, data(i), timeout, continue);

      if not continue then
        return;
      end if;
    end loop;  -- i
  end procedure read_data;

  procedure process_disconnect_req (
    signal evnt : inout event_t;
    signal sda  : inout std_logic;
    signal scl  : inout std_logic) is

    variable scl_freed : boolean := false;
    variable sda_freed : boolean := false;
  begin
    while not scl_freed or not sda_freed loop
      if is_active(s_free_sda_req) then
        sda_freed := true;
        sda <= 'Z';
      end if;

      if is_active(s_free_scl_req) then
        scl_freed := true;
        scl <= 'Z';
      end if;

      if is_active(evnt) then
        exit;
      end if;

      if not scl_freed or not sda_freed then
        wait until is_active(s_free_scl_req) or is_active(s_free_sda_req) or is_active(evnt);
      end if;
    end loop;
  end procedure process_disconnect_req;

  procedure req_disconnect(
    signal free_sda_req: inout event_t;
    signal free_scl_req: inout event_t) is
  begin
    notify(free_sda_req);
    notify(free_scl_req);
  end procedure req_disconnect;

  procedure dc(
    signal sda : inout std_logic;
    signal scl : inout std_logic) is
  begin  -- procedure disconnect
    sda <= 'Z';
    scl <= 'Z';
  end procedure dc;

begin  -- architecture behav
  scl_io <= 'H';
  sda_io <= 'H';

  start_cond_gen: process is
  begin  -- process start_cond_gen
    dc(sda_io, scl_io);
    if not is_active(s_start_cond_req) then
      wait until is_active(s_start_cond_req);
    end if;

    info(logger, "Initiating communication on the bus by generating a start condition.");

    check(checker, sda_io = 'H', "SDA cannot be low to generate a start condition!", level => failure);
    check(checker, scl_io = 'H', "SCL cannot be low to generate a start condition!", level => failure);

    req_disconnect(s_free_sda_req, s_free_scl_req);

    sda_io <= '0';
    wait until scl_io'event for s_scl_period / 4;
    scl_io <= '0';
    wait for s_scl_period / 4;

    info(logger, "Start condition generated.");

    notify(s_start_cond_done);
    process_disconnect_req(s_start_cond_req, sda_io, scl_io);
  end process start_cond_gen;

  stop_cond_gen: process is
    variable v_timeout : time;
  begin  -- process stop_cond_gen
    dc(sda_io, scl_io);
    if not is_active(s_stop_cond_req) then
      wait until is_active(s_stop_cond_req);
    end if;

    v_timeout := s_timeout;

    check(checker, scl_io = '0', "SCL cannot be high to generate a stop condition!", level => failure);

    scl_io <= '0';
    sda_io <= '0';
    req_disconnect(s_free_sda_req, s_free_scl_req);

    info(logger, "Stopping communication on the bus by generating a stop condition.");

    wait for s_scl_period / 4;
    scl_io <= 'Z';

    wait until scl_io = 'H' for v_timeout;

    if scl_io /= 'H' then
      error(logger, "Timed out when waiting for scl rising edge to generate a stop condition!");
    end if;

    wait for s_scl_period / 4;
    sda_io <= 'Z';

    wait until sda_io = 'H' for v_timeout;

    if sda_io /= 'H' then
      error(logger, "Timed out when waiting for sda rising edge to generate a stop condition!");
    end if;

    wait for s_scl_period / 4;

    info(logger, "Stop condition generated.");

    notify(s_stop_cond_done);

    -- already freed...
    -- process_disconnect_req(sda_io, scl_io);
  end process stop_cond_gen;

  data_gen: process is
    variable v_timeout : time;
    variable v_position : natural;
    variable v_continue : boolean;

    variable v_data : std_logic_vector(1023 downto 0);
    variable v_count : natural;
  begin  -- process data_gen
    dc(sda_io, scl_io);
    if not is_active(s_data_req) then
      wait until is_active(s_data_req);
    end if;

    v_timeout := s_timeout;
    v_continue := true;
    v_data := s_data;
    v_count := s_data_count;

    notify(s_free_sda_req);

    v_position := 0;
    while v_continue and v_position < v_count loop
      write_bit(sda_io, scl_io, v_data(v_count - 1 - v_position), v_timeout, v_continue);
      v_position := v_position + 1;
    end loop;

    if v_continue and v_count = 8 then
      info(logger, "Sent I2C frame of data.");
    elsif v_count = 8 then
      warning(logger, "Could not send requested data to the bus.");
    end if;

    if s_bits_since_start_cond <= 8 and v_count = 8 then
      -- send address and rw
      info(logger, "Sent I2C Frame: " & to_string(v_data(v_count - 1 downto 0)));
      info(logger, "  Slave Address: " & to_string(v_data(7 downto 1)));
      info(logger, "  RW: " & to_string(v_data(0)));
    elsif v_count = 8 then
      -- sent just data
      info(logger, "I2C Frame: " & to_string(v_data(v_count - 1 downto 0)));
    end if;

    if v_count = 1 and s_bits_since_start_cond mod 9 = 8 then
      if v_continue then
        info(logger, "Sent ACK.");
      else
        warning(logger, "Could not send ACK!");
      end if;
    end if;

    notify(s_data_done);
    wait until is_active(s_free_sda_req) or is_active(s_data_req);
    sda_io <= 'Z';
  end process data_gen;

  clk_gen: process is
    variable v_start : std_logic;

    variable v_continue : boolean;

    variable v_count : natural;
    variable v_position : natural;
    variable v_timeout : time;
    variable v_now : time;
  begin  -- process clk_gen
    dc(sda_io, scl_io);
    if not is_active(s_clk_req) then
      wait until is_active(s_clk_req);
    end if;

    v_count := s_clk_count;
    v_timeout := s_timeout;
    v_start := s_clk_start;
    v_now := now;

    scl_io <= v_start;
    notify(s_free_scl_req);

    if v_start = 'H' then
      if scl_io /= 'H' then
        wait until scl_io = 'H' for v_timeout;
      end if;

      if scl_io /= 'H' then
        error(logger, "Timed out when waiting for scl rising edge to generate clock.");
      end if;

      wait until scl_io /= 'H' for s_scl_period / 2;

      if scl_io /= 'H' then
        error(logger, "Got instability at scl when generating clock!");
      end if;

      scl_io <= '0';
      wait for s_scl_period / 4;
    end if;

    v_position := 0;
    v_continue := true;
    while v_continue and v_position < v_count loop
      wait for s_scl_period / 4;

      scl_io <= 'Z';

      if scl_io /= 'H' then
        wait until scl_io = 'H' for v_timeout;
      end if;

      if scl_io /= 'H' then
        error(logger, "Timed out when waiting for scl rising edge to generate clock.");
      end if;

      wait until scl_io /= 'H' for s_scl_period / 2;

      if scl_io /= 'H' then
        error(logger, "Got instability at scl when generating clock!");
      end if;

      scl_io <= '0';
      wait for s_scl_period / 4;

      v_position := v_position + 1;
    end loop;

    notify(s_clk_done);
    wait until is_active(s_free_scl_req) or is_active(s_clk_req);
  end process clk_gen;

  data_checker: process is
    variable v_timeout : time;
    variable v_position : natural;
    variable v_continue : boolean;

    variable v_exp_data : std_logic_vector(1023 downto 0);
    variable v_read_data : std_logic_vector(1023 downto 0);
    variable v_count : natural;
  begin  -- process data_checker
    dc(sda_io, scl_io);
    if not is_active(s_check_data_req) then
      wait until is_active(s_check_data_req);
    end if;

    v_timeout := s_timeout;
    v_exp_data := s_data;
    v_count := s_data_count;

    v_position := 0;
    v_continue := true;
    while v_continue and v_position < v_count loop
      read_bit(sda_io, scl_io, v_read_data(v_count - 1 - v_position), v_timeout, v_continue);
      v_position := v_position + 1;
    end loop;

    if v_continue and v_count = 8 then
      info(logger, "Received I2C frame of data.");
    elsif v_count = 8 then
      warning(logger, "Could not receive requested data on the bus.");
    end if;

    if v_exp_data(v_count - 1 downto 0) = v_read_data(v_count - 1 downto 0) then
      info(logger, "Got expected data.");
    else
      error(logger, "Received data do not match expected data.");
    end if;

    if s_bits_since_start_cond <= 8 and v_count = 8 then
      -- send address and rw
      info(logger, "Expected I2C Frame: " & to_string(v_exp_data(v_count - 1 downto 0)));
      info(logger, "  Slave Address: " & to_string(v_exp_data(7 downto 1)));
      info(logger, "  RW: " & to_string(v_exp_data(0)));
      info(logger, "Received I2C Frame: " & to_string(v_read_data(v_count - 1 downto 0)));
      info(logger, "  Slave Address: " & to_string(v_read_data(7 downto 1)));
      info(logger, "  RW: " & to_string(v_read_data(0)));
    elsif v_count = 8 then
      -- sent just data
      info(logger, "Received I2C Frame: " & to_string(v_read_data(v_count - 1 downto 0)));
      info(logger, "Expected I2C Frame: " & to_string(v_exp_data(v_count - 1 downto 0)));
    end if;

    if v_count = 1 and s_bits_since_start_cond mod 9 = 8 then
      if v_continue then
        if v_exp_data(0) = '0' then
          if v_read_data(0) = '0' then
            info(logger, "Received ACK.");
          else
            error(logger, "Received NACK instead of ACK.");
          end if;
        else
          if v_read_data(0) = '0' then
            error(logger, "Received unexpected ACK.");
          else
            info(logger, "Received expected NACK.");
          end if;
        end if;
      else
        warning(logger, "Could not receive ACK!");
      end if;
    end if;

    notify(s_check_data_done);

  end process data_checker;

  gen_rising_pulse: process is
  begin  -- process gen_rising_pulse
    dc(sda_io, scl_io);
    scl_rising_o <= '0';
    wait until rising_edge(scl_io);
    scl_rising_o <= '1';

    wait until rising_edge(clk_i);
    wait until falling_edge(clk_i);
  end process gen_rising_pulse;

  gen_falling_pulse: process is
  begin  -- process gen_rising_pulse
    dc(sda_io, scl_io);
    scl_falling_o <= '0';
    wait until falling_edge(scl_io);
    scl_falling_o <= '1';

    wait until rising_edge(clk_i);
    wait until falling_edge(clk_i);
  end process gen_falling_pulse;

  auto_ack_gen: process is
    variable v_address : std_logic_vector(6 downto 0);
    variable v_rw : std_logic;

    variable v_continue : boolean;
    variable v_timeout : time;
  begin  -- process auto_ack_gen
    dc(sda_io, scl_io);
    if not s_auto_ack_active then
      wait until is_active(s_auto_ack_req);
    end if;

    wait until is_active(s_byte_sent) or is_active(s_auto_ack_req);

    if is_active(s_byte_sent) and s_auto_ack_active then
      if s_bits_since_start_cond = 8 then
        v_address := s_read_byte(7 downto 1);
        v_rw := s_read_byte(0);
      end if;

      v_timeout := time'high;
      v_continue := true;
      if v_address = s_auto_ack_address and v_rw = '0' then
        write_bit(sda_io, scl_io, '0', v_timeout, v_continue);
        info(logger, "Sent automatic ACK as " & to_string(v_address));
        write_bit(sda_io, scl_io, '1', v_timeout, v_continue);
      elsif v_address = "0000000" and v_rw = '1' and s_bits_since_start_cond > 8 then
        write_bit(sda_io, scl_io, '0', v_timeout, v_continue);
        info(logger, "Sent automatic ACK as master.");
        write_bit(sda_io, scl_io, '1', v_timeout, v_continue);
      end if;
    end if;
  end process auto_ack_gen;

  bit_counter: process is
    variable v_started : boolean;
    variable v_read : std_logic;
    variable v_timeout : time;
  begin  -- process bit_counter
    dc(sda_io, scl_io);
    if not v_started then
      v_timeout := time'high;
      wait_for_start(sda_io, scl_io, v_timeout);
      v_started := true;

      notify(s_start_cond);
      s_bus_busy <= '1';
      s_bits_since_start_cond <= 0;
    end if;

    wait until (sda_io'event and scl_io = 'H') or rising_edge(scl_io);

    if rising_edge(scl_io) then
      if sda_io = 'H' then
        v_read := '1';
      else
        v_read := sda_io;
      end if;

      s_read_byte <= s_read_byte(6 downto 0) & v_read;
      s_bits_since_start_cond <= s_bits_since_start_cond + 1;

      wait for 0 ns;
      if s_bits_since_start_cond mod 8 = 0 then
        notify(s_byte_sent);
      end if;
    else
      s_bits_since_start_cond <= 0;

      wait for 0 ns;
      if sda_io = 'H' then
        v_started := false;
        s_bus_busy <= '0';
      else
        notify(s_start_cond);
      end if;
    end if;
  end process bit_counter;

  message_handler: process is
    constant self : actor_t := new_actor(inst_name);

    variable msg : msg_t;
    variable msg_type : msg_type_t;

    variable v_frequency : real;
    variable v_count : natural;
    variable v_timeout : time;
  begin  -- process message_handler
    dc(sda_io, scl_io);
    receive(net, self, msg);
    msg_type := message_type(msg);

    if msg_type = free_bus_msg then
      wait for s_scl_period / 4;
      req_disconnect(s_free_sda_req, s_free_scl_req);
    elsif msg_type = set_scl_freq_msg then
      v_frequency := pop(msg);
      s_scl_frequency <= v_frequency;
      s_scl_period <= get_period(v_frequency);
    elsif msg_type = gen_start_cond_msg then
      s_timeout <= pop(msg);
      notify(s_start_cond_req);
      wait until is_active(s_start_cond_done);
    elsif msg_type = gen_stop_cond_msg then
      s_timeout <= pop(msg);
      notify(s_stop_cond_req);
      wait until is_active(s_stop_cond_done);
    elsif msg_type = gen_clocks_msg then
      s_clk_start <= scl_io;
      s_clk_count <= pop(msg);
      s_timeout <= pop(msg);
      notify(s_clk_req);
      wait until is_active(s_clk_done);
    elsif msg_type = send_data_msg then
      s_data_count <= pop(msg);
      s_data <= pop(msg);
      s_timeout <= pop(msg);
      notify(s_data_req);
      wait until is_active(s_data_done);
    elsif msg_type = send_data_clocks_msg then
      s_clk_start <= scl_io;
      v_count := pop(msg);
      s_data_count <= v_count;
      s_clk_count <= v_count;
      s_data <= pop(msg);
      s_timeout <= pop(msg);
      notify(s_clk_req, s_data_req);
      wait until is_active(s_clk_done);
    elsif msg_type = auto_ack_msg then
      s_auto_ack_active <= pop(msg);
      s_auto_ack_address <= pop(msg);
      s_auto_ack_count <= pop(msg);
      notify(s_auto_ack_req);
    elsif msg_type = wait_start_cond_msg then
      req_disconnect(s_free_sda_req, s_free_scl_req);
      v_timeout := pop(msg);
      wait_for_start(sda_io, scl_io, v_timeout);
    elsif msg_type = wait_stop_cond_msg then
      req_disconnect(s_free_sda_req, s_free_scl_req);
      v_timeout := pop(msg);
      wait_for_stop(sda_io, scl_io, v_timeout);
    elsif msg_type = wait_clocks_msg then
      req_disconnect(s_free_sda_req, s_free_scl_req);
      v_count := pop(msg);
      v_timeout := pop(msg);
      for i in 1 to v_count loop
        wait_for_clock(sda_io, scl_io, v_timeout);
      end loop;  -- i
    elsif msg_type = check_data_msg then
      req_disconnect(s_free_sda_req, s_free_scl_req);
      s_data_count <= pop(msg);
      s_data <= pop(msg);
      s_timeout <= pop(msg);
      notify(s_check_data_req);
      wait until is_active(s_check_data_done);
    elsif msg_type = check_data_clocks_msg then
      s_clk_start <= scl_io;
      notify(s_free_sda_req);
      v_count := pop(msg);
      s_data_count <= v_count;
      s_clk_count <= v_count;
      s_data <= pop(msg);
      s_timeout <= pop(msg);
      notify(s_clk_req);
      notify(s_check_data_req);
      wait until is_active(s_clk_done);
    elsif msg_type = wait_until_idle_msg then
      acknowledge(net, msg, true);
    end if;

  end process message_handler;

end architecture behav;
