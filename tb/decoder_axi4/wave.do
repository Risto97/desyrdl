onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_top/ins_top/pi_clk
add wave -noupdate /tb_top/ins_top/pi_reset
add wave -noupdate /tb_top/ins_top/S_AXI_AWADDR
add wave -noupdate /tb_top/ins_top/S_AXI_AWPROT
add wave -noupdate /tb_top/ins_top/S_AXI_AWVALID
add wave -noupdate /tb_top/ins_top/S_AXI_AWREADY
add wave -noupdate /tb_top/ins_top/S_AXI_WDATA
add wave -noupdate /tb_top/ins_top/S_AXI_WSTRB
add wave -noupdate /tb_top/ins_top/S_AXI_WVALID
add wave -noupdate /tb_top/ins_top/S_AXI_WREADY
add wave -noupdate /tb_top/ins_top/S_AXI_BRESP
add wave -noupdate /tb_top/ins_top/S_AXI_BVALID
add wave -noupdate /tb_top/ins_top/S_AXI_BREADY
add wave -noupdate /tb_top/ins_top/S_AXI_ARADDR
add wave -noupdate /tb_top/ins_top/S_AXI_ARPROT
add wave -noupdate /tb_top/ins_top/S_AXI_ARVALID
add wave -noupdate /tb_top/ins_top/S_AXI_ARREADY
add wave -noupdate /tb_top/ins_top/S_AXI_RDATA
add wave -noupdate /tb_top/ins_top/S_AXI_RRESP
add wave -noupdate /tb_top/ins_top/S_AXI_RVALID
add wave -noupdate /tb_top/ins_top/S_AXI_RREADY
add wave -noupdate /tb_top/ins_top/pi_logic_regs
add wave -noupdate /tb_top/ins_top/po_logic_regs
add wave -noupdate /tb_top/ins_top/adapter_stb
add wave -noupdate /tb_top/ins_top/adapter_we
add wave -noupdate /tb_top/ins_top/adapter_err
add wave -noupdate /tb_top/ins_top/adapter_wdata
add wave -noupdate /tb_top/ins_top/adapter_rdata
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 0
configure wave -namecolwidth 150
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
WaveRestoreZoom {337008 ps} {350684 ps}
