-- i2c interface
    -- scl_pulse_i
    -- scl_stretch_o
    -- sda_o

-- control interface
    -- clk_i
    -- rst_in
    -- start_read_i

-- read interface
    -- read_valid_o
    -- read_ready_o
    -- read_data_o
    -- confirm_read_i
--
library ieee;
use ieee.std_logic_1164.all;

entity rx is

  port (
    -- control part
    clk_i          : in  std_logic;     -- Clock
    rst_in         : in  std_logic;     -- Reset (asynchronous)
    start_read_i   : in  std_logic;     -- Start reading with next scl_pulse
    ss_condition_i : in std_logic;    -- Reset rx circuitry

    scl_pulse_i    : in  std_logic;     -- SCL rising edge pulse
    scl_stretch_o  : out std_logic;     -- Stretch SCL (keep SCL 0)
    sda_i          : in  std_logic;     -- SDA data line state

    read_valid_o   : out std_logic;     -- Are there any data on read_data_o?
    read_ready_o   : out std_logic;     -- Is it possible to read anymore, or
                                        -- does data have to be read to flush buffer?
    read_data_o    : out std_logic_vector(7 downto 0);  -- The received data
    confirm_read_i : in  std_logic);    -- Confirm that data have been read

end entity rx;

architecture a1 of rx is
  -- IDLE - not doing anythign
  -- RECEIVING - currently receiving data to the buffer
  -- SAVING - trying to save to the read data output, waiting for data being
  -- read if cannot save
  -- SAVING_STRETCHING - waiting for data being read, should
  -- be sending already, but cannot, since the data are not read,
  -- so stretching SCL
  type rx_state_t is (IDLE, RECEIVING, SAVING, SAVING_STRETCHING);
  signal curr_state : rx_state_t;
  signal next_state : rx_state_t;

  -- Whether state = RECEIVING
  signal curr_receiving : std_logic;
  -- Whether state = SAVING or SAVING_STRETCHING
  signal curr_saving : std_logic;

  -- Whether the read data output is filled
  -- already (it's a register)
  signal curr_read_data_filled : std_logic;
  signal next_read_data_filled : std_logic;

  -- The received data
  signal curr_rx_buffer : std_logic_vector(7 downto 0);
  signal next_rx_buffer : std_logic_vector(7 downto 0);

  signal curr_read_data : std_logic_vector(7 downto 0);
  signal next_read_data : std_logic_vector(7 downto 0);
begin  -- architecture a1
  read_ready_o <= '1' when curr_state /= SAVING_STRETCHING and (curr_saving = '0' or curr_read_data_filled = '0') else '0';
  scl_stretch_o <= '1' when curr_state = SAVING_STRETCHING else '0';
  read_data_o <= curr_read_data;

  -- IDLE -> RECEIVING on start_read,
  -- RECEIVING -> RECEIVING when not received full data
  -- RECEIVING -> SAVING when received all data
  -- SAVING -> SAVING_STRETCHING when cannot overrode data AND start_read
  -- SAVING -> RECEIVING when start_read AND overriding data now
  -- SAVING -> SAVING when cannot override data (data not read yet)
  -- SAVING -> IDLE when can override data
  -- SAVING_STRETCHING -> SAVING_STRETCHING when data not read yet
  -- SAVING_STRETCHING -> RECEIVING when data read

  set_next_state: process(all) is
  begin  -- process set_next_state
    next_state <= curr_state;

    if curr_state = IDLE then
      if start_read_i = '1' then
        next_state <= RECEIVING;
      end if;
    elsif curr_state = RECEIVING then
      if curr_rx_buffer(7) = '1' and scl_pulse_i = '1' then
        next_state <= SAVING;
      end if;
    elsif curr_state = SAVING then
      if curr_read_data_filled = '0' then
        if start_read_i = '1' then
          next_state <= RECEIVING;
        else
          next_state <= IDLE;
        end if;
      elsif confirm_read_i = '1' then
        if start_read_i = '1' then
          next_state <= RECEIVING; -- skip SAVING_STRETCHING
        else
          next_state <= IDLE;
        end if;
      elsif start_read_i = '1' then
        next_state <= SAVING_STRETCHING;
      end if;
    elsif curr_state = SAVING_STRETCHING then
      if confirm_read_i = '1' then
        next_state <= RECEIVING;
      end if;
    end if;

    if ss_condition_i = '1' then
      if curr_saving = '1' and curr_read_data_filled = '1' then
        next_state <= SAVING;
      else
        next_state <= IDLE;
      end if;
    end if;
  end process set_next_state;

  curr_receiving <= '1' when curr_state = RECEIVING else '0';
  curr_saving <= '1' when curr_state = SAVING or curr_state = SAVING_STRETCHING else '0';

  read_valid_o <= curr_read_data_filled;

  -- TODO: (speedup by one cycle when saving?)
  next_read_data <= curr_rx_buffer when next_read_data_filled = '1' and curr_read_data_filled = '0' else
                    curr_rx_buffer when curr_read_data_filled = '1' and curr_saving = '1' and confirm_read_i = '1' else
                    curr_read_data when curr_read_data_filled = '1' else
                    (others => '0');

  next_read_data_filled <= '1' when curr_read_data_filled = '1' and confirm_read_i = '0' else
                           curr_saving when curr_read_data_filled = '1' and confirm_read_i = '1' else
                           '1' when curr_saving = '1' else
                           '0';

  next_rx_buffer <= curr_rx_buffer(6 downto 0) & sda_i when curr_receiving = '1' and scl_pulse_i = '1' else
                    curr_rx_buffer when curr_receiving = '1' else
                    curr_rx_buffer when curr_saving = '1' and confirm_read_i = '0' else
                    "00000001";

  set_regs: process (clk_i) is
  begin  -- process set_regs
    if rising_edge(clk_i) then          -- rising clock edge
      if rst_in = '0' then              -- synchronous reset (active low)
        curr_read_data <= (others => '0');
        curr_rx_buffer <= (others => '0');
        curr_read_data_filled <= '0';
        curr_state <= IDLE;
      else
        curr_read_data <= next_read_data;
        curr_rx_buffer <= next_rx_buffer;
        curr_read_data_filled <= next_read_data_filled;
        curr_state <= next_state;
      end if;
    end if;
  end process set_regs;

end architecture a1;
