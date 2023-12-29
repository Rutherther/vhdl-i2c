library ieee;
use ieee.std_logic_1164.all;

use work.i2c_pkg.all;

entity address_detector is

  port (
    clk_i       : in  std_logic;        -- Input clock
    rst_in      : in  std_logic;        -- Reset the detection
    address_i   : in  std_logic_vector(6 downto 0);
    scl_pulse_i : in  std_logic;
    sda_i      : in  std_logic;   -- The data that could contain the address
    start_i     : in  std_logic;        -- When to start looking for the
                                        -- address. Will clear success_o
    rw_o        : out std_logic;
    success_o   : out std_logic;        -- Whether full address matches
    fail_o      : out std_logic);       -- Whether matching failed. Will stay 0
                                        -- as long as bits are matching. Will
                                        -- be set to 1 the first bit that does
                                        -- not match the address

end entity address_detector;

architecture a1 of address_detector is
  type state_t is (IDLE, CHECKING_START, CHECKING, MATCH, FAIL);
  signal curr_state : state_t;
  signal next_state : state_t;

  signal curr_index : integer range 0 to 7;
  signal next_index : integer range 0 to 7;

  signal curr_read_rw : std_logic;
  signal next_read_rw : std_logic;

  signal mismatch : std_logic;
begin  -- architecture a1

  fail_o <= '1' when curr_state = FAIL else '0';
  success_o <= '1' when curr_state = MATCH else '0';
  rw_o <= curr_read_rw when curr_state = MATCH else '0';

  next_read_rw <= sda_i when scl_pulse_i = '1' and curr_index = 7 else
                  curr_read_rw;

  next_index <= (curr_index + 1) when curr_state = CHECKING and scl_pulse_i = '1' and curr_index < 7 else
                curr_index when curr_state = CHECKING else
                0;

  mismatch <= '1' when curr_index <= 6 and address_i(6 - curr_index) /= sda_i and scl_pulse_i = '1' else '0';

  set_next_state: process (all) is
  begin  -- process set_next_state
    next_state <= curr_state;

    if curr_state = CHECKING_START then
      next_state <= CHECKING;
    end if;

    if curr_state = CHECKING then
      if mismatch = '1' then
        next_state <= FAIL;
      elsif curr_index = 7 and scl_pulse_i = '1' then
        next_state <= MATCH;
      end if;
    end if;

    if start_i = '1' then
      next_state <= CHECKING_START;
    end if;
  end process set_next_state;

  set_regs: process (clk_i) is
  begin  -- process set_regs
    if rising_edge(clk_i) then          -- rising clock edge
      if rst_in = '0' then              -- synchronous reset (active low)
        curr_state <= IDLE;
        curr_index <= 0;
        curr_read_rw <= '0';
      else
        curr_state <= next_state;
        curr_index <= next_index;
        curr_read_rw <= next_read_rw;
      end if;
    end if;
  end process set_regs;

end architecture a1;
