
-- i2c interface
    -- scl_pulse_i
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
  generic (
    DELAY_SDA_FOR : natural := 5);      -- How many cycles to delay setting SDA
                                        -- after falling edge of scl
  port (
    clk_i               : in  std_logic;
    rst_in              : in  std_logic;
    start_write_i       : in  std_logic;

    scl_rising_pulse_i  : in  std_logic;
    scl_falling_pulse_i : in  std_logic;

    scl_i               : in  std_logic;
    scl_stretch_o       : out std_logic;
    sda_o               : out std_logic;

    ready_o             : out std_logic;
    valid_i             : in  std_logic;
    write_data_i        : in  std_logic_vector(7 downto 0));

end entity tx;

architecture a1 of tx is
  -- IDLE - not doing anything
  -- SENDING - data are in the buffer, being sent
  -- WAITING_FOR_SEND there were data written to the buffer, but cannot send now
  -- WAITING_FOR_DATA should be sending, but there are no data - stretching
  type tx_state_t is (IDLE, WAITING_FOR_FALLING_EDGE, SENDING, WAITING_FOR_DATA);
  signal curr_state : tx_state_t;
  signal next_state : tx_state_t;

  type tx_buffers is array (0 to 1) of std_logic_vector(7 downto 0);
  signal curr_tx_buffers : tx_buffers;
  signal next_tx_buffers : tx_buffers;

  -- Index to save next new data to.
  signal curr_saving_buffer_index : integer range 0 to 1;
  signal next_saving_buffer_index : integer range 0 to 1;

  signal curr_tx_buffer_index : integer range 0 to 1;
  signal next_tx_buffer_index : integer range 0 to 1;

  signal curr_tx_buffers_filled : std_logic_vector(1 downto 0);
  signal next_tx_buffers_filled : std_logic_vector(1 downto 0);

  signal tx_buffer : std_logic_vector(7 downto 0);
  signal tx_buffer_filled : std_logic;

  signal curr_bit_index : integer range 0 to 7;
  signal next_bit_index : integer range 0 to 7;

  signal scl_delayed_pulse : std_logic;
  signal curr_scl : std_logic;
  signal next_scl : std_logic;

  signal ready : std_logic;
begin  -- architecture a1
  scl_falling_delay: entity utils.delay
    generic map (
      DELAY => DELAY_SDA_FOR)
    port map (
      clk_i   => clk_i,
      rst_in  => rst_in,
      signal_i => scl_falling_pulse_i,
      signal_o => scl_delayed_pulse);

  scl_stretch_o <= '1' when curr_state = WAITING_FOR_DATA else '0';
  ready_o <= ready;
  sda_o <= tx_buffer(curr_bit_index) when curr_state = SENDING else '1';

  ready <= '0' when curr_tx_buffers_filled(curr_saving_buffer_index) = '1' else '1';
  tx_buffer <= curr_tx_buffers(curr_tx_buffer_index);
  tx_buffer_filled <= curr_tx_buffers_filled(curr_tx_buffer_index);

  next_scl <= '1' when scl_rising_pulse_i = '1' else
              '0' when scl_falling_pulse_i = '1' else
              curr_scl;

  next_bit_index <= 0 when start_write_i = '1' else
                    (curr_bit_index + 1) mod 7 when curr_state = SENDING and scl_delayed_pulse = '1' else
                    0;

  next_tx_buffer_index <= (curr_tx_buffer_index + 1) mod 1 when curr_bit_index = 7 and scl_delayed_pulse = '1' else
                          curr_tx_buffer_index;

  next_saving_buffer_index <= (curr_saving_buffer_index + 1) mod 1 when ready = '1' and valid_i = '1' else
                              curr_saving_buffer_index;

  set_next_tx_buffers: process is
  begin  -- process set_next_tx_buffer
    next_tx_buffers <= curr_tx_buffers;
    if ready = '1' and valid_i = '1' then
      next_tx_buffers(curr_saving_buffer_index) <= write_data_i;
    end if;
  end process set_next_tx_buffers;

  set_next_buffer_filled: process is
  begin  -- process set_next_buffer_filled
    next_tx_buffers_filled <= curr_tx_buffers_filled;
    if curr_bit_index = 7 and scl_delayed_pulse = '1' then
      next_tx_buffers_filled(curr_tx_buffer_index) <= '0';
    end if;

    if ready = '1' and valid_i = '1' then
      next_tx_buffers_filled(curr_saving_buffer_index) <= '1';
    end if;
  end process set_next_buffer_filled;

  set_next_state: process(curr_state, scl_delayed_pulse, curr_scl, tx_buffer_filled, valid_i) is
    variable start_sending : std_logic := '0';
  begin  -- process set_next_state
    next_state <= curr_state;

    if curr_state = WAITING_FOR_FALLING_EDGE then
      if scl_delayed_pulse = '1' then
        next_state <= SENDING;
      end if;
    elsif curr_state = SENDING then
      if curr_bit_index = 7 and scl_delayed_pulse = '1' then
        next_state <= IDLE;
      end if;
    elsif curr_state = WAITING_FOR_DATA then
      if valid_i = '1' then
        start_sending := '1';
      end if;
    end if;

    if start_write_i = '1' then
      if tx_buffer_filled = '1' then
        start_sending := '1';
      else
        next_state <= WAITING_FOR_DATA;
      end if;
    end if;

    if start_sending = '1' then
      if curr_scl = '0' then
        next_state <= SENDING;
      else
        next_state <= WAITING_FOR_FALLING_EDGE;
      end if;
    end if;
  end process set_next_state;

  set_regs: process (clk_i) is
  begin  -- process set_next
    if rising_edge(clk_i) then          -- rising clock edge
      if rst_in = '0' then              -- synchronous reset (active low)
        curr_state <= IDLE;
        curr_tx_buffers <= (others => (others => '0'));
        curr_tx_buffer_index <= 0;
        curr_tx_buffers_filled <= "00";
        curr_bit_index <= 0;
        curr_scl <= '1';                -- assume 1 (the default, no one transmitting)
      else
        curr_state <= next_state;
        curr_tx_buffers <= next_tx_buffers;
        curr_tx_buffer_index <= next_tx_buffer_index;
        curr_tx_buffers_filled <= next_tx_buffers_filled;
        curr_bit_index <= next_bit_index;
        curr_scl <= next_scl;
      end if;
    end if;
  end process set_regs;

end architecture a1;
