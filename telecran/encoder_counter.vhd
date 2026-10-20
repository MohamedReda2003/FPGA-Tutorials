library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity encoder_counter is
    generic (
        g_BITS : integer := 10 -- Taille du compteur (configurable, par défaut 10 bits pour le projet)
    );
    port (
        i_clk     : in  std_logic;                          -- Horloge système (50 MHz)
        i_rst_n   : in  std_logic;                          -- Reset asynchrone (actif bas)
        i_clk_en  : in  std_logic;                          -- Signal Enable venant du diviseur
        i_a       : in  std_logic;                          -- Voie A de l'encodeur
        i_b       : in  std_logic;                          -- Voie B de l'encodeur
        o_counter : out std_logic_vector(g_BITS - 1 downto 0) -- Valeur du compteur
    );
end entity encoder_counter;

architecture rtl of encoder_counter is

    -- Registres à décalage pour les 2 bascules D de chaque voie
    -- bit 0 = Aq1 (sortie 1ère bascule), bit 1 = Aq2 (sortie 2ème bascule)
    signal r_a_pipe : std_logic_vector(1 downto 0) := "00";
    signal r_b_pipe : std_logic_vector(1 downto 0) := "00";

    -- Signaux combinatoires de détection
    signal s_inc : std_logic;
    signal s_dec : std_logic;

    -- Registre du compteur interne
    signal r_counter : unsigned(g_BITS - 1 downto 0) := (others => '0');

begin

    ------------------------------------------------------------------
    -- 1. Échantillonnage des voies A et B (Les 4 bascules D)
    ------------------------------------------------------------------
    process(i_clk, i_rst_n)
    begin
        if (i_rst_n = '0') then
            r_a_pipe <= "00";
            r_b_pipe <= "00";
        elsif rising_edge(i_clk) then
            if (i_clk_en = '1') then
                -- Décalage : le bit 0 reçoit la nouvelle entrée, le bit 1 reçoit l'ancien bit 0
                r_a_pipe <= r_a_pipe(0) & i_a;
                r_b_pipe <= r_b_pipe(0) & i_b;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- 2. Logique combinatoire (Portes ET / OU / NOT de votre schéma)
    ------------------------------------------------------------------
    -- s_inc = (A_q1 AND NOT A_q2 AND NOT B_q1) OR (NOT A_q1 AND A_q2 AND B_q1)
    s_inc <= (r_a_pipe(0) and not r_a_pipe(1) and not r_b_pipe(0)) or
             (not r_a_pipe(0) and r_a_pipe(1) and r_b_pipe(0));

    -- s_dec = (NOT A_q1 AND B_q1 AND NOT B_q2) OR (A_q1 AND NOT B_q1 AND B_q2)
    s_dec <= (not r_a_pipe(0) and r_b_pipe(0) and not r_b_pipe(1)) or
             (r_a_pipe(0) and not r_b_pipe(0) and r_b_pipe(1));

    ------------------------------------------------------------------
    -- 3. Mise à jour du compteur de position
    ------------------------------------------------------------------
    process(i_clk, i_rst_n)
    begin
        if (i_rst_n = '0') then
            r_counter <= (others => '0');
        elsif rising_edge(i_clk) then
            if (i_clk_en = '1') then
                if (s_inc = '1') then
                    r_counter <= r_counter + 1;
                elsif (s_dec = '1') then
                    r_counter <= r_counter - 1;
                end if;
            end if;
        end if;
    end process;

    -- Affectation de la sortie
    o_counter <= std_logic_vector(r_counter);

end architecture rtl;