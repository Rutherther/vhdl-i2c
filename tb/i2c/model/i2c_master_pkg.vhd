library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

use work.i2c_bus_pkg;

-- all procedures here take 0 simulation time
-- call i2c_bus_pkg.wait_until_idle to wait
-- until the operation is performed.

package i2c_master_pkg is

  procedure write (
    signal net : inout network_t;
    constant address : in std_logic_vector(6 downto 0);
    constant data    : in std_logic_vector;
    constant timeout : in time;
    constant actor : in actor_t);

  procedure read (
    signal net : inout network_t;
    constant address  : in std_logic_vector(6 downto 0);
    constant exp_data : in std_logic_vector;
    constant timeout  : in time;
    constant actor : in actor_t);

  procedure write_read (
    signal net : inout network_t;
    constant address  : in std_logic_vector(6 downto 0);
    constant data     : in std_logic_vector;
    constant exp_data : in std_logic_vector;
    constant timeout  : in time;
    constant actor : in actor_t);

end package i2c_master_pkg;

package body i2c_master_pkg is

  procedure write (
    signal net : inout network_t;
    constant address : in std_logic_vector(6 downto 0);
    constant data    : in std_logic_vector;
    constant timeout : in time;
    constant actor : in actor_t) is
  begin
    if data'length mod 8 /= 0 then
      failure("The number of bits to write to the slave have to be divisible by 8.");
    end if;

    i2c_bus_pkg.gen_start_cond(net, timeout, actor);
    i2c_bus_pkg.send_data_and_clock(net, address & '0', timeout, actor);

    for i in 0 to data'length/8 - 1 loop
      i2c_bus_pkg.send_data_and_clock(net, data(data'left - i*8 downto data'left - 7 - i*8), timeout, actor);
      i2c_bus_pkg.check_ack_gen_clock(net, '1', timeout, actor);
    end loop;  -- i

    i2c_bus_pkg.gen_stop_cond(net, timeout, actor);
  end procedure write;

  procedure read (
    signal net : inout network_t;
    constant address  : in std_logic_vector(6 downto 0);
    constant exp_data : in std_logic_vector;
    constant timeout  : in time;
    constant actor : in actor_t) is
  begin
    if exp_data'length mod 8 /= 0 then
      failure("The number of bits to read from the slave have to be divisible by 8.");
    end if;

    i2c_bus_pkg.gen_start_cond(net, timeout, actor);
    i2c_bus_pkg.send_data_and_clock(net, address & '1', timeout, actor);

    for i in 0 to exp_data'length/8 - 1 loop
      i2c_bus_pkg.check_data_gen_clock(net, exp_data(exp_data'left - i*8 downto exp_data'left - 7 - i*8), timeout, actor);
      i2c_bus_pkg.send_ack_and_clock(net, timeout, actor);
    end loop;  -- i

    i2c_bus_pkg.gen_stop_cond(net, timeout, actor);
  end procedure read;

  procedure write_read (
    signal net : inout network_t;
    constant address  : in std_logic_vector(6 downto 0);
    constant data     : in std_logic_vector;
    constant exp_data : in std_logic_vector;
    constant timeout  : in time;
    constant actor : in actor_t) is
  begin
    if data'length mod 8 /= 0 then
      failure("The number of bits to write to the slave have to be divisible by 8.");
    end if;

    if exp_data'length mod 8 /= 0 then
      failure("The number of bits to read from the slave have to be divisible by 8.");
    end if;

    i2c_bus_pkg.gen_start_cond(net, timeout, actor);
    i2c_bus_pkg.send_data_and_clock(net, address & '0', timeout, actor);

    for i in 0 to data'length/8 - 1 loop
      i2c_bus_pkg.send_data_and_clock(net, data(data'left - i*8 downto data'left - 7 - i*8), timeout, actor);
      i2c_bus_pkg.check_ack_gen_clock(net, '1', timeout, actor);
    end loop;  -- i

    i2c_bus_pkg.gen_start_cond(net, timeout, actor);
    i2c_bus_pkg.send_data_and_clock(net, address & '1', timeout, actor);

    for i in 0 to exp_data'length/8 - 1 loop
      i2c_bus_pkg.check_data_gen_clock(net, exp_data(exp_data'left - i*8 downto exp_data'left - 7 - i*8), timeout, actor);
      i2c_bus_pkg.send_ack_and_clock(net, timeout, actor);
    end loop;  -- i

    i2c_bus_pkg.gen_stop_cond(net, timeout, actor);
  end procedure write_read;

end package body i2c_master_pkg;
