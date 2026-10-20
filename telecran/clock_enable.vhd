library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clock_enable is
    generic (
        -- Facteur de division :
        -- Par exemple, avec une horloge à 50 MHz (20 ns) :
        -- Pour avoir une impulsion tous les 1 ms (1 kHz), g_DIVISOR = 50 000
        g_DIVISOR : integer := 500000
    );
    port (
        i_clk    : in  std_logic; -- Horloge système principale (ex: 50 MHz)
        i_rst_n  : in  std_logic; -- Reset asynchrone (actif à l'état bas '0')
        o_clk_en : out std_logic  -- Impulsion d'autorisation (1 coup d'horloge)
    );
end entity clock_enable;

architecture rtl of clock_enable is

    -- Registre de comptage de 0 à (g_DIVISOR - 1)
    signal r_counter : integer range 0 to g_DIVISOR - 1 := 0;
    
    -- Registre interne pour la sortie Enable
    signal r_clk_en  : std_logic := '0';

begin

    ------------------------------------------------------------------
    -- Processus de comptage et de génération du signal Enable
    ------------------------------------------------------------------
    process(i_clk, i_rst_n)
    begin
        if (i_rst_n = '0') then
            r_counter <= 0;
            r_clk_en  <= '0';
        elsif rising_edge(i_clk) then
            if (r_counter = g_DIVISOR - 1) then
                r_counter <= 0;
                r_clk_en  <= '1'; -- Génère l'impulsion Enable pendant 1 cycle
            else
                r_counter <= r_counter + 1;
                r_clk_en  <= '0';
            end if;
        end if;
    end process;

    -- Affectation de la sortie
    o_clk_en <= r_clk_en;

end architecture rtl;