quit -sim

vlib work

vcom fifo.vhd
vcom fifo_tb.vhd

vsim -c work.fifo_tb

# INPUTS
add wave -divider Inputs:
add wave -color yellow uut/i_clk
add wave -color yellow uut/i_rst_n
add wave -color yellow uut/i_en
add wave -color yellow uut/i_d

# INTERNAL
add wave -divider Internal:
add wave uut/r_reg

# OUTPUTS
add wave -divider Outputs:
add wave uut/o_q

run -all