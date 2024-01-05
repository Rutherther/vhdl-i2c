library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ssd1306_pkg is

  constant DISPLAY_WIDTH : unsigned(7 downto 0) := to_unsigned(128, 8);
  constant DISPLAY_HEIGHT : unsigned(7 downto 0) := to_unsigned(64, 8);

  type data_arr_t is array (natural range <>) of std_logic_vector(7 downto 0);

  constant SSD1306_INIT : data_arr_t := (
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
    X"80", X"AF" -- init done
  );

  constant SSD1306_HORIZONTAL_ADDRESSING_MODE : data_arr_t := (
    X"80", X"20", -- set addressing mode
    X"80", X"00"         -- horizontal
  );

  constant SSD1306_CURSOR_TO_ZERO : data_arr_t := (
    X"80", X"21", -- set column address
    X"80", X"00", -- set first address
    X"80", X"7F", -- set last address

    X"80", X"22", -- set page address
    X"80", X"00", -- start
    X"80", X"07"  -- end
  );

  constant SSD1306_ZERO_LEN : integer := 1025;
  constant SSD1306_ZERO : data_arr_t := (
    X"40", X"00"
  );

  -----------------------------------------------------------------------------
  -- 8x8 characters obtained from https://github.com/dhepper/font8x8
  -----------------------------------------------------------------------------

  -- contains beginning of i2c packet
  -- (0x40) to signal only data will follow

constant SSD1306_CHAR_0 : data_arr_t(0 to 8) := (
  X"40",
  X"3E", X"7F", X"71", X"59",
  X"4D", X"7F", X"3E", X"00"
);
constant SSD1306_CHAR_1 : data_arr_t(0 to 8) := (
  X"40",
  X"40", X"42", X"7F", X"7F",
  X"40", X"40", X"00", X"00"
);
constant SSD1306_CHAR_2 : data_arr_t(0 to 8) := (
  X"40",
  X"62", X"73", X"59", X"49",
  X"6F", X"66", X"00", X"00"
);
constant SSD1306_CHAR_3 : data_arr_t(0 to 8) := (
  X"40",
  X"22", X"63", X"49", X"49",
  X"7F", X"36", X"00", X"00"
);
constant SSD1306_CHAR_4 : data_arr_t(0 to 8) := (
  X"40",
  X"18", X"1C", X"16", X"53",
  X"7F", X"7F", X"50", X"00"
);
constant SSD1306_CHAR_5 : data_arr_t(0 to 8) := (
  X"40",
  X"27", X"67", X"45", X"45",
  X"7D", X"39", X"00", X"00"
);
constant SSD1306_CHAR_6 : data_arr_t(0 to 8) := (
  X"40",
  X"3C", X"7E", X"4B", X"49",
  X"79", X"30", X"00", X"00"
);
constant SSD1306_CHAR_7 : data_arr_t(0 to 8) := (
  X"40",
  X"03", X"03", X"71", X"79",
  X"0F", X"07", X"00", X"00"
);
constant SSD1306_CHAR_8 : data_arr_t(0 to 8) := (
  X"40",
  X"36", X"7F", X"49", X"49",
  X"7F", X"36", X"00", X"00"
);
constant SSD1306_CHAR_9 : data_arr_t(0 to 8) := (
  X"40",
  X"06", X"4F", X"49", X"69",
  X"3F", X"1E", X"00", X"00"
);

  function ssd1306_bcd_digit_data (
    constant digit : std_logic_vector(3 downto 0))
    return data_arr_t;

end package ssd1306_pkg;

package body ssd1306_pkg is

  function ssd1306_bcd_digit_data (
    constant digit : std_logic_vector(3 downto 0))
    return data_arr_t is
    variable ret : data_arr_t(0 to 8);
  begin
    case digit is
      when "0000" => ret := SSD1306_CHAR_0;
      when "0001" => ret := SSD1306_CHAR_1;
      when "0010" => ret := SSD1306_CHAR_2;
      when "0011" => ret := SSD1306_CHAR_3;
      when "0100" => ret := SSD1306_CHAR_4;
      when "0101" => ret := SSD1306_CHAR_5;
      when "0110" => ret := SSD1306_CHAR_6;
      when "0111" => ret := SSD1306_CHAR_7;
      when "1000" => ret := SSD1306_CHAR_8;
      when "1001" => ret := SSD1306_CHAR_9;
      when others => ret := SSD1306_CHAR_0;
    end case;
    return ret;
  end function ssd1306_bcd_digit_data;

end package body ssd1306_pkg;
