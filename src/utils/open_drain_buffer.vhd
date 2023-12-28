library ieee;
use ieee.std_logic_1164.all;

entity open_drain_buffer is

  port (
    pad_io   : inout std_logic;         -- The pad itself, will be set to 'Z'
                                        -- when enable_i = '0'
    enable_i : in    std_logic;         -- Whether to enable output, ie. set
                                        -- pad to '0' for enable_i = '1'
    state_o  : out   std_logic);        -- The state of the pad, relevant if
                                        -- enable_i = '0'

end entity open_drain_buffer;

architecture a1 of open_drain_buffer is

begin  -- architecture a1

  pad_io <= '0' when enable_i = '0' else
            'Z';

  state_o <= pad_io;

end architecture a1;
