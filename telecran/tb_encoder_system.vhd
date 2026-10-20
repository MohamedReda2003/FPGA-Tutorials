library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity telecran is
    port (
        -- Horloge principale 50 MHz de la carte
        FPGA_CLK1_50 : in  std_logic;
        
        -- Bouton poussior KEY0 pour le Reset (actif à '0')
        KEY0         : in  std_logic;
        
        -- Voies A et B de l'encodeur gauche
        LEFT_A       : in  std_logic;
        LEFT_B       : in  std_logic;
        
        -- Affichage de la valeur binaire sur les 10 LEDs
        LEDR         : out std_logic_vector(9 downto 0)
    );
end entity telecran;

architecture rtl of telecran is

    -- Signaux internes pour l'interconnexion
    signal s_clk_en  : std_logic;
    signal s_counter : std_logic_vector(9 downto 0);

begin

    ------------------------------------------------------------------
    -- 1. Instanciation de votre Diviseur d'Horloge (clock_enable)
    ------------------------------------------------------------------
    u_clock_enable : entity work.clock_enable
        generic map (
            -- 50 000 cycles à 50 MHz = 1 ms (filtre anti-rebond efficace)
            g_DIVISOR => 50000 
        )
        port map (
            i_clk    => FPGA_CLK1_50,
            i_rst_n  => KEY0,
            o_clk_en => s_clk_en
        );

    ------------------------------------------------------------------
    -- 2. Instanciation de votre Compteur d'Encodeur (encoder_counter)
    ------------------------------------------------------------------
    u_encoder_counter : entity work.encoder_counter
        generic map (
            g_BITS => 10
        )
        port map (
            i_clk     => FPGA_CLK1_50,
            i_rst_n   => KEY0,
            i_clk_en  => s_clk_en,
            i_a       => LEFT_A,
            i_b       => LEFT_B,
            o_counter => s_counter
        );

    ------------------------------------------------------------------
    -- 3. Sortie sur les LEDs de la carte
    ------------------------------------------------------------------
    LEDR <= s_counter;

end architecture rtl;