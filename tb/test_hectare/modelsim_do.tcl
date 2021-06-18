
# OSVVM
source OsvvmLibraries/Scripts/StartUp.tcl
build OsvvmLibraries/AXI4/Axi4/Axi4.pro
#build OsvvmLibraries/OsvvmLibraries.pro

set modname test_hectare

library osvvm_my_tb
analyze dual_port_memory.vhd
analyze ../../templates/pkg_reg_common.vhd
analyze ../../templates/PKG_AXI.vhd
analyze ../../templates/reg_field_storage.vhd
analyze ../../templates/reg_field_counter.vhd
analyze ../../templates/register.vhd
analyze ../../templates/adapter_axi4.vhd
analyze ../../out/pkg_reg_$modname.vhd
analyze ../../out/top_$modname.vhd
#analyze test_hectare_top.vhd
analyze tb_TestCtrl.vhd
analyze tb_top.vhd

simulate tb_top

add wave /tb_top/*
add wave /tb_top/ins_dut/*
add wave /tb_top/ins_dut/ins_top_reg_test_hectare/*
add wave /tb_top/ins_dut/ins_top_reg_test_hectare/ins_adapter/*
