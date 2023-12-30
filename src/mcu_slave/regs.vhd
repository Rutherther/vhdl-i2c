library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library utils;
library i2c;

entity regs is
  generic (
    DELAY : integer := 15);

  port (
    clk_i  : in std_logic;
    rst_i : in std_logic;
    rst_on : out std_logic;
    err_noack_o : out std_logic;
    bus_busy_o : out std_logic;
    dev_busy_o : out std_logic;
    sda_io : inout std_logic;
    scl_io : inout std_logic);

end entity regs;

architecture a1 of regs is
  constant ADDRESS : std_logic_vector(6 downto 0) := "1110101";

  constant REGS_COUNT : integer := 20;
  type regs_t is array (0 to REGS_COUNT - 1) of std_logic_vector(7 downto 0);
  signal curr_regs : regs_t;
  signal next_regs : regs_t;

  signal rst_n : std_logic;

  signal sda, scl : std_logic;
  signal sda_enable, scl_enable : std_logic;

  signal tx_valid, tx_ready, tx_clear_buffer : std_logic;
  signal tx_data : std_logic_vector(7 downto 0);

  signal rx_valid, rx_confirm : std_logic;
  signal rx_data : std_logic_vector(7 downto 0);

  signal curr_reg_address_filled : std_logic;
  signal next_reg_address_filled : std_logic;

  signal curr_reg_address : unsigned(7 downto 0);
  signal next_reg_address : unsigned(7 downto 0);

  signal dev_busy : std_logic;

  signal curr_dev_busy : std_logic;
  signal next_dev_busy : std_logic;

  signal rw : std_logic;
begin
  rst_n <= not rst_i;
  rst_on <= not rst_i;
  dev_busy_o <= dev_busy;

  next_dev_busy <= dev_busy;

  next_reg_address_filled <= '0' when curr_dev_busy = '0' and dev_busy = '1' and rw = '0' else
                             '1' when curr_reg_address_filled = '0' and rx_valid = '1' else
                             curr_reg_address_filled;

  rx_confirm <= rx_valid;

  next_reg_address <= unsigned(rx_data) when rx_valid = '1' and curr_reg_address_filled = '0' else
                      (curr_reg_address + 1) mod REGS_COUNT when rx_valid = '1' else
                      (curr_reg_address + 1) mod REGS_COUNT when tx_valid = '1' and dev_busy = '1' and rw = '1' else
                      curr_reg_address;

  tx_clear_buffer <= not curr_reg_address_filled;
  tx_data <= curr_regs(to_integer(curr_reg_address));
  tx_valid <= '1' when tx_ready = '1' and dev_busy = '1' and rw = '1' else
              '0';

  set_next_regs: process (all) is
  begin  -- process set_next_regs
    next_regs <= curr_regs;

    if rx_valid = '1' and curr_reg_address_filled = '1' then
      next_regs(to_integer(curr_reg_address)) <= rx_data;
    end if;
  end process set_next_regs;

  i2c_slave: entity i2c.slave
    generic map (
      SCL_FALLING_DELAY => DELAY)
    port map (
      clk_i          => clk_i,
      rst_in         => rst_n,
      address_i      => ADDRESS,
      generate_ack_i => '1',
      expect_ack_i   => '1',

      rx_valid_o     => rx_valid,
      rx_data_o      => rx_data,
      rx_confirm_i   => rx_confirm,
      rx_stretch_i   => '0',

      tx_ready_o     => tx_ready,
      tx_valid_i     => tx_valid,
      tx_data_i      => tx_data,
      tx_stretch_i   => '0',
      tx_clear_buffer_i => tx_clear_buffer,

      err_noack_o    => err_noack_o,
      rw_o           => rw,
      dev_busy_o     => dev_busy,
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
        curr_reg_address_filled <= '0';
        curr_dev_busy <= '0';
        curr_reg_address <= "00000000";
        curr_regs <= (others => (others => '0'));
      else
        curr_reg_address_filled <= next_reg_address_filled;
        curr_dev_busy <= next_dev_busy;
        curr_reg_address <= next_reg_address;
        curr_regs <= next_regs;
      end if;
    end if;
  end process set_regs;

end architecture a1;
