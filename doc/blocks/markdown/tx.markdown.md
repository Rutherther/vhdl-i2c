| **Name**              | **Type**            | **Description** |
|-----------------------|---------------------|-----------------|
| clk_i                 | std_logic           |                 |
| rst_in                | std_logic           |                 |
| start_write_i         | std_logic           |                 |
| rst_i2c_i             | std_logic           |                 |
| clear_buffer_i        | std_logic           |                 |
| done_o                | std_logic           |                 |
| unexpected_sda_o      | std_logic           |                 |
| noack_o               | std_logic           |                 |
| scl_rising_i          | std_logic           |                 |
| scl_falling_delayed_i | std_logic           |                 |
| scl_stretch_o         | std_logic           |                 |
| sda_i                 | std_logic           |                 |
| sda_enable_o          | std_logic           |                 |
| ready_o               | std_logic           |                 |
| valid_i               | std_logic           |                 |
| write_data_i          | std_logic_vector[8] |                 |
