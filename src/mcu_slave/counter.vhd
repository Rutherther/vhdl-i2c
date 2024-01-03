library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library utils;
library i2c;

entity counter is

  generic (
    DELAY : integer := 15;
    MAX : integer := 100);

  port (
    clk_i  : in std_logic;
    rst_i : in std_logic;
    rst_on : out std_logic;
    err_noack_o : out std_logic;
    bus_busy_o : out std_logic;
    dev_busy_o : out std_logic;
    sda_io : inout std_logic;
    scl_io : inout std_logic);

end entity counter;

architecture a1 of counter is
  constant ADDRESS : std_logic_vector(6 downto 0) := "1110100";
  signal curr_count : unsigned(7 downto 0);
  signal next_count : unsigned(7 downto 0);

  signal go_next : std_logic;

  signal rst_n : std_logic;
  signal rst_sync : std_logic;

  signal sda, scl : std_logic;
  signal sda_enable, scl_enable : std_logic;

  signal tx_valid, tx_ready : std_logic;
  signal tx_data : std_logic_vector(7 downto 0);
begin
  rst_n <= not rst_sync;
  rst_on <= rst_n;

  sync_reset: entity utils.metastability_filter
    port map (
      clk_i    => clk_i,
      signal_i => rst_i,
      signal_o => rst_sync);

  next_count <= (curr_count + 1) mod MAX when go_next = '1' else
                curr_count;

  go_next <= tx_ready;

  tx_valid <= tx_ready;
  tx_data <= std_logic_vector(curr_count);

  i2c_slave: entity i2c.slave
    generic map (
      SCL_FALLING_DELAY => DELAY)
    port map (
      clk_i          => clk_i,
      rst_in         => rst_n,
      address_i      => ADDRESS,
      generate_ack_i => '1',
      expect_ack_i   => '1',

      rx_valid_o     => open,
      rx_data_o      => open,
      rx_confirm_i   => '1',
      rx_stretch_i   => '0',

      tx_ready_o     => tx_ready,
      tx_valid_i     => tx_valid,
      tx_data_i      => tx_data,
      tx_stretch_i   => '0',
      tx_clear_buffer_i => '0',

      err_noack_o    => err_noack_o,
      rw_o           => open,
      dev_busy_o     => dev_busy_o,
      bus_busy_o     => bus_busy_o,
      sda_i          => sda,
      scl_i          => scl,
      sda_enable_o   => sda_enable,
      scl_enable_o   => scl_enable);

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

  set_regs: process (clk_i) is
  begin  -- process set_regs
    if rising_edge(clk_i) then          -- rising clock edge
      if rst_n = '0' then              -- synchronous reset (active low)
        curr_count <= "00000000";
      else
        curr_count <= next_count;
      end if;
    end if;
  end process set_regs;

end architecture a1;
