#!/usr/bin/env python3

from vunit import VUnit
from pathlib import Path

vu = VUnit.from_argv(compile_builtins = False)

vu.add_vhdl_builtins()
vu.add_com()

i2c_tb_lib = vu.add_library('i2c_tb')
i2c_tb_lib.add_source_files(Path(__file__).parent / 'tb/i2c/**/*.vhd')

mcu_slave_tb_lib = vu.add_library('mcu_slave_tb')
mcu_slave_tb_lib.add_source_files(Path(__file__).parent / 'tb/mcu_slave/**/*.vhd')

mcu_slave_lib = vu.add_library('mcu_slave')
mcu_slave_lib.add_source_files(Path(__file__).parent / 'src/mcu_slave/**/*.vhd')

ssd1306_lib = vu.add_library('ssd1306')
ssd1306_lib.add_source_files(Path(__file__).parent / 'src/ssd1306/**/*.vhd')

ssd1306_lib = vu.add_library('ssd1306_tb')
ssd1306_lib.add_source_files(Path(__file__).parent / 'tb/ssd1306/**/*.vhd')

utils_lib = vu.add_library('utils')
utils_lib.add_source_files(Path(__file__).parent / 'src/utils/**/*.vhd')

# utils_tb_lib = vu.add_library('utils_tb')
# utils_tb_lib.add_source_files(Path(__file__).parent / 'tb/utils/**/*.vhd')

i2c_lib = vu.add_library('i2c')
i2c_lib.add_source_files(Path(__file__).parent / 'src/**/*.vhd')

vu.add_compile_option('nvc.a_flags', ['--relaxed'])
vu.add_compile_option('ghdl.a_flags', ['-frelaxed'])
vu.set_sim_option('ghdl.elab_flags', ['-frelaxed'])

vu.main()
