
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

library desyrdl
analyze ../../templates/pkg_desyrdl_common.vhd
# these are necessary to make desyrdl self-contained
analyze ../../templates/axi4_to_axi4.vhd
analyze ../../templates/axi4_to_ibus.vhd
#
analyze ../../templates/reg_field_storage.vhd
analyze ../../templates/reg_field_counter.vhd
analyze ../../templates/register.vhd
analyze ../../templates/adapter_axi4.vhd
analyze ../../out/pkg_reg_$modname.vhd
analyze ../../out/top_$modname.vhd

library osvvm_my_tb
analyze tb_TestCtrl.vhd
analyze tb_top.vhd

simulate tb_top
