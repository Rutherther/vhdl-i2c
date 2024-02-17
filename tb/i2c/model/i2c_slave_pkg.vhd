--- read(address, exp_data, timeout)
---   wait start
---   wait address
---   ack (if matching)
---   read data, check it
---   check ack on every byte
---   wait stop?
--- write(address, data, timeout)
---   wait start
---   wait address
---   ack (if matching)
---   write data, check ack
---   wait stop?
--- read_write(address, exp_data, data, timeout)
---   wait start
---   wait address
---   ack (if matcihng)
---   start matching bytes
---     ack every byte
---   wait start
---   wait address
---   ack (if matching)
---   write data, check ack

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

use work.i2c_bus_pkg;

package i2c_slave_pkg is

  procedure write (
    constant address  : in std_logic_vector(6 downto 0);
    constant exp_data : in std_logic_vector;
    constant timeout  : in time;
    constant actor    : in actor_t);

  procedure read (
    constant address  : in std_logic_vector(6 downto 0);
    constant data     : in std_logic_vector;
    constant timeout  : in time;
    constant actor : in actor_t);

  procedure write_read (
    constant address  : in std_logic_vector(6 downto 0);
    constant exp_data : in std_logic_vector;
    constant data     : in std_logic_vector;
    constant timeout  : in time;
    constant actor : in actor_t);

end package i2c_slave_pkg;

package body i2c_slave_pkg is

  procedure write (
    constant address  : in std_logic_vector(6 downto 0);
    constant exp_data : in std_logic_vector;
    constant timeout  : in time;
    constant actor    : in actor_t) is
  begin
    if exp_data'length mod 8 /= 0 then
      failure("The number of bits to be written to the slave have to be divisible by 8.");
    end if;

    i2c_bus_pkg.wait_for_start_cond(timeout, actor);
    i2c_bus_pkg.check_data(address & '0', timeout, actor);

    for i in 0 to exp_data'length/8 - 1 loop
      i2c_bus_pkg.check_data(exp_data(exp_data'left - i*8 downto exp_data'left - 7 - i*8), timeout, actor);
      i2c_bus_pkg.send_ack(timeout, actor);
    end loop;  -- i

    i2c_bus_pkg.wait_for_stop_cond(timeout, actor);
  end procedure write;

  procedure read (
    constant address  : in std_logic_vector(6 downto 0);
    constant data     : in std_logic_vector;
    constant timeout  : in time;
    constant actor    : in actor_t) is
  begin
    if data'length mod 8 /= 0 then
      failure("The number of bits to be read from the slave have to be divisible by 8.");
    end if;

    i2c_bus_pkg.wait_for_start_cond(timeout, actor);
    i2c_bus_pkg.check_data(address & '1', timeout, actor);

    for i in 0 to data'length/8 - 1 loop
      i2c_bus_pkg.send_data(data(data'left - i*8 downto data'left - 7 - i*8), timeout, actor);
      i2c_bus_pkg.check_ack(timeout, actor);
    end loop;  -- i

    i2c_bus_pkg.wait_for_stop_cond(timeout, actor);
  end procedure read;

  procedure write_read (
    constant address  : in std_logic_vector(6 downto 0);
    constant data     : in std_logic_vector;
    constant exp_data : in std_logic_vector;
    constant timeout  : in time;
    constant actor : in actor_t) is
  begin
    if exp_data'length mod 8 /= 0 then
      failure("The number of bits to be written to the slave have to be divisible by 8.");
    end if;
    if data'length mod 8 /= 0 then
      failure("The number of bits to be read from the slave have to be divisible by 8.");
    end if;

    i2c_bus_pkg.wait_for_start_cond(timeout, actor);
    i2c_bus_pkg.send_data_and_clock(address & '0', timeout, actor);

    for i in 0 to exp_data'length/8 - 1 loop
      i2c_bus_pkg.check_data(exp_data(exp_data'left - i*8 downto exp_data'left - 7 - i*8), timeout, actor);
      i2c_bus_pkg.send_ack(timeout, actor);
    end loop;  -- i

    i2c_bus_pkg.wait_for_start_cond(timeout, actor);
    i2c_bus_pkg.send_data_and_clock(address & '1', timeout, actor);

    for i in 0 to data'length/8 - 1 loop
      i2c_bus_pkg.send_data(data(data'left - i*8 downto data'left - 7 - i*8), timeout, actor);
      i2c_bus_pkg.check_ack(timeout, actor);
    end loop;  -- i

    i2c_bus_pkg.wait_for_stop_cond(timeout, actor);
  end procedure write_read;


end package body i2c_slave_pkg;
