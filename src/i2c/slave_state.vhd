library ieee;
use ieee.std_logic_1164.all;

entity i2c_slave_state is
  port (
    clk_i                    : in  std_logic;
    rst_in                   : in  std_logic;

    start_condition_i        : in  std_logic;
    stop_condition_i         : in  std_logic;

    rw_i                     : in  std_logic;
    address_detect_success_i : in  std_logic;
    address_detect_fail_i    : in  std_logic;
    address_detect_start_o   : out std_logic;
    address_detect_o         : out std_logic;

    receive_o                : out std_logic;
    transmit_o               : out std_logic;
    bus_busy_o               : out std_logic
  );
end entity i2c_slave_state;

architecture a1 of i2c_slave_state is
  type slave_state is (
    BUS_FREE,           -- there is no communication on the bus
    BUS_ADDRESS,        -- communication on the bus just started, listening for
                        -- address
    RECEIVING,          -- we are receiving data
    TRANSMITTING,       -- we are transmitting data
    BUS_BUSY);          -- bus is taken, different slave communicating

  signal curr_state : slave_state;
  signal next_state : slave_state;

  signal communicating_with_master : std_logic;
begin  -- architecture a1

  communicating_with_master <= '1' when curr_state = BUS_ADDRESS or curr_state = RECEIVING or curr_state = TRANSMITTING else '0';

  address_detect_start_o <= '1' when start_condition_i = '1' else '0';
  address_detect_o <= '1' when curr_state = BUS_ADDRESS else '0';

  receive_o <= '1' when curr_state = RECEIVING else '0';
  transmit_o <= '1' when curr_state = TRANSMITTING else '0';
  bus_busy_o <= '1' when curr_state = BUS_BUSY else '0';

  next_state <= BUS_ADDRESS when start_condition_i = '1' else
                -- BUS_BUSY when curr_state = BUS_FREE and (sda_i = '0' or scl_i = '0') else --
                  -- assume busy when there is something on the bus?
                BUS_FREE when stop_condition_i = '1' else
                RECEIVING when curr_state = BUS_ADDRESS and address_detect_success_i = '1' and rw_i = '0' else
                TRANSMITTING when curr_state = BUS_ADDRESS and address_detect_success_i = '1' and rw_i = '1' else
                BUS_BUSY when curr_state = BUS_ADDRESS and address_detect_fail_i = '1' else
                curr_state;

  set_regs: process (clk_i) is
  begin  -- process set_regs
    if rising_edge(clk_i) then          -- rising clock edge
      if rst_in = '0' then              -- synchronous reset (active low)
        curr_state <= BUS_FREE;
      else
        curr_state <= next_state;
      end if;
    end if;
  end process set_regs;

end architecture a1;
