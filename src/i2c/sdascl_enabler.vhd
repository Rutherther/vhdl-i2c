library ieee;
use ieee.std_logic_1164.all;

library utils;

entity sdascl_enabler is
  generic (
    DELAY : natural);

  port (
    clk_i          : in  std_logic;
    rst_in         : in  std_logic;

    scl_i : in std_logic;
    sda_i : in std_logic;

    scl_falling_pulse_i : in std_logic;

    transmitting_i : in  std_logic;
    receiving_i    : in  std_logic;

    expects_ack_i  : in  std_logic;
    generate_ack_i : in  std_logic;

    tx_sda_i         : in std_logic;
    tx_scl_stretch_i : in std_logic;
    rx_scl_stretch_i : in std_logic;

    sda_enable_o   : out std_logic;
    scl_enable_o   : out std_logic);

end entity sdascl_enabler;

architecture a1 of sdascl_enabler is
  type state_t is (TRANSMITTING, RECEIVING, EXPECTS_ACK, GENERATE_ACK, NONE);
  signal curr_state : state_t;
  signal next_state : state_t;

  signal curr_scl_enable : std_logic := '0';
  signal next_scl_enable : std_logic;

  signal any_stretch : std_logic;
  signal should_start_stretch : std_logic;

  signal delayed_scl_pulse : std_logic;
begin  -- architecture a1
  scl_falling_delay: entity utils.delay
    generic map (
      DELAY => DELAY)
    port map (
      clk_i   => clk_i,
      rst_in  => rst_in,
      signal_i => scl_falling_pulse_i,
      signal_o => delayed_scl_pulse);

  scl_enable_o <= curr_scl_enable;
  sda_enable_o <= '0' when curr_state = EXPECTS_ACK else
                  '1' when curr_state = GENERATE_ACK else
                  not tx_sda_i when curr_state = TRANSMITTING else
                  '0';

  any_stretch <= '1' when
                    (tx_scl_stretch_i = '1' and transmitting_i = '1') or
                    (rx_scl_stretch_i = '1' and receiving_i = '1')
                 else '0';
  should_start_stretch <= '1' when any_stretch = '1' and scl_i = '0' else '0';

  next_scl_enable <= '1' when should_start_stretch = '1' else
                     '0' when any_stretch = '0' else
                     curr_scl_enable;

  next_state <= TRANSMITTING when transmitting_i = '1' and delayed_scl_pulse = '1' else
                RECEIVING when receiving_i = '1' and delayed_scl_pulse = '1'else
                EXPECTS_ACK when expects_ack_i = '1' and delayed_scl_pulse = '1'else
                GENERATE_ACK when generate_ack_i = '1' and delayed_scl_pulse = '1'else
                curr_state;

  set_regs: process (clk_i) is
  begin  -- process set_regs
    if rising_edge(clk_i) then          -- rising clock edge
      if rst_in = '0' then              -- synchronous reset (active low)
        curr_state <= NONE;
        curr_scl_enable <= '0';
      else
        curr_state <= next_state;
        curr_scl_enable <= next_scl_enable;
      end if;
    end if;
  end process set_regs;

end architecture a1;
