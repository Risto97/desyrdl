
# OSVVM
source OsvvmLibraries/Scripts/StartUp.tcl
build OsvvmLibraries/OsvvmLibraries.pro

set modname test_hectare

library osvvm_my_tb
analyze ../../../desy_lib_svn/pkg/PKG_TYPES.vhd
analyze ../../../desy_lib_svn/math/math_basic.vhd
#analyze ../../../desy_lib_svn/mem/fifo/PKG_FIFO.vhd
#analyze ../../../desy_lib_svn/mem/fifo/ENT_FIFO_DPRAM.vhd
#analyze ../../../desy_lib_svn/mem/fifo/ENT_FIFO_GENERIC.vhd
#analyze ../../../desy_lib_svn/mem/fifo/ENT_FIFO_INPUT.vhd
#analyze ../../../desy_lib_svn/mem/fifo/ENT_FIFO_OUTPUT.vhd
#analyze ../../../desy_lib_svn/mem/fifo/ENT_FIFO_ULTRASCALE.vhd
#analyze ../../../desy_lib_svn/mem/fifo/ENT_FIFO_VIRTEX.vhd
#analyze ../../../desy_lib_svn/mem/fifo/ENT_FIFO_XPM.vhd
#analyze ../../../desy_lib_svn/mem/fifo/ENT_FIFO.vhd
#analyze ../../../desy_lib_svn/mem/fifo/ENT_SYNC_FIFO.vhd
#analyze ../../../desy_lib_svn/axi/ENT_AXI4_INTERCONNECT.vhd
analyze ../../../desy_lib_svn/axi/PKG_AXI.vhd
analyze ../../dual_port_memory.vhd
analyze axi4_spi.vhd
analyze ../../HECTARE/pkg_reg_$modname.vhd
analyze ../../HECTARE/reg_field_storage_$modname.vhd
analyze ../../HECTARE/reg_field_counter_$modname.vhd
analyze ../../HECTARE/register_$modname.vhd
analyze ../../HECTARE/adapter_axi4_$modname.vhd
analyze ../../HECTARE/top_$modname.vhd
analyze test_hectare_top.vhd
analyze tb_TestCtrl.vhd
analyze tb_top.vhd

simulate tb_top

add wave /tb_top/*
add wave /tb_top/ins_dut/*
add wave /tb_top/ins_dut/ins_top_reg_test_hectare/*
add wave /tb_top/ins_dut/ins_top_reg_test_hectare/ins_adapter/*
add wave /tb_top/ins_dut/ins_axi4_spi/*
