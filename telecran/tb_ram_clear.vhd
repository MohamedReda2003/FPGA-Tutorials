library ieee;
use ieee.std_logic_1164.all;

entity tb_ram_clear is
end entity;

architecture tb of tb_ram_clear is
    constant c_SIZE : positive := 64;  -- RAM réduite pour la simulation
    signal clk, rst_n, clk_en, btn_n, busy : std_logic := '0';
    signal addr  : natural range 0 to c_SIZE - 1;
    signal q_a, q_b : std_logic_vector(0 downto 0);
    signal addr_a   : natural range 0 to c_SIZE - 1 := 0;
    signal data_a   : std_logic_vector(0 downto 0);
    signal we_a     : std_logic;
    signal pre_we   : std_logic := '0';
    signal pre_addr : natural range 0 to c_SIZE - 1 := 0;
    signal done : boolean := false;
begin
    clk <= not clk after 10 ns when not done;
    u_en : entity work.clock_enable generic map (g_DIVISOR => 8)
        port map (i_clk => clk, i_rst_n => rst_n, o_clk_en => clk_en);
    u_dut : entity work.ram_clear generic map (g_MEM_SIZE => c_SIZE)
        port map (i_clk => clk, i_rst_n => rst_n, i_clk_en => clk_en,
                  i_btn_n => btn_n, o_busy => busy, o_addr => addr);
    -- même multiplexeur que dans telecran.vhd
    addr_a <= addr when busy = '1' else pre_addr;
    data_a <= "0"  when busy = '1' else "1";
    we_a   <= '1'  when busy = '1' else pre_we;
    u_ram : entity work.dpram generic map (mem_size => c_SIZE, data_width => 1)
        port map (i_clk_a => clk, i_clk_b => clk,
                  i_addr_a => addr_a, i_data_a => data_a, i_we_a => we_a, o_q_a => q_a,
                  i_addr_b => pre_addr, i_data_b => "0", i_we_b => '0', o_q_b => q_b);

    process
        variable v_ones : natural;
    begin
        btn_n <= '1'; rst_n <= '0';
        wait for 45 ns; rst_n <= '1';
        -- remplit toute la RAM de '1' (simule un dessin)
        for i in 0 to c_SIZE - 1 loop
            pre_addr <= i; pre_we <= '1';
            wait until rising_edge(clk);
        end loop;
        pre_we <= '0';
        wait for 400 ns;
        -- appui bouton (actif bas) avec rebonds
        btn_n <= '0'; wait for 30 ns; btn_n <= '1'; wait for 50 ns; btn_n <= '0';
        wait for 2 us;
        btn_n <= '1';
        wait for 2 us;
        -- relecture
        v_ones := 0;
        for i in 0 to c_SIZE - 1 loop
            pre_addr <= i;
            wait until rising_edge(clk); wait until rising_edge(clk);
            if q_b(0) = '1' then v_ones := v_ones + 1; end if;
        end loop;
        report "pixels restant a 1 apres effacement : " & integer'image(v_ones);
        assert v_ones = 0 report "ECHEC" severity failure;
        done <= true; wait;
    end process;
end architecture;
