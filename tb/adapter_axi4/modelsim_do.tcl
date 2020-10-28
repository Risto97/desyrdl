
# OSVVM
source OsvvmLibraries/Scripts/StartUp.tcl
build OsvvmLibraries/OsvvmLibraries.pro

library osvvm_my_tb
analyze ../../../desy_lib_svn/pkg/PKG_TYPES.vhd
analyze ../../pkg_axi4.vhd
analyze ../../reg_field_storage.vhd
analyze ../../generic_register.vhd
analyze ../../adapter_axi4.vhd
analyze ../../top2.vhd
analyze tb_TestCtrl.vhd
analyze tb_top.vhd

simulate tb_top

do wave.do
