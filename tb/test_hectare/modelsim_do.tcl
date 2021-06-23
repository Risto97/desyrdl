
# OSVVM
source OsvvmLibraries/Scripts/StartUp.tcl
## don't just build everything
#build OsvvmLibraries/OsvvmLibraries.pro
## build what is needed
build OsvvmLibraries/osvvm/osvvm.pro
build OsvvmLibraries/Common/Common.pro
build OsvvmLibraries/AXI4/AXI4.pro
build Dpm.pro

set modname test_hectare

library osvvm_my_tb
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
