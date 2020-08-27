onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_iq_slide/gen_ENT_IQ_SLIDE/uut/SIG_SIN_TMP
add wave -noupdate /tb_iq_slide/gen_ENT_IQ_SLIDE/uut/SIG_COS_TMP
add wave -noupdate /tb_iq_slide/gen_ENT_IQ_SLIDE/uut/SIG_I_SHIFT_REG
add wave -noupdate /tb_iq_slide/gen_ENT_IQ_SLIDE/uut/SIG_Q_SHIFT_REG
add wave -noupdate /tb_iq_slide/gen_ENT_IQ_SLIDE/uut/SIG_I_PIPE
add wave -noupdate /tb_iq_slide/gen_ENT_IQ_SLIDE/uut/SIG_Q_PIPE
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {103 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 367
configure wave -valuecolwidth 144
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
WaveRestoreZoom {0 ns} {872 ns}
