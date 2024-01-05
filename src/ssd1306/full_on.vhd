library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library i2c;
library utils;

entity full_on is

  generic (
    CLK_FREQ       : integer   := 100000000;  -- Input clock frequency
    I2C_CLK_FREQ   : integer   := 5000000;
    DELAY : integer := 20;

    SCL_MIN_STABLE_CYCLES : natural := 50);

  port (
    clk_i  : in std_logic;
    rst_i : in std_logic;
    
    start_i : in std_logic;

    err_noack_data_o : out std_logic;
    err_noack_address_o : out std_logic;
    err_arbitration_o : out std_logic;
    err_general_o : out std_logic;
    
    full_on_state_o : out std_logic_vector(2 downto 0);

    bus_busy_o : out std_logic;
    dev_busy_o : out std_logic;
    waiting_o : out std_logic;

    sda_io : inout std_logic;
    scl_io : inout std_logic);

end entity full_on;

architecture a1 of full_on is
  constant ADDRESS : std_logic_vector(6 downto 0) := "0111100";

  type data_arr_t is array (natural range <>) of std_logic_vector(7 downto 0);
  constant INIT_DATA : data_arr_t := (
    X"80", X"A8",  X"80", X"3F",
    X"80", X"D3", X"80", X"00",
    X"80", X"40",
    X"80", X"A0",
    X"80", X"C0",
    X"80", X"DA", X"80", X"02",
    X"80", X"81", X"80", X"7F",
    X"80", X"A4",
    X"80", X"A6",
    X"80", X"D5", X"80", X"80",
    X"80", X"8D", X"80", X"14",
    X"80", X"AF", -- init done
    X"80", X"A5" --entire display on
  );

  signal rst_n : std_logic;
  signal rst_sync : std_logic;

  signal i2c_clk : std_logic;

  signal master_start, master_stop, master_run : std_logic;
  signal rw : std_logic;

  signal tx_valid, tx_ready, tx_clear_buffer : std_logic;
  signal tx_data : std_logic_vector(7 downto 0);

  signal rx_valid, rx_confirm : std_logic;
  signal rx_data : std_logic_vector(7 downto 0);

  signal waiting : std_logic;

  signal sda, scl : std_logic;
  signal sda_enable, scl_enable : std_logic;

  signal curr_index : natural;
  signal next_index : natural;
  signal go_next : std_logic;

  type state_t is (IDLE, START, COUNT, STOP, DONE);
  signal curr_state : state_t;
  signal next_state : state_t;
begin  -- architecture a1
  tx_clear_buffer <= '0';
  master_run <= '1';
  rst_n <= not rst_sync;
  waiting_o <= waiting;
  -- i2c_clk <= clk_i;

  rw <= '0';
  
  full_on_state_o <= std_logic_vector(to_unsigned(state_t'pos(curr_state), 3));


  next_index <= 0 when curr_state = IDLE else
                (curr_index + 1) when go_next = '1' else
                curr_index;

  go_next <= '1' when tx_ready = '1' and curr_index < INIT_DATA'length and curr_state = COUNT else '0';


  tx_valid <= '1' when go_next = '1' else '0';
  tx_data <= INIT_DATA(curr_index) when curr_index < INIT_DATA'length else "00000000";

  next_state <= START when start_i = '1' and curr_state = IDLE else
                COUNT when curr_state = START else
                STOP when curr_state = COUNT and curr_index = INIT_DATA'length and waiting = '1' else
                DONE when curr_state = STOP else
                IDLE when curr_state = DONE and start_i = '0' else
                curr_state;

  master_start <= '1' when curr_state = START else '0';
  master_stop <= '1' when curr_state = STOP else '0';
  
  divider: entity utils.clock_divider
    generic map (
      IN_FREQ  => CLK_FREQ,
      OUT_FREQ => I2C_CLK_FREQ)
    port map (
      clk_i    => clk_i,
      clk_o    => i2c_clk);

  i2c_master: entity i2c.master
    generic map (
      SCL_FALLING_DELAY     => DELAY,
      SCL_MIN_STABLE_CYCLES => SCL_MIN_STABLE_CYCLES)
    port map (
      clk_i               => i2c_clk,
      rst_in              => rst_n,
--
      slave_address_i     => ADDRESS,
--
      generate_ack_i      => '1',
      expect_ack_i        => '1',
--
      rx_valid_o          => rx_valid,
      rx_data_o           => rx_data,
      rx_confirm_i        => rx_confirm,
--
      tx_ready_o          => tx_ready,
      tx_valid_i          => tx_valid,
      tx_data_i           => tx_data,
      tx_clear_buffer_i   => tx_clear_buffer,
--
      err_noack_data_o    => err_noack_data_o,
      err_noack_address_o => err_noack_address_o,
      err_arbitration_o   => err_arbitration_o,
      err_general_o       => err_general_o,
--
      stop_i              => master_stop,
      start_i             => master_start,
      run_i               => master_run,
      rw_i                => rw,
--
      dev_busy_o          => dev_busy_o,
      bus_busy_o          => bus_busy_o,
      waiting_o           => waiting,
--
      sda_i               => sda,
      scl_i               => scl,
      sda_enable_o        => sda_enable,
      scl_enable_o        => scl_enable);

  sync_reset: entity utils.metastability_filter
    port map (
      clk_i    => clk_i,
      signal_i => rst_i,
      signal_o => rst_sync);

  sda_open_buffer: entity utils.open_drain_buffer
    port map (
      pad_io   => sda_io,
      enable_i => sda_enable,
      state_o  => sda);
  scl_open_buffer: entity utils.open_drain_buffer
    port map (
      pad_io   => scl_io,
      enable_i => scl_enable,
      state_o  => scl);

  set_regs: process (i2c_clk) is
  begin  -- process set_regs
    if rising_edge(i2c_clk) then          -- rising clock edge
      if rst_n = '0' then              -- synchronous reset (active low)
        curr_state <= IDLE;
        curr_index <= 0;
      else
        curr_state <= next_state;
        curr_index <= next_index;
      end if;
    end if;
  end process set_regs;

end architecture a1;
