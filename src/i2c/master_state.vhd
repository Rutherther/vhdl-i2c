library ieee;
use ieee.std_logic_1164.all;

entity master_state is

  port (
    clk_i                    : in  std_logic;
    rst_in                   : in  std_logic;
    rst_i2c_o                : out std_logic;
-- control interface
    start_i                  : in  std_logic;
    stop_i                   : in  std_logic;
    run_i                    : in  std_logic;
    rw_i                     : in  std_logic;
-- error inputs and config
    expect_ack_i             : in  std_logic;
    noack_address_i          : in  std_logic;
    noack_data_i             : in  std_logic;
    unexpected_sda_address_i : in  std_logic;
    unexpected_sda_data_i    : in  std_logic;
-- error outputs (reset on new run)
    err_noack_address_o      : out std_logic;
    err_noack_data_o         : out std_logic;
    err_arbitration_o        : out std_logic;
    err_general_o            : out std_logic;
-- i2c condition detection
    start_condition_i        : in  std_logic;
    stop_condition_i         : in  std_logic;
-- rx, tx comms
    waiting_for_data_i       : in std_logic;
    rx_done_i                : in std_logic;
    tx_done_i                : in std_logic;
-- data for address_generator
    address_gen_start_o      : out std_logic;
    address_gen_done_i       : out std_logic;
-- data for cond generator
    req_start_o              : out std_logic;
    req_stop_o               : out std_logic;
    req_cond_done_i          : in  std_logic;
-- data for scl generator
    req_scl_continuous_o     : out std_logic;
-- active component
    cond_gen_o               : out std_logic;
    address_gen_o            : out std_logic;
    receive_o                : out std_logic;
    transmit_o               : out std_logic;
    bus_busy_o               : out std_logic);

end entity master_state;

architecture a1 of master_state is
  type state_t is (
    IDLE,
    GENERATING_START,                   -- requesting start condition
    GENERATED_START,                    -- start condition generated, waiting
                                        -- for gen done
    GENERATING_ADDRESS,
    TRANSMITTING,
    RECEIVING,
    GENERATING_STOP,
    GENERATED_STOP,
    BUS_BUSY,
    ERR);

  signal curr_state : state_t;
  signal next_state : state_t;

  signal curr_err_arbitration : std_logic;
  signal next_err_arbitration : std_logic;

  signal curr_err_noack_data : std_logic;
  signal next_err_noack_data : std_logic;

  signal curr_err_noack_address : std_logic;
  signal next_err_noack_address : std_logic;

  signal curr_err_general : std_logic;
  signal next_err_general : std_logic;

  signal curr_gen_start_req : std_logic;
  signal next_gen_start_req : std_logic;

  signal curr_gen_stop_req : std_logic;
  signal next_gen_stop_req : std_logic;

  signal any_err, any_terminal_err : std_logic;
  signal control_over_bus : std_logic;
  signal can_gen_cond : std_logic;
begin  -- architecture a1
  any_err <= curr_err_arbitration or curr_err_noack_data or curr_err_noack_address or curr_err_general;
  any_terminal_err <= curr_err_noack_data or curr_err_noack_address or curr_err_general;
  control_over_bus <= '1' when curr_state /= IDLE and curr_state /= BUS_BUSY;
  can_gen_cond <= '1' when curr_state = IDLE or waiting_for_data_i = '1' or tx_done_i = '1' or rx_done_i = '1' else '0';

  req_scl_continuous_o <= '1' when curr_state = GENERATING_ADDRESS or
                          curr_state = TRANSMITTING or curr_state = RECEIVING else '0';

  req_start_o <= '1' when curr_state = GENERATING_START or curr_state = GENERATED_START else '0';
  req_stop_o <= '1' when curr_state = GENERATING_STOP or curr_state = GENERATED_STOP else '0';

  address_gen_start_o <= '1' when curr_state = GENERATED_START and next_state = GENERATING_ADDRESS else '0';

  receive_o <= '1' when curr_state = RECEIVING else '0';
  transmit_o <= '1' when curr_state = TRANSMITTING else '0';
  address_gen_o <= '1' when curr_state = GENERATING_ADDRESS else '0';
  bus_busy_o <= '1' when curr_state = BUS_BUSY else '0';

  err_noack_address_o <= curr_err_noack_address;
  err_noack_data_o <= curr_err_noack_data;
  err_arbitration_o <= curr_err_arbitration;
  err_general_o <= curr_err_general;

  cond_gen_o <= '1' when
                curr_state = GENERATING_STOP or curr_state = GENERATED_STOP or
                curr_state = GENERATING_START or curr_state = GENERATED_START else '0';

  rst_i2c_o <= any_err;

  next_gen_start_req <= '1' when start_i = '1' else
                        '0' when next_state = GENERATING_START else
                        curr_gen_start_req;

  next_gen_stop_req <= '1' when stop_i = '1' else
                        '0' when next_state = GENERATING_STOP else
                        curr_gen_stop_req;

  next_err_general <= '0' when start_condition_i = '1' else
                      '1' when curr_err_general = '1' else
                      '1' when curr_state = GENERATING_STOP and start_condition_i = '1' else
                      '1' when curr_state = GENERATING_START and stop_condition_i = '1' else
                      '1' when curr_state /= GENERATING_STOP and control_over_bus = '1' and stop_condition_i = '1' else
                      '1' when curr_state /= GENERATING_START and control_over_bus = '1' and start_condition_i = '1' else
                      '1' when curr_state = ERR else
                      '0';

  next_err_arbitration <= '0' when start_condition_i = '1' else
                          '1' when curr_err_arbitration = '1' else
                          '1' when unexpected_sda_data_i = '1' and curr_state = TRANSMITTING else
                          '1' when unexpected_sda_address_i = '1' and curr_state = GENERATING_ADDRESS else
                          '0';

  next_err_noack_data <= '0' when start_condition_i = '1' else
                         '1' when curr_err_noack_data = '1' else
                         '1' when noack_data_i = '1' and curr_state = TRANSMITTING and expect_ack_i = '1' else
                         '0';

  next_err_noack_address <= '0' when start_condition_i = '1' else
                            '1' when curr_err_noack_address = '1' else
                            '1' when noack_address_i = '1' and curr_state = TRANSMITTING and expect_ack_i = '1' else
                            '0';

  set_next_state: process (all) is
  begin  -- process set_next_state
    next_state <= curr_state;

    if curr_state = IDLE then
      -- not much to do,
      -- condition for start
      -- is at the end
    elsif curr_state = GENERATING_START then
      if start_condition_i = '1' then
        next_state <= GENERATED_START;
      elsif req_cond_done_i = '1' then
        -- done before cond generated?
        -- That's not right...
        next_state <= ERR;
      end if;
    elsif curr_state = GENERATED_START then
      if any_terminal_err = '1' then
        next_state <= GENERATING_STOP;
      elsif req_cond_done_i = '1' then
        next_state <= GENERATING_ADDRESS;
      end if;
    elsif curr_state = GENERATING_ADDRESS then
      if any_terminal_err = '1' then
        next_state <= GENERATING_STOP;
      elsif address_gen_done_i = '1' then
        if any_err = '1' then
          next_state <= GENERATING_STOP;
        elsif rw_i = '1' then
          next_state <= TRANSMITTING;
        else
          next_state <= RECEIVING;
        end if;
      end if;
    elsif curr_state = TRANSMITTING then
      if any_terminal_err = '1' then
        next_state <= GENERATING_STOP;
      end if;
    elsif curr_state = RECEIVING then
      if any_terminal_err = '1' then
        next_state <= GENERATING_STOP;
      end if;
    elsif curr_state = GENERATING_STOP then
      if stop_condition_i = '1' then
        next_state <= GENERATING_STOP;
      elsif req_cond_done_i = '1' then
        -- done before cond generated?
        -- That's not right...
        next_state <= ERR;
      end if;
    elsif curr_state = GENERATED_STOP then
      if req_cond_done_i = '1' then
        next_state <= IDLE;
      end if;
    elsif curr_state = ERR then
      -- not much to do
      -- This state should not be possible
      -- if the components in i2c master are
      -- behaving correctly
    end if;

    if can_gen_cond = '1' then
      if curr_gen_start_req = '1' then
        next_state <= GENERATING_START;
        -- if no control over bus, do not
        -- allow generating stop condition
        -- TODO consider not checking that?
      elsif curr_gen_stop_req = '1' and control_over_bus = '1' then
        next_state <= GENERATING_STOP;
      end if;
    end if;

    if run_i = '0' then
      next_state <= IDLE;
    end if;
  end process set_next_state;

  set_regs: process (clk_i) is
  begin  -- process set_regs
    if rising_edge(clk_i) then          -- rising clock edge
      if rst_in = '0' then              -- synchronous reset (active low)
        curr_state <= IDLE;
        curr_err_arbitration <= '0';
        curr_err_noack_data <= '0';
        curr_err_noack_address <= '0';
        curr_err_general <= '0';
        curr_gen_start_req <= '0';
        curr_gen_stop_req <= '0';
      else
        curr_state <= curr_state;
        curr_err_arbitration <= curr_err_arbitration;
        curr_err_noack_data <= curr_err_noack_data;
        curr_err_noack_address <= curr_err_noack_address;
        curr_err_general <= curr_err_general;
        curr_gen_start_req <= curr_gen_start_req;
        curr_gen_stop_req <= curr_gen_stop_req;
      end if;
    end if;
  end process set_regs;

end architecture a1;
