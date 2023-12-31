library ieee;
use ieee.std_logic_1164.all;

entity address_generator is

  port (
    clk_i                 : in  std_logic;  -- Clock
    rst_in                : in  std_logic;  -- Synchronous reset (active low)
    address_i             : in  std_logic_vector(6 downto 0);
    rw_i                  : in  std_logic;  -- Read (not write)
    store_address_rw_i    : in  std_logic;
    start_i               : in  std_logic;  -- When to start sending the address.
                                            -- A pulse. Every time it's '1',
                                        -- address will be sent from beginning
                                        -- First bit on rising edge
    scl_rising_i          : in  std_logic;
    scl_falling_delayed_i : in  std_logic;
    sda_enable_o          : out std_logic;  -- Data of the address to send.
    sda_i                 : in  std_logic;
    noack_o               : out std_logic;
    unexpected_sda_o      : out std_logic;
    done_o                : out std_logic);
end entity address_generator;

architecture a1 of address_generator is
  type state_t is (IDLE, WAITING_FOR_FALLING, GEN, ACK);
  signal curr_state : state_t;
  signal next_state : state_t;

  signal curr_data : std_logic_vector(7 downto 0);
  signal next_data : std_logic_vector(7 downto 0);

  signal curr_index : integer range 0 to 8;
  signal next_index : integer range 0 to 8;

  signal curr_scl : std_logic;
  signal next_scl : std_logic;

  signal curr_done : std_logic;
  signal next_done : std_logic;
begin  -- architecture a1

  sda_enable_o <= not curr_data(7 - curr_index) when curr_index <= 7 and curr_state = GEN else
                  '0';

  next_data <= address_i & rw_i when store_address_rw_i = '1' else
               curr_data;

  next_index <= 0 when start_i = '1' else
                curr_index + 1 when curr_index < 8 and scl_falling_delayed_i = '1' and curr_state = GEN else
                curr_index;

  unexpected_sda_o <= '1' when curr_state = GEN and curr_index <= 6 and sda_i /= address_i(6 - curr_index) and scl_rising_i = '1' else '0';
  noack_o <= '1' when curr_state = ACK and scl_rising_i = '1' and sda_i = '1' else '0';

  next_scl <= '1' when scl_rising_i = '1' else
              '0' when scl_falling_delayed_i = '1' else
              curr_scl;

  done_o <= curr_done and not next_done;
  next_done <= '1' when curr_state = ACK and scl_rising_i = '1' else
               '1' when curr_done = '1' and scl_falling_delayed_i = '0' else
               '0';

  set_next_state: process (all) is
    variable start_gen : std_logic;
  begin  -- process set_next_state
    next_state <= curr_state;
    start_gen := '0';

    -- if curr_state = IDLE then
    if curr_state = WAITING_FOR_FALLING then
      if scl_falling_delayed_i = '1' then
        next_state <= GEN;
      end if;
    elsif curr_state = GEN then
      if curr_index = 8 then
        next_state <= ACK;
      end if;
    elsif curr_state = ACK and scl_rising_i = '1' then
      next_state <= IDLE;
    end if;

    if start_i = '1' then
      start_gen := '1';
    end if;

    if start_gen = '1' then
      if curr_scl = '1' then
        next_state <= WAITING_FOR_FALLING;
      else
        next_state <= GEN;
      end if;
    end if;
  end process set_next_state;

  set_regs: process (clk_i) is
  begin  -- process set_next
    if rising_edge(clk_i) then          -- rising clock edge
      if rst_in = '0' then              -- synchronous reset (active low)
        curr_state <= IDLE;
        curr_index <= 0;
        curr_scl <= '1';
        curr_done <= '0';
        curr_data <= (others => '0');
      else
        curr_state <= next_state;
        curr_index <= next_index;
        curr_scl <= next_scl;
        curr_done <= next_done;
        curr_data <= next_data;
      end if;
    end if;
  end process set_regs;

end architecture a1;
