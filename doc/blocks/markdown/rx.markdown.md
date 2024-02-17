| **Name**              | **Type**            | **Description** |
|-----------------------|---------------------|-----------------|
| clk_i                 | std_logic           |                 |
| rst_in                | std_logic           |                 |
| start_read_i          | std_logic           |                 |
| rst_i2c_i             | std_logic           |                 |
| scl_rising            | std_logic           |                 |
| scl_falling_delayed_i | std_logic           |                 |
| scl_stretch_o         | std_logic           |                 |
| sda_i                 | std_logic           |                 |
| sda_enable_o          | std_logic           |                 |
| done_o                | std_logic           |                 |
| generate_ack_i        | std_logic           |                 |
| read_valid_o          | std_logic           |                 |
| read_ready_o          | std_logic           |                 |
| read_data_o           | std_logic_vector[8] |                 |
| confirm_read_i        | std_logic           |                 |
