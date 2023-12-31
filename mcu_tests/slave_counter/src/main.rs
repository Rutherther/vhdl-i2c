#![no_std]
#![no_main]

use cortex_m_semihosting::hprintln;
use cortex_m_semihosting::dbg;
use embedded_hal::blocking::i2c;
use hal::pwm::Timer;
use panic_halt as _;
use tm4c_hal::gpio; // you can put a breakpoint on `rust_begin_unwind` to catch panics

use cortex_m_rt::entry;
use tm4c123x_hal::{self as hal, prelude::*, delay::Delay, i2c::I2c};

#[entry]
fn main() -> ! {
    let p = hal::Peripherals::take().unwrap();
    let cp = hal::CorePeripherals::take().unwrap();

    let mut sc = p.SYSCTL.constrain();
    sc.clock_setup.oscillator = hal::sysctl::Oscillator::Main(
        hal::sysctl::CrystalFrequency::_16mhz,
        hal::sysctl::SystemClock::UsePll(hal::sysctl::PllOutputFrequency::_80_00mhz),
    );
    let clocks = sc.clock_setup.freeze();

    let mut portb = p.GPIO_PORTB.split(&sc.power_control);

    let scl = portb.pb2.into_af_push_pull::<hal::gpio::AF3>(&mut portb.control);
    let sda = portb.pb3.into_af_open_drain::<hal::gpio::AF3, gpio::Floating>(&mut portb.control);

    let mut i2c = I2c::i2c0(p.I2C0, (scl, sda), 100_000u32.hz(), &clocks, &sc.power_control);

    hprintln!("Hello world!");

    let mut delay = Delay::new(cp.SYST, &clocks);

    let mut buffer: [u8; 5] = [0; 5];
    const ADDRESS: u8 = 0b1110100;
    loop {
        let res = i2c.read(ADDRESS, &mut buffer);
        if res.is_ok() {
            dbg!(buffer);
        }
        else {
            hprintln!("Got an error when trying to read :(");
        }

        delay.delay_ms(1000u16);
    }
}
