#!/usr/bin/env python3

from vunit import VUnit
from pathlib import Path

vu = VUnit.from_argv(compile_builtins = False)

vu.add_vhdl_builtins()

testbench_lib = vu.add_library('i2c_tb')
testbench_lib.add_source_files(Path(__file__).parent / 'tb/**/*.vhd')

utils_lib = vu.add_library('utils')
utils_lib.add_source_files(Path(__file__).parent / 'src/utils/**/*.vhd')

i2c_lib = vu.add_library('i2c')
i2c_lib.add_source_files(Path(__file__).parent / 'src/**/*.vhd')

vu.add_compile_option('nvc.a_flags', ['--relaxed'])

vu.main()
