library ieee;
use ieee.std_logic_1164.all;

library i2c;
library vunit_lib;
context vunit_lib.vunit_context;

entity address_generator_tb is

  generic (
    runner_cfg : string);

end entity address_generator_tb;

architecture tb of address_generator_tb is
  signal clk : std_logic := '0';
  constant CLK_PERIOD : time := 10 ns;

  signal rst_n : std_logic := '0';

  signal sda : std_logic := 'H';
  signal slave_sda : std_logic := 'H';
  signal sda_enable : std_logic;

  signal scl : std_logic := 'H';
  signal not_scl : std_logic;

  signal scl_rising : std_logic := '0';
  signal scl_falling : std_logic := '0';
  signal scl_falling_delayed : std_logic := '0';

  signal start : std_logic := '0';
  signal done : std_logic;
  signal unexpected_sda, noack : std_logic;
  signal rw : std_logic := '0';
  signal address : std_logic_vector(6 downto 0);

  signal one : std_logic := '1';
  signal zero : std_logic := '0';
begin  -- architecture tb

  clk <= not clk after CLK_PERIOD/2;
  rst_n <= '1' after 2*CLK_PERIOD;

  sda <= 'H';
  sda <= '0' when sda_enable = '1' else 'Z';

  slave_sda <= '1' when sda = 'H' else sda;

  not_scl <= not scl;
  scl <= 'H';

  uut : entity i2c.address_generator
    port map (
      clk_i                 => clk,
      rst_in                => rst_n,
      start_i               => start,
      store_address_rw_i    => '1',
      address_i             => address,
      rw_i                  => rw,
      sda_i                 => slave_sda,
      sda_enable_o          => sda_enable,
      scl_rising_i          => scl_rising,
      scl_falling_delayed_i => scl_falling_delayed,
      unexpected_sda_o      => unexpected_sda,
      noack_o               => noack,
      done_o                => done);

  sda_stability_check: check_stable(clk, one, scl, not_scl, sda);

  main: process is
    procedure request_address_gen (
      constant address_i : in std_logic_vector(6 downto 0);
      constant rw_i      : in std_logic) is
      begin
        rw <= rw_i;
        address <= address_i;
        start <= '1';
        wait until falling_edge(clk);
        start <= '0';
      end procedure request_address_gen;

      procedure scl_fall is
      begin  -- procedure scl_fall
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        scl <= '0';
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        wait until falling_edge(clk);
      end procedure scl_fall;

      procedure scl_rise is
      begin  -- procedure scl_fall
        scl <= 'Z';
        wait until falling_edge(clk);
      end procedure scl_rise;

      procedure scl_pulse is
      begin  -- procedure scl_pulse
        scl_rise;
        scl_fall;
      end procedure scl_pulse;

      procedure validate_address_gen (
        constant address            : in std_logic_vector(6 downto 0);
        constant rw                 : in std_logic;
        constant ack                : in std_logic                    := '1';
        constant exp_noack          : in std_logic                    := '0';
        constant exp_unexpected_sda : in std_logic_vector(7 downto 0) := (others => '0')) is
      begin  -- procedure validate_address_gen
        check_equal(done, '0', "Wrong done before validation!");
        scl_fall;

        for i in 0 to 6 loop
          if address(6 - i) = '1' then
            check_equal(sda, 'H', "Sda should be high for index " & integer'image(i));
          else
            check_equal(sda, '0', "Sda should be low for index " & integer'image(i));
          end if;

          wait for 0 ns;
          if exp_unexpected_sda(7 - i) = '1' then
            sda <= '0';
          end if;

          scl_rise;

          check_equal(unexpected_sda, exp_unexpected_sda(7 - i));

          scl_fall;

          if exp_unexpected_sda(7 - i) = '1' then
            sda <= 'Z';
          end if;
          wait for 0 ns;

        end loop;  -- i

        if rw = '1' then
          check_equal(sda, 'H', "Sda should be high for rw");
        else
          check_equal(sda, '0', "Sda should be low for rw");
        end if;

        scl_rise;
        check_equal(unexpected_sda, exp_unexpected_sda(0));
        scl_fall;

        if ack = '1' then
          sda <= '0';
          wait until falling_edge(clk);
        end if;

        scl <= 'Z';
        wait for CLK_PERIOD/4;

        check_equal(noack, exp_noack, "Unexpected noack.");

        wait until falling_edge(clk);

        scl <= '0';

        wait until falling_edge(clk);
        wait until rising_edge(clk);
        check_equal(done, '1', "Not reporting done");
        wait until falling_edge(clk);

        sda <= 'Z';


      end procedure validate_address_gen;
  begin  -- process main
    wait until rst_n = '1';
    wait until falling_edge(clk);

    check_equal(scl, 'H', "begin SCL not high");

    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("simple_read") then
        request_address_gen("1110101", '1');
        validate_address_gen("1110101", '1');
      elsif run("simple_write") then
        request_address_gen("0001010", '0');
        validate_address_gen("0001010", '0');
      elsif run("write_read") then
        request_address_gen("0001010", '0');
        validate_address_gen("0001010", '0');

        request_address_gen("1111010", '1');
        validate_address_gen("1111010", '1');
      elsif run("noack") then
        request_address_gen("0001010", '0');
        validate_address_gen("0001010", '0', ack => '0', exp_noack => '1');
      elsif run("sda_wrong") then
        request_address_gen("1111111", '0');
        validate_address_gen("1111111", '0', exp_unexpected_sda => "10101010");
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process main;

  set_scl_rising: process is
  begin  -- process scl_rising
    wait until rising_edge(scl);
    scl_rising <= '1';
    wait until falling_edge(clk);
    wait until rising_edge(clk);
    scl_rising <= '0';
  end process set_scl_rising;

  set_scl_falling: process is
  begin  -- process scl_rising
    wait until falling_edge(scl);
    scl_falling <= '1';
    wait until rising_edge(clk);
    wait until falling_edge(clk);
    scl_falling <= '0';
  end process set_scl_falling;

  set_delayed_scl_falling: process is
  begin  -- process scl_rising
    wait until falling_edge(scl);
    wait until falling_edge(clk);
    scl_falling_delayed <= '1';
    wait until rising_edge(clk);
    wait until falling_edge(clk);
    scl_falling_delayed <= '0';
  end process set_delayed_scl_falling;

end architecture tb;
