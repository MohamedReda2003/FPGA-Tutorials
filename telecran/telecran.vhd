-------------------------------------------------------------------------------
-- telecran.vhd
-- ============
-- Top-level du projet "écran magique" sur DE10-Nano.
-- Version "Mémorisation" : framebuffer + tracer/effacer par re-passage.
--
-- Principe :
--   * Un framebuffer (RAM dual-port dpram) stocke l'état de chaque pixel
--     de l'écran (1 bit par pixel : 0 = noir, 1 = blanc).
--   * Port A (i_clk_50, 50 MHz) : écriture à la position de l'encodeur.
--     À chaque changement de position, la valeur stockée est INVERSÉE
--     (toggle) : passer une fois trace le trait, repasser l'efface.
--   * Port B (s_clk_27, 27 MHz) : lecture par le contrôleur HDMI à
--     l'adresse du pixel en cours d'affichage.
--
-- Conventions de nommage (cf. TP FPGA ENSEA) :
--   i_  : entrées        o_  : sorties
--   r_  : registres      s_  : signaux internes
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library pll;
use pll.all;

entity telecran is
    port (
        -- FPGA
        i_clk_50 : in std_logic;

        -- HDMI
        io_hdmi_i2c_scl : inout std_logic;
        io_hdmi_i2c_sda : inout std_logic;
        o_hdmi_tx_clk   : out std_logic;
        o_hdmi_tx_d     : out std_logic_vector(23 downto 0);
        o_hdmi_tx_de    : out std_logic;
        o_hdmi_tx_hs    : out std_logic;
        i_hdmi_tx_int   : in std_logic;
        o_hdmi_tx_vs    : out std_logic;

        -- KEY
        i_rst_n : in std_logic;

        -- LEDs
        o_leds      : out std_logic_vector(9 downto 0);
        o_de10_leds : out std_logic_vector(7 downto 0);

        -- Encodeurs
        i_left_ch_a  : in std_logic;
        i_left_ch_b  : in std_logic;
        i_left_pb    : in std_logic;
        i_right_ch_a : in std_logic;
        i_right_ch_b : in std_logic;
        i_right_pb   : in std_logic
    );
end entity telecran;

architecture rtl of telecran is

    -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
    -- Composants existants (PLL + config I2C ADV7513)
    -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
    component I2C_HDMI_Config
        port (
            iCLK        : in  std_logic;
            iRST_N      : in  std_logic;
            I2C_SCLK    : out std_logic;
            I2C_SDAT    : inout std_logic;
            HDMI_TX_INT : in  std_logic
        );
    end component;

    component pll
        port (
            refclk   : in  std_logic;
            rst      : in  std_logic;
            outclk_0 : out std_logic;
            locked   : out std_logic
        );
    end component;

    -- Résolution 480p
    constant h_res : positive := 720;
    constant v_res : positive := 480;

    -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
    -- Signaux internes (préfixe s_ pour les fils, r_ pour les registres)
    -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

    -- Horloge et reset produits par la PLL
    signal s_clk_27 : std_logic;
    signal s_rst_n  : std_logic;

    -- Compteurs pixel du contrôleur HDMI
    signal s_x_counter   : natural range 0 to (h_res - 1);
    signal s_y_counter   : natural range 0 to (v_res - 1);
    signal s_pixel_addr  : natural range 0 to (h_res * v_res - 1);

    -- Clock enable et positions encodeurs
    signal s_clk_en : std_logic;
    signal s_enc_x  : std_logic_vector(9 downto 0);   -- encodeur gauche -> x
    signal s_enc_y  : std_logic_vector(9 downto 0);   -- encodeur droit  -> y

    -- Framebuffer (RAM dual-port)
    signal s_fb_addr  : natural range 0 to (h_res * v_res - 1); -- adresse encodeur
    signal s_fb_we    : std_logic;                    -- write enable port A
    signal s_fb_wdata : std_logic_vector(0 downto 0); -- donnée écrite (inverse)
    signal s_fb_qa    : std_logic_vector(0 downto 0); -- valeur lue port A
    signal s_fb_qb    : std_logic_vector(0 downto 0); -- valeur lue port B (affichage)

    -- Détection de changement de position
    signal s_pos_changed   : std_logic;
    signal s_pos_on_screen : std_logic;

    -- Registres de la logique de tracé
    signal r_prev_x    : std_logic_vector(9 downto 0) := (others => '0');
    signal r_prev_y    : std_logic_vector(9 downto 0) := (others => '0');
    signal r_toggle_pending : std_logic := '0';  -- 1 cycle de retard pour la lecture RAM

    -- Effacement du framebuffer
    signal s_clr_busy : std_logic;                         -- effacement en cours
    signal s_clr_addr : natural range 0 to (h_res * v_res - 1);

    -- Signaux effectivement appliqués au port A de la RAM (tracé OU effacement)
    signal s_ram_addr_a : natural range 0 to (h_res * v_res - 1);
    signal s_ram_data_a : std_logic_vector(0 downto 0);
    signal s_ram_we_a   : std_logic;

begin

    -- =======================================================================
    -- PLL : 50 MHz -> 27 MHz (pixel clock pour le 480p)
    -- =======================================================================
    pll0 : component pll
        port map (
            refclk   => i_clk_50,
            rst      => not(i_rst_n),
            outclk_0 => s_clk_27,
            locked   => s_rst_n
        );

    -- =======================================================================
    -- Configuration I2C de l'ADV7513 (480p)
    -- =======================================================================
    I2C_HDMI_Config0 : component I2C_HDMI_Config
        port map (
            iCLK        => i_clk_50,
            iRST_N      => i_rst_n,
            I2C_SCLK    => io_hdmi_i2c_scl,
            I2C_SDAT    => io_hdmi_i2c_sda,
            HDMI_TX_INT => i_hdmi_tx_int
        );

    -- =======================================================================
    -- Contrôleur HDMI
    -- =======================================================================
    u_hdmi_controler : entity work.hdmi_controler
        generic map (
            h_res  => h_res,
            v_res  => v_res,
            h_sync => 61,
            h_fp   => 58,
            h_bp   => 18,
            v_sync => 5,
            v_fp   => 30,
            v_bp   => 9
        )
        port map (
            i_clk            => s_clk_27,
            i_rst_n          => s_rst_n,
            o_hdmi_hs        => o_hdmi_tx_hs,
            o_hdmi_vs        => o_hdmi_tx_vs,
            o_hdmi_de        => o_hdmi_tx_de,
            o_pixel_en       => open,
            o_pixel_address  => s_pixel_addr,   -- branché au framebuffer (port B)
            o_x_counter      => s_x_counter,
            o_y_counter      => s_y_counter
        );

    -- Horloge TMDS = pixel clock (27 MHz)
    o_hdmi_tx_clk <= s_clk_27;

    -- =======================================================================
    -- Clock enable : 50 MHz / 50 000 = 1 kHz pour échantillonner les encodeurs
    -- =======================================================================
    u_clk_en : entity work.clock_enable
        generic map (
            g_DIVISOR => 50000
        )
        port map (
            i_clk    => i_clk_50,
            i_rst_n  => s_rst_n,
            o_clk_en => s_clk_en
        );

    -- =======================================================================
    -- Effacement : un appui sur le bouton de l'encodeur gauche parcourt
    -- toute la RAM et y écrit des zéros
    -- =======================================================================
    u_ram_clear : entity work.ram_clear
        generic map (
            g_MEM_SIZE => h_res * v_res
        )
        port map (
            i_clk    => i_clk_50,
            i_rst_n  => s_rst_n,
            i_clk_en => s_clk_en,
            i_btn_n  => i_left_pb,
            o_busy   => s_clr_busy,
            o_addr   => s_clr_addr
        );

    -- =======================================================================
    -- Encodeur gauche -> x (horizontal), encodeur droit -> y (vertical)
    -- =======================================================================
    u_enc_x : entity work.encoder_counter
        generic map (
            g_BITS => 10
        )
        port map (
            i_clk     => i_clk_50,
            i_rst_n   => s_rst_n,
            i_clk_en  => s_clk_en,
            i_a       => i_left_ch_a,
            i_b       => i_left_ch_b,
            o_counter => s_enc_x
        );

    u_enc_y : entity work.encoder_counter
        generic map (
            g_BITS => 10
        )
        port map (
            i_clk     => i_clk_50,
            i_rst_n   => s_rst_n,
            i_clk_en  => s_clk_en,
            i_a       => i_right_ch_a,
            i_b       => i_right_ch_b,
            o_counter => s_enc_y
        );

    -- =======================================================================
    -- Affichage de la position sur les LEDs (debug)
    -- =======================================================================
    o_leds      <= s_enc_x;
    o_de10_leds <= s_enc_y(7 downto 0);

    -- =======================================================================
    -- Framebuffer : détection de changement de position
    --   On ne trace que lorsque la position CHANGE (pas quand le pixel
    --   reste immobile), sinon le pixel clignoterait sur place.
    -- =======================================================================
    s_pos_changed <= '1' when (s_enc_x /= r_prev_x) or (s_enc_y /= r_prev_y)
                     else '0';

    -- La position n'est traçable que si elle est dans l'écran
    -- (le compteur encodeur va jusqu'à 1023, l'écran ne fait que 720x480)
    s_pos_on_screen <= '1' when (to_integer(unsigned(s_enc_x)) < h_res)
                            and (to_integer(unsigned(s_enc_y)) < v_res)
                       else '0';

    -- Adresse framebuffer = y * h_res + x
    -- Calcul protégé : hors écran, on force 0 (jamais écrit car we=0)
    process(s_enc_x, s_enc_y)
    begin
        if (to_integer(unsigned(s_enc_x)) < h_res)
            and (to_integer(unsigned(s_enc_y)) < v_res) then
            s_fb_addr <= to_integer(unsigned(s_enc_y)) * h_res
                       + to_integer(unsigned(s_enc_x));
        else
            s_fb_addr <= 0;
        end if;
    end process;

    -- =======================================================================
    -- Logique de tracé (toggle) avec 1 cycle de retard :
    --   Cycle 1 : l'adresse change dans la RAM, o_q_a se met à jour à la
    --             fin du cycle avec l'ANCIENNE valeur stockée.
    --   Cycle 2 : on écrit l'inverse de l'ancienne valeur (toggle).
    --   r_toggle_pending crée ce délai d'un cycle.
    -- =======================================================================
    process(i_clk_50, s_rst_n)
    begin
        if (s_rst_n = '0') then
            r_prev_x         <= (others => '0');
            r_prev_y         <= (others => '0');
            r_toggle_pending <= '0';
        elsif rising_edge(i_clk_50) then
            if (r_toggle_pending = '1') then
                -- Cycle d'écriture : on mémorise la position courante
                -- comme "déjà traitée" et on relâche le pending.
                r_prev_x         <= s_enc_x;
                r_prev_y         <= s_enc_y;
                r_toggle_pending <= '0';
            elsif (s_pos_changed = '1') and (s_clr_busy = '0') then
                -- Nouvelle position : armer l'écriture (elle part au
                -- prochain cycle, une fois o_q_a à jour).
                r_toggle_pending <= '1';
            end if;
        end if;
    end process;

    -- Write enable : uniquement pendant le cycle d'écriture et si la
    -- position est dans l'écran.
    s_fb_we <= r_toggle_pending and s_pos_on_screen;

    -- Donnée écrite = inverse de la valeur actuellement stockée (toggle) :
    --   pixel éteint (0) -> allumé (1)  : on trace
    --   pixel allumé (1) -> éteint (0)  : on efface en repassant
    s_fb_wdata <= (0 => not s_fb_qa(0));

    -- =======================================================================
    -- Multiplexage du port A : l'effacement est prioritaire sur le tracé
    -- =======================================================================
    s_ram_addr_a <= s_clr_addr when (s_clr_busy = '1') else s_fb_addr;
    s_ram_data_a <= "0"        when (s_clr_busy = '1') else s_fb_wdata;
    s_ram_we_a   <= '1'        when (s_clr_busy = '1') else s_fb_we;

    -- =======================================================================
    -- Framebuffer : RAM dual-port (dpram.vhd fourni par le TP)
    --   Port A : écriture/lecture du tracé  (domaine i_clk_50, 50 MHz)
    --   Port B : lecture pour l'affichage   (domaine s_clk_27, 27 MHz)
    --
    --   data_width = 1 (1 bit par pixel) : 720x480 = 345 600 bits,
    --   soit quelques dizaines de blocs M10K sur les centaines disponibles
    --   dans le 5CSEBA6 du DE10-Nano. Avec data_width = 8 on consommerait
    --   8 fois plus (~2,8 Mbits) pour un affichage identique : inutile.
    --
    --   ATTENTION : i_we_b = '0' obligatoire (le port B ne fait que lire).
    --   Sans cela, l'adresse HDMI écrirait des zéros dans le framebuffer
    --   à chaque pixel affiché (i_we_b vaut '1' par défaut dans dpram).
    -- =======================================================================
    u_framebuffer : entity work.dpram
        generic map (
            mem_size   => h_res * v_res,     -- 345 600 pixels
            data_width => 1                  -- 1 bit par pixel
        )
        port map (
            -- Port A : tracé (domaine 50 MHz)
            i_clk_a  => i_clk_50,
            i_addr_a => s_ram_addr_a,
            i_data_a => s_ram_data_a,
            i_we_a   => s_ram_we_a,
            o_q_a    => s_fb_qa,

            -- Port B : affichage (domaine 27 MHz)
            i_clk_b  => s_clk_27,
            i_addr_b => s_pixel_addr,
            i_data_b => (0 => '0'),
            i_we_b   => '0',                 -- lecture seule !
            o_q_b    => s_fb_qb
        );

    -- =======================================================================
    -- Génération des pixels :
    --   blanc (x"FFFFFF") si le framebuffer contient 1 à l'adresse du pixel
    --   affiché, noir (x"000000") sinon.
    --
    --   La latence de lecture d'1 cycle du port B compense exactement le
    --   décalage d'1 cycle entre o_pixel_address (combinatoire) et
    --   o_hdmi_de (enregistré) : l'alignement est correct sans autre
    --   registre.
    -- =======================================================================
    o_hdmi_tx_d <= x"FFFFFF" when (s_fb_qb(0) = '1') else x"000000";

end architecture rtl;
