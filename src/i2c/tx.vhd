
-- i2c interface
    -- scl_rising
    -- scl_stretch_o
    -- sda_o

-- control interface
    -- clk_i
    -- rst_in
    -- start_write_i

-- write interface
-- ready_o
-- valid_i
-- write_data

library ieee;
use ieee.std_logic_1164.all;

library utils;

entity tx is
  port (
    clk_i               : in  std_logic;
    rst_in              : in  std_logic;
    start_write_i       : in  std_logic;
    rst_i2c_i           : in  std_logic;    -- Reset rx circuitry
    clear_buffer_i      : in  std_logic;
    done_o         : out std_logic;

    unexpected_sda_o    : out std_logic;
    noack_o             : out std_logic;

    scl_rising_i  : in  std_logic;
    scl_falling_delayed_i : in  std_logic;

    scl_stretch_o       : out std_logic;
    sda_i               : in  std_logic;
    sda_enable_o        : out std_logic;

    ready_o             : out std_logic;
    valid_i             : in  std_logic;
    write_data_i        : in  std_logic_vector(7 downto 0));

end entity tx;

architecture a1 of tx is
  -- IDLE - not doing anything
  -- SENDING - data are in the buffer, being sent
  -- WAITING_FOR_SEND there were data written to the buffer, but cannot send now
  -- WAITING_FOR_DATA should be sending, but there are no data - stretching
  type tx_state_t is (IDLE, WAITING_FOR_FALLING_EDGE, SENDING, ACK, WAITING_FOR_DATA);
  signal curr_state : tx_state_t;
  signal next_state : tx_state_t;

  type tx_buffers is array (0 to 1) of std_logic_vector(8 downto 0);
  signal curr_tx_buffers : tx_buffers;
  signal next_tx_buffers : tx_buffers;

  -- Index to save next new data to.
  signal curr_saving_buffer_index : integer range 0 to 1;
  signal next_saving_buffer_index : integer range 0 to 1;

  signal curr_tx_buffer_index : integer range 0 to 1;
  signal next_tx_buffer_index : integer range 0 to 1;

  signal curr_tx_buffers_filled : std_logic_vector(1 downto 0);
  signal next_tx_buffers_filled : std_logic_vector(1 downto 0);

  signal curr_done : std_logic;
  signal next_done : std_logic;

  signal tx_buffer : std_logic_vector(8 downto 0);
  signal tx_buffer_filled : std_logic;

  signal curr_scl : std_logic;
  signal next_scl : std_logic;

  signal ready : std_logic;
begin  -- architecture a1
  scl_stretch_o <= '1' when curr_state = WAITING_FOR_DATA else '0';
  ready_o <= ready;
  sda_enable_o <= not tx_buffer(8) when curr_state = SENDING else '0';
  unexpected_sda_o <= '1' when curr_state = SENDING and sda_i /= tx_buffer(8) and scl_rising_i = '1' else '0';
  noack_o <= '1' when curr_state = ACK and sda_i = '1' and scl_rising_i = '1' else '0';

  ready <= '0' when curr_tx_buffers_filled(curr_saving_buffer_index) = '1' else '1';
  tx_buffer <= curr_tx_buffers(curr_tx_buffer_index);
  tx_buffer_filled <= curr_tx_buffers_filled(curr_tx_buffer_index);

  next_scl <= '1' when scl_rising_i = '1' else
              '0' when scl_falling_delayed_i = '1' else
              curr_scl;

  next_tx_buffer_index <= (curr_tx_buffer_index + 1) mod 2 when tx_buffer(7 downto 0) = "10000000" and scl_falling_delayed_i = '1' else
                          curr_tx_buffer_index;

  next_saving_buffer_index <= (curr_saving_buffer_index + 1) mod 2 when ready = '1' and valid_i = '1' else
                              curr_saving_buffer_index;

  done_o <= curr_done and not next_done;
  next_done <= '1' when curr_state = ACK and next_state /= ACK else
               '1' when curr_done = '1' and scl_falling_delayed_i = '0' else
               '0';

  set_next_tx_buffers: process(all) is
  begin  -- process set_next_tx_buffer
    next_tx_buffers <= curr_tx_buffers;
    if ready = '1' and valid_i = '1' then
      next_tx_buffers(curr_saving_buffer_index) <= write_data_i & '1';
    end if;

    if curr_state = SENDING and scl_falling_delayed_i = '1' then
      next_tx_buffers(curr_tx_buffer_index) <= tx_buffer(7 downto 0) & '0';
    end if;
  end process set_next_tx_buffers;

  set_next_buffer_filled: process(all) is
  begin  -- process set_next_buffer_filled
    next_tx_buffers_filled <= curr_tx_buffers_filled;
    if tx_buffer(7 downto 0) = "10000000" and scl_falling_delayed_i = '1' then
      next_tx_buffers_filled(curr_tx_buffer_index) <= '0';
    end if;

    if ready = '1' and valid_i = '1' then
      next_tx_buffers_filled(curr_saving_buffer_index) <= '1';
    end if;
  end process set_next_buffer_filled;

  set_next_state: process(all) is
    variable start_sending : std_logic := '0';
    variable override_tx_buffer_filled : std_logic;
  begin  -- process set_next_state
    start_sending := '0';
    next_state <= curr_state;
    override_tx_buffer_filled := tx_buffer_filled;

    if curr_state = IDLE then
      if start_write_i = '1' then
        start_sending := '1';
      end if;
    elsif curr_state = WAITING_FOR_FALLING_EDGE then
      if scl_falling_delayed_i = '1' then
        next_state <= SENDING;
      end if;
    elsif curr_state = SENDING then
      if tx_buffer(7 downto 0) = "10000000" and scl_falling_delayed_i = '1' then
        next_state <= ACK;
      end if;
    elsif curr_state = ACK then
      if scl_rising_i = '1' then
        if start_write_i = '1' then
          override_tx_buffer_filled := curr_tx_buffers_filled(next_tx_buffer_index);
          start_sending := '1';
        else
          next_state <= IDLE;
        end if;
      end if;
    elsif curr_state = WAITING_FOR_DATA then
      if valid_i = '1' then
        start_sending := '1';
      end if;
    end if;

    if start_sending = '1' then
      if override_tx_buffer_filled = '0' and valid_i = '0' then
        next_state <= WAITING_FOR_DATA;
      elsif curr_scl = '0' and scl_rising_i = '0' then
        next_state <= SENDING;
      else
        next_state <= WAITING_FOR_FALLING_EDGE;
      end if;
    end if;

  end process set_next_state;

  set_regs: process (clk_i) is
  begin  -- process set_next
    if rising_edge(clk_i) then          -- rising clock edge
      if rst_in = '0' or clear_buffer_i = '1' then  -- synchronous reset (active low)
        curr_state <= IDLE;
        curr_tx_buffers <= (others => (others => '0'));
        curr_tx_buffer_index <= 0;
        curr_tx_buffers_filled <= "00";
        curr_saving_buffer_index <= 0;
        curr_scl <= '1';                -- assume 1 (the default, no one transmitting)
      elsif rst_i2c_i = '1' then
        curr_state <= IDLE;
        curr_scl <= '1';                -- assume 1 (the default, no one transmitting)
      else
        curr_state <= next_state;
        curr_tx_buffers <= next_tx_buffers;
        curr_tx_buffer_index <= next_tx_buffer_index;
        curr_tx_buffers_filled <= next_tx_buffers_filled;
        curr_saving_buffer_index <= next_saving_buffer_index;
        curr_scl <= next_scl;
      end if;
    end if;
  end process set_regs;

end architecture a1;
