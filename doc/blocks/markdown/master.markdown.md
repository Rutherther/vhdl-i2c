| **Name**            | **Type**            | **Description** |
|---------------------|---------------------|-----------------|
| clk_i               | std_logic           |                 |
| rst_in              | std_logic           |                 |
| slave_address_i     | std_logic_vector[7] |                 |
| generate_ack_i      | std_logic           |                 |
| expect_ack_i        | std_logic           |                 |
| rx_valid_o          | std_logic           |                 |
| rx_data_o           | std_logic_vector[8] |                 |
| rx_confirm_i        | std_logic           |                 |
| tx_ready_o          | std_logic           |                 |
| tx_valid_i          | std_logic           |                 |
| tx_data_i           | std_logic_vector[8] |                 |
| tx_clear_buffer_i   | std_logic           |                 |
| err_noack_data_o    | std_logic           |                 |
| err_noack_address_o | std_logic           |                 |
| err_arbitration_o   | std_logic           |                 |
| err_general_o       | std_logic           |                 |
| stop_i              | std_logic           |                 |
| start_i             | std_logic           |                 |
| run_i               | std_logic           |                 |
| rw_i                | std_logic           |                 |
| dev_busy_o          | std_logic           |                 |
| bus_busy_o          | std_logic           |                 |
| waiting_o           | std_logic           |                 |
| sda_i               | std_logic           |                 |
| scl_i               | std_logic           |                 |
| sda_enable_o        | std_logic           |                 |
| scl_enable_o        | std_logic           |                 |


| **Name**              | **Type** | **Default value** |
|-----------------------|----------|-------------------|
| SCL_FALLING_DELAY     | natural  |                   |
| SCL_MIN_STABLE_CYCLES |          |                   |