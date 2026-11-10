-------------------------------------------------------------------------------
-- hdmi_controler_tb.vhd  (version corrigée)
--
-- Test bench du contrôleur HDMI.
-- Conserve la structure d'origine (constantes H_*, signal tb_done, test
-- horizontal sur une ligne complète via une boucle for) et AJOUTE :
--   * les constantes verticales V_SYNC, V_FP, V_RES, V_BP, V_TOTAL,
--   * une vérification que les sorties o_hdmi_vs, o_hdmi_de, o_pixel_en sont
--     bien pilotées (pas de 'U') pendant quelques lignes après le test
--     horizontal.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity hdmi_controler_tb is
end entity hdmi_controler_tb;

architecture tb of hdmi_controler_tb is

    constant T : time := 10 ns;

    -- Timings horizontaux (480p)
    constant H_SYNC  : positive := 61;
    constant H_FP    : positive := 58;
    constant H_RES   : positive := 720;
    constant H_BP    : positive := 18;
    constant H_TOTAL : positive := H_SYNC + H_FP + H_RES + H_BP;   -- 857

    -- Timings verticaux (480p)
    constant V_SYNC  : positive := 5;
    constant V_FP    : positive := 30;
    constant V_RES   : positive := 480;
    constant V_BP    : positive := 9;
    constant V_TOTAL : positive := V_SYNC + V_FP + V_RES + V_BP;   -- 524

    signal tb_i_clk   : std_logic := '0';
    signal tb_i_rst_n : std_logic := '0';

    signal tb_hdmi_hs      : std_logic;
    signal tb_hdmi_vs      : std_logic;
    signal tb_hdmi_de      : std_logic;
    signal tb_pixel_en     : std_logic;

    signal tb_pixel_address : natural range 0 to (H_RES * V_RES - 1);
    signal tb_x_counter     : natural range 0 to (H_RES - 1);
    signal tb_y_counter     : natural range 0 to (V_RES - 1);

    signal tb_done : boolean := false;

begin

    uut : entity work.hdmi_controler
        generic map (
            h_res  => H_RES,
            v_res  => V_RES,
            h_sync => H_SYNC,
            h_fp   => H_FP,
            h_bp   => H_BP,
            v_sync => V_SYNC,
            v_fp   => V_FP,
            v_bp   => V_BP
        )
        port map (
            i_clk           => tb_i_clk,
            i_rst_n         => tb_i_rst_n,
            o_hdmi_hs       => tb_hdmi_hs,
            o_hdmi_vs       => tb_hdmi_vs,
            o_hdmi_de       => tb_hdmi_de,
            o_pixel_en      => tb_pixel_en,
            o_pixel_address => tb_pixel_address,
            o_x_counter     => tb_x_counter,
            o_y_counter     => tb_y_counter
        );

    -- Génération de l'horloge
    clock_process : process
    begin
        while not tb_done loop
            tb_i_clk <= '0';
            wait for T / 2;
            tb_i_clk <= '1';
            wait for T / 2;
        end loop;
        wait;
    end process;

    -- Stimuli et vérification
    test_process : process
        variable expected_hs : std_logic;
    begin
        -- Maintien du reset
        tb_i_rst_n <= '0';
        wait for 3 * T;

        -- Désactivation du reset
        tb_i_rst_n <= '1';

        ---------------------------------------------------------------------
        -- 1) Test horizontal : vérifie o_hdmi_hs sur une ligne complète
        ---------------------------------------------------------------------
        for counter in 0 to H_TOTAL loop

            wait until rising_edge(tb_i_clk);
            wait for 1 ns;

            if counter >= H_SYNC and counter /= H_TOTAL then
                expected_hs := '1';
            else
                expected_hs := '0';
            end if;

            assert tb_hdmi_hs = expected_hs
                report "Erreur sur o_hdmi_hs au compteur "
                        & integer'image(counter)
                severity error;
        end loop;

        report "Test horizontal terminé avec succès."
            severity note;

        ---------------------------------------------------------------------
        -- 2) Vérification que les autres sorties sont pilotées (pas de 'U')
        --    On laisse tourner quelques lignes ; les chronogrammes précis
        --    de o_hdmi_vs / r_v_active / o_hdmi_de / r_v_count se vérifient
        --    visuellement dans Modelsim (comme demandé par le TD).
        ---------------------------------------------------------------------
        for line in 0 to 50 loop
            for cycle in 0 to H_TOTAL loop
                wait until rising_edge(tb_i_clk);
                wait for 1 ns;

                -- o_hdmi_vs doit valoir '0' ou '1', jamais 'U'
                assert (tb_hdmi_vs = '0') or (tb_hdmi_vs = '1')
                    report "o_hdmi_vs est indéfini (non piloté par le contrôleur)"
                    severity error;

                -- o_hdmi_de doit valoir '0' ou '1', jamais 'U'
                assert (tb_hdmi_de = '0') or (tb_hdmi_de = '1')
                    report "o_hdmi_de est indéfini (non piloté par le contrôleur)"
                    severity error;

                -- o_pixel_en doit valoir '0' ou '1', jamais 'U'
                assert (tb_pixel_en = '0') or (tb_pixel_en = '1')
                    report "o_pixel_en est indéfini (non piloté par le contrôleur)"
                    severity error;

                -- Si on est en zone active, les compteurs doivent être
                -- dans leurs plages valides (déjà garanti par le range
                -- constraint sur les ports, mais on vérifie quand même).
                if tb_pixel_en = '1' then
                    assert tb_x_counter <= H_RES - 1
                        report "o_x_counter hors plage"
                        severity error;
                    assert tb_y_counter <= V_RES - 1
                        report "o_y_counter hors plage"
                        severity error;
                    assert tb_pixel_address <= (H_RES * V_RES) - 1
                        report "o_pixel_address hors plage"
                        severity error;
                end if;
            end loop;
        end loop;

        report "Test global terminé avec succès."
            severity note;
        tb_done <= true;
        wait;
    end process;

end architecture tb;
