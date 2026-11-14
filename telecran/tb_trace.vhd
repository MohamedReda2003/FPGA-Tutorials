library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_trace is
end entity;

architecture tb of tb_trace is
    signal clk : std_logic := '0';
    signal rst_n, pb : std_logic := '1';
    signal a, b : std_logic := '0';
    signal scl, sda : std_logic;
    signal tx_clk, tx_de, tx_hs, tx_vs : std_logic;
    signal tx_d : std_logic_vector(23 downto 0);
    signal leds : std_logic_vector(9 downto 0);
    signal dleds : std_logic_vector(7 downto 0);
    signal done : boolean := false;
    signal we   : std_logic;
    signal addr : natural range 0 to 345599;
    signal wd   : std_logic_vector(0 downto 0);
begin
    clk <= not clk after 10 ns when not done;

    dut : entity work.telecran
        port map (i_clk_50 => clk, io_hdmi_i2c_scl => scl, io_hdmi_i2c_sda => sda,
            o_hdmi_tx_clk => tx_clk, o_hdmi_tx_d => tx_d, o_hdmi_tx_de => tx_de,
            o_hdmi_tx_hs => tx_hs, i_hdmi_tx_int => '0', o_hdmi_tx_vs => tx_vs,
            i_rst_n => rst_n, o_leds => leds, o_de10_leds => dleds,
            i_left_ch_a => a, i_left_ch_b => b, i_left_pb => pb,
            i_right_ch_a => '0', i_right_ch_b => '0', i_right_pb => '1');

    -- espionnage du port A de la RAM (signaux internes du top)
    we   <= << signal .tb_trace.dut.s_ram_we_a : std_logic >>;
    addr <= << signal .tb_trace.dut.s_ram_addr_a : natural range 0 to 345599 >>;
    wd   <= << signal .tb_trace.dut.s_ram_data_a : std_logic_vector(0 downto 0) >>;

    p_pos : process(leds)
    begin
        report "x = " & integer'image(to_integer(unsigned(leds)));
    end process;

    p_log : process(clk)
    begin
        if rising_edge(clk) and we = '1' and addr < 8 then
            report "ecriture adresse " & integer'image(addr) & " <- " & std_logic'image(wd(0));
        end if;
    end process;

    p_stim : process
        procedure step(na, nb : std_logic) is
        begin
            a <= na; b <= nb; wait for 4 ms;
        end procedure;
    begin
        rst_n <= '0'; wait for 100 ns; rst_n <= '1';
        wait for 4 ms;
        report "--- effacement initial (RAM a 0)";
        pb <= '0'; wait for 4 ms; pb <= '1'; wait for 12 ms;
        report "--- aller : x passe de 0 a 2";
        step('1','0'); step('1','1'); step('0','1'); step('0','0');
        report "--- retour : x repasse sur 1";
        step('0','1');
        wait for 4 ms;
        done <= true; wait;
    end process;
end architecture;
