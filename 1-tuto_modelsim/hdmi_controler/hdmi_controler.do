-------------------------------------------------------------------------------
-- hdmi_controler.do
-- Script de simulation Modelsim pour le contrôleur HDMI.
--
-- Usage :
--   1. Lancer Modelsim
--   2. cd <chemin/vers/le/dossier>
--   3. do hdmi_controler.do
-------------------------------------------------------------------------------
quit -sim
vlib work
vcom hdmi_controler.vhd
vcom hdmi_controler_tb.vhd
vsim -c work.hdmi_controler_tb

# ---- Entrées -------------------------------------------------------------
add wave -divider {Inputs:}
add wave -color yellow -format Logic /hdmi_controler_tb/tb_clk
add wave -color yellow -format Logic /hdmi_controler_tb/tb_rst_n

# ---- Compteurs internes --------------------------------------------------
add wave -divider {Horizontal counter:}
add wave -color cyan  -format Literal -radix unsigned /hdmi_controler_tb/uut/r_h_count
add wave -color green -format Logic                   /hdmi_controler_tb/uut/r_h_active
add wave -color red   -format Logic                   /hdmi_controler_tb/tb_hdmi_hs

add wave -divider {Vertical counter:}
add wave -color cyan  -format Literal -radix unsigned /hdmi_controler_tb/uut/r_v_count
add wave -color green -format Logic                   /hdmi_controler_tb/uut/r_v_active
add wave -color red   -format Logic                   /hdmi_controler_tb/tb_hdmi_vs

# ---- Sorties pixel -------------------------------------------------------
add wave -divider {Pixel outputs:}
add wave -color magenta -format Logic                   /hdmi_controler_tb/tb_hdmi_de
add wave -color magenta -format Logic                   /hdmi_controler_tb/tb_pixel_en
add wave -color white   -format Literal -radix unsigned /hdmi_controler_tb/tb_x_counter
add wave -color white   -format Literal -radix unsigned /hdmi_controler_tb/tb_y_counter
add wave -color white   -format Literal -radix unsigned /hdmi_controler_tb/tb_pixel_address

# ---- Lancement -----------------------------------------------------------
run -all
