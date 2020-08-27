# -------------------------------------------------------------------------------
# --          ____  _____________  __                                          --
# --         / __ \/ ____/ ___/\ \/ /                 _   _   _                --
# --        / / / / __/  \__ \  \  /                 / \ / \ / \               --
# --       / /_/ / /___ ___/ /  / /               = ( M | S | K )=             --
# --      /_____/_____//____/  /_/                   \_/ \_/ \_/               --
# --                                                                           --
# -------------------------------------------------------------------------------
# --! @file    modelsim_do.tcl
# --! @brief   modelsim tcl script for IQ demod
# --! @author  Lukasz Butkowski  <lukasz.butkowski@desy.de>
# --! @author  Michael Buechler <michael.buechler@desy.de>
# --! @company DESY
# --! @created 2019-03-13
# -------------------------------------------------------------------------------
# -- Copyright (c) 2019,2020 DESY
# -------------------------------------------------------------------------------

## ------------------------------------------------------------------------------
## compile
## ------------------------------------------------------------------------------

# create empty list
set designLibrary {}

if {[info exists module_name]} {
  puts "module_name exists: ${module_name}"
} else {
  set module_name iq_slide
}

# fill lists
lappend designLibrary ../../../math/math_basic.vhd
lappend designLibrary ../../../pkg/PKG_TYPES.vhd
lappend designLibrary ../../adder_pipe.vhd
lappend designLibrary ../../$module_name.vhd
lappend designLibrary ../../ENT_IQ_SLIDE.vhd
lappend designLibrary ../tb_${module_name}.vhd

set topLevel  work.tb_${module_name}


vlib designLibrary
vmap work designLibrary

foreach file $designLibrary {
    #vcom -93 +cover=bcesfx $file
    vcom -93 $file
}

#eval vsim -coverage $topLevel
eval vsim $topLevel
#noview wavel

add wave /*
#add wave /uut/SIG_COS_TMP
#add wave /uut/SIG_SIN_TMP

#do wave.do
do wave_ENT_IQ_SLIDE.do

## -----------------------------------------------------------------------------
## cosimtcp
## -----------------------------------------------------------------------------
#source ../../../../tools/cosimtcp/server/modelsimServer.tcl
source ../../../../tools/cosimtcp/server/modelsimServer.tcl

global input
global output

set  input(data,path)       pi_data
#set  input(sintable,path)   uut\/pi_sin
#set  input(costable,path)   uut\/pi_cos

set  output(I,path)      po_i
set  output(Q,path)      po_q
set  output(valid,path)  po_valid
#set  output(I_tmp,path)  uut\/sig_cos_tmp
#set  output(Q_tmp,path)  uut\/sig_sin_tmp

modelsimServer 23495
