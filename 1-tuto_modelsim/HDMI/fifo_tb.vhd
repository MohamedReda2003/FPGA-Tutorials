library ieee;
use ieee.std_logic_1164.all;

entity fifo_tb is
end entity fifo_tb;

architecture tb of fifo_tb is
    constant T : time := 10 ns;
    constant N : positive := 4;
    signal tb_clk   : std_logic := '0';
    signal tb_rst_n : std_logic;
    signal tb_en    : std_logic;
    signal tb_d     : std_logic;
    signal tb_q     : std_logic;
    signal tb_done  : boolean := false;
begin
    uut : entity work.fifo
        generic map (N => N)
        port map (
            i_clk   => tb_clk,
            i_rst_n => tb_rst_n,
            i_en    => tb_en,
            i_d     => tb_d,
            o_q     => tb_q
        );

    -- Horloge
    process
    begin
        while not tb_done loop
            tb_clk <= '0'; wait for T/2;
            tb_clk <= '1'; wait for T/2;
        end loop;
        wait;
    end process;

    -- Stimuli
    process
    begin
        tb_rst_n <= '0'; tb_en <= '1'; tb_d <= '0';
        wait for 12 ns;
        tb_rst_n <= '1';

        -- séquence 1 0 1 1 0 0 0 0
        tb_d <= '1'; wait for T;
        tb_d <= '0'; wait for T;
        tb_d <= '1'; wait for T;
        tb_d <= '1'; wait for T;
        tb_d <= '0'; wait for 4*T;

        -- enable coupé : le registre se fige
        tb_d <= '1'; wait for 2*T;
        tb_en <= '0';
        tb_d <= '0'; wait for 3*T;
        tb_en <= '1'; wait for 5*T;

        -- reset asynchrone en cours de décalage
        tb_d <= '1'; wait for 3*T;
        tb_rst_n <= '0'; wait for 4 ns;
        tb_rst_n <= '1'; wait for 3*T;

        tb_done <= true;
        wait;
    end process;
end architecture tb;