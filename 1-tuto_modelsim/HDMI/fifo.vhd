--- un registre serie est un ensemble de bascules D connectées en série. Il est utilisé pour stocker des données binaires et les transférer d'une bascule à l'autre à chaque impulsion d'horloge.
--- on va utiliser un registre serie de 4 bascule D

library ieee;
use ieee.std_logic_1164.all;

entity fifo is
    generic (
        N : positive := 4
    );
    port (
        i_clk   : in  std_logic;
        i_rst_n : in  std_logic;
        i_en    : in  std_logic;
        i_d     : in  std_logic;
        o_q     : out std_logic
    );
end entity fifo;

architecture rtl of fifo is
    signal r_reg : std_logic_vector(N-1 downto 0);
begin
    process(i_clk, i_rst_n)
    begin
        if i_rst_n = '0' then
            r_reg <= (others => '0');
        elsif rising_edge(i_clk) then
            if i_en = '1' then
                r_reg(0) <= i_d;
                r_reg(N-1 downto 1) <= r_reg(N-2 downto 0);
            end if;
        end if;
    end process;

    o_q <= r_reg(N-1);
end architecture rtl;

--- registre à décalage série de 4 bits avec entrée et sortie série, horloge et reset asynchrone = un registre de 4 bascule D asynchrone avec entrée et sortie série, horloge et reset asynchrone.