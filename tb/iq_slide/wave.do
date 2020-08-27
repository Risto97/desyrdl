onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_iq_slide/pi_clock
add wave -noupdate /tb_iq_slide/pi_reset
add wave -noupdate /tb_iq_slide/pi_data
add wave -noupdate /tb_iq_slide/pi_sin
add wave -noupdate /tb_iq_slide/pi_cos
add wave -noupdate /tb_iq_slide/sincos_tab_index
add wave -noupdate /tb_iq_slide/po_i
add wave -noupdate /tb_iq_slide/po_q
add wave -noupdate /tb_iq_slide/po_valid
add wave -noupdate /tb_iq_slide/gen_iq_slide/uut/blk_mult/l_product_i
add wave -noupdate /tb_iq_slide/gen_iq_slide/uut/window_i
add wave -noupdate /tb_iq_slide/gen_iq_slide/uut/blk_adders/ins_adder_i/l_adder_tree
add wave -noupdate /tb_iq_slide/gen_iq_slide/uut/window_rdy
add wave -noupdate /tb_iq_slide/gen_iq_slide/uut/blk_mult/l_window_cnt
add wave -noupdate /tb_iq_slide/gen_iq_slide/uut/blk_adders/ins_adder_i/l_valid
add wave -noupdate /tb_iq_slide/gen_iq_slide/uut/sum_rdy
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 0
configure wave -namecolwidth 400
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {10155 ns}
