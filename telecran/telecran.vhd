-------------------------------------------------------------------------------
-- telecran.vhd
-- ============
-- Top-level du projet "écran magique" sur DE10-Nano.
--
-- Conventions de nommage (cf. TP FPGA ENSEA) :
--   i_  : entrées
--   o_  : sorties
--   r_  : registres (assignés dans un process cadencé)
--   s_  : signaux internes
--
-- Cette version instancie :
--   * la PLL (50 MHz -> 27 MHz pixel clock),
--   * la config I2C de l'ADV7513,
--   * le contrôleur HDMI (hdmi_controler),
--   * un générateur de clock enable (clock_enable) pour échantillonner
--     les encodeurs à 1 kHz à partir du 50 MHz,
--   * deux décodeurs-compteurs d'encodeur (encoder_counter) :
--       - encodeur gauche  -> position x (horizontale)
--       - encodeur droit    -> position y (verticale)
--
-- Affichage : un pixel blanc (x"FFFFFF") à la position (enc_x, enc_y),
--             fond noir (x"000000") partout ailleurs.
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

    -- Composants existants (PLL + config I2C ADV7513)
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
    -- Signaux internes (préfixe s_)
    -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

    -- Horloge et reset produits par la PLL (noms imposés par le TP)
    signal s_clk_27 : std_logic;
    signal s_rst_n  : std_logic;          -- reste à 0 tant que la PLL n'est pas verrouillée

    -- Compteurs pixel du contrôleur HDMI
    signal s_x_counter : natural range 0 to (h_res - 1);
    signal s_y_counter : natural range 0 to (v_res - 1);

    -- Clock enable pour les encodeurs (1 kHz à partir de 50 MHz)
    signal s_clk_en : std_logic;

    -- Positions encodeur (10 bits chacune, affichables sur les LEDs)
    signal s_enc_x : std_logic_vector(9 downto 0);  -- encodeur gauche  -> x
    signal s_enc_y : std_logic_vector(9 downto 0);  -- encodeur droit   -> y

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
    -- Contrôleur HDMI (instanciation conforme au TP)
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
            o_pixel_address  => open,
            o_x_counter      => s_x_counter,
            o_y_counter      => s_y_counter
        );

    -- Horloge TMDS = pixel clock (27 MHz)
    o_hdmi_tx_clk <= s_clk_27;

    -- =======================================================================
    -- Clock enable : produit une pulse toutes les 50 000 cycles de i_clk_50
    --   50 MHz / 50 000 = 1 kHz  ->  échantillonnage encodeur à 1 kHz
    -- =======================================================================
    u_clk_en : entity work.clock_enable
        generic map (
            g_DIVISOR => 50000      -- 1 kHz
        )
        port map (
            i_clk    => i_clk_50,
            i_rst_n  => s_rst_n,
            o_clk_en => s_clk_en
        );

    -- =======================================================================
    -- Encodeur gauche  -> position x (horizontale)
    -- Encodeur droit    -> position y (verticale)
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
    -- Affichage de la position x sur les 10 LEDs de la mezzanine
    -- et des 8 bits de poids faible de y sur les LEDs de la DE10-Nano.
    -- (Cf. TP : "On pourra choisir une taille de 10 pour afficher la
    --  valeur en binaire sur les LED.")
    -- =======================================================================
    o_leds      <= s_enc_x;
    o_de10_leds <= s_enc_y(7 downto 0);

    -- =======================================================================
    -- Génération du pixel : blanc à la position encodeur, noir ailleurs
    --   "attribuer la valeur blanche (x"FFFFFF") au signal o_hdmi_tx_d
    --    quand les valeurs x et y des encodeurs sont égales à celles
    --    des compteurs du contrôleur HDMI. Dans le cas contraire,
    --    attribuer la valeur noire (x"000000")."
    -- =======================================================================
    o_hdmi_tx_d <= x"FFFFFF" when (to_integer(unsigned(s_enc_x)) = s_x_counter)
                              and (to_integer(unsigned(s_enc_y)) = s_y_counter)
                   else x"000000";

end architecture rtl;
