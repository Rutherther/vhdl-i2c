library ieee;
use ieee.std_logic_1164.all;

entity i2c_slave_state is
  port (
    clk_i                    : in  std_logic;
    rst_in                   : in  std_logic;
    rst_i2c_o                : out std_logic;

    noack_i                  : in  std_logic;
    expect_ack_i             : in  std_logic;
    unexpected_sda_i         : in  std_logic;
    err_noack_o              : out std_logic;
    err_sda_o                : out std_logic;

    start_condition_i        : in  std_logic;
    stop_condition_i         : in  std_logic;
    rw_i                     : in  std_logic;

    address_detect_success_i : in  std_logic;
    address_detect_fail_i    : in  std_logic;
    address_detect_start_o   : out std_logic;
    address_detect_store_o   : out std_logic;
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

  signal curr_state : slave_state := BUS_FREE;
  signal next_state : slave_state;

  signal curr_err_noack : std_logic;
  signal next_err_noack : std_logic;

  signal curr_err_sda : std_logic;
  signal next_err_sda : std_logic;

  signal communicating_with_master : std_logic;
begin  -- architecture a1
  rst_i2c_o                 <= curr_err_noack or curr_err_sda or start_condition_i or stop_condition_i;

  address_detect_start_o    <= start_condition_i;
  address_detect_store_o    <= start_condition_i;
  address_detect_o          <= '1' when curr_state = BUS_ADDRESS else '0';

  err_noack_o               <= curr_err_noack;
  err_sda_o                 <= curr_err_sda;

  receive_o <= '1' when curr_state = RECEIVING else '0';
  transmit_o <= '1' when curr_state = TRANSMITTING else '0';
  bus_busy_o <= '1' when curr_state = BUS_BUSY else '0';

  communicating_with_master <= '1' when curr_state = BUS_ADDRESS or
                                curr_state = RECEIVING or
                                curr_state = TRANSMITTING else
                               '0';

  next_err_sda <= '0' when start_condition_i = '1' or stop_condition_i = '1' else
                  '1' when curr_err_sda = '1' else
                  '1' when unexpected_sda_i = '1' and curr_state = TRANSMITTING else
                  '0';

  next_err_noack <= '0' when start_condition_i = '1' or stop_condition_i = '1' else
                  '1' when curr_err_noack = '1' else
                  '1' when noack_i = '1' and curr_state = TRANSMITTING and expect_ack_i = '1' else
                  '0';

  next_state <= BUS_ADDRESS when start_condition_i = '1' else
                -- BUS_BUSY when curr_state = BUS_FREE and (sda_i = '0' or scl_i = '0') else --
                  -- assume busy when there is something on the bus?
                BUS_FREE when stop_condition_i = '1' else
                BUS_BUSY when next_err_sda = '1' or next_err_noack = '1' else
                RECEIVING when curr_state = BUS_ADDRESS and address_detect_success_i = '1' and rw_i = '0' else
                TRANSMITTING when curr_state = BUS_ADDRESS and address_detect_success_i = '1' and rw_i = '1' else
                BUS_BUSY when curr_state = BUS_ADDRESS and address_detect_fail_i = '1' else
                curr_state;

  set_regs: process (clk_i) is
  begin  -- process set_regs
    if rising_edge(clk_i) then          -- rising clock edge
      if rst_in = '0' then              -- synchronous reset (active low)
        curr_state <= BUS_FREE;
        curr_err_sda <= '0';
        curr_err_noack <= '0';
      else
        curr_state <= next_state;
        curr_err_noack <= next_err_noack;
        curr_err_sda <= next_err_sda;
      end if;
    end if;
  end process set_regs;

end architecture a1;
