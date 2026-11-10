-------------------------------------------------------------------------------
-- hdmi_controler.vhd  (version corrigée)
-- Contrôleur HDMI pour ADV7513 sur DE10-Nano.
-- Conformément au TD3 "Contrôleur HDMI" de l'ENSEA (mineure FPGA).
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity hdmi_controler is
    generic (
        h_res : positive := 720;
        v_res : positive := 480;

        h_sync : positive := 61;
        h_fp   : positive := 58;
        h_bp   : positive := 18;

        v_sync : positive := 5;
        v_fp   : positive := 30;
        v_bp   : positive := 9
    );
    port (
        i_clk   : in  std_logic;
        i_rst_n : in  std_logic;

        o_hdmi_hs : out std_logic;
        o_hdmi_vs : out std_logic;
        o_hdmi_de : out std_logic;

        o_pixel_en      : out std_logic;
        o_pixel_address : out natural range 0 to (h_res * v_res - 1);
        o_x_counter     : out natural range 0 to (h_res - 1);
        o_y_counter     : out natural range 0 to (v_res - 1)
    );
end entity hdmi_controler;

architecture rtl of hdmi_controler is

    -- Constantes horizontales (cf. TD "Synchro horizontale")
    constant h_start : positive := h_sync + h_fp;       -- 119
    constant h_end   : positive := h_start + h_res;     -- 839
    constant h_total : positive := h_end + h_bp;        -- 857

    -- Constantes verticales (structure miroir de la synchro horizontale)
    constant v_start : positive := v_sync + v_fp;       -- 35
    constant v_end   : positive := v_start + v_res;     -- 515
    constant v_total : positive := v_end + v_bp;        -- 524

    -- Registres internes synchro horizontale
    signal r_h_counter : natural range 0 to h_total := 0;
    signal r_h_active  : std_logic := '0';

    -- Registres internes synchro verticale
    signal r_v_counter : natural range 0 to v_total := 0;
    signal r_v_active  : std_logic := '0';

    -- Signaux internes pour les compteurs pixel (en VHDL-93 on ne peut pas
    -- relire un port 'out' à l'intérieur de l'architecture ; on passe donc
    -- par des registres internes recopiés sur les ports de sortie).
    signal r_x_counter     : natural range 0 to (h_res - 1) := 0;
    signal r_y_counter     : natural range 0 to (v_res - 1) := 0;
    signal r_pixel_address : natural range 0 to (h_res * v_res - 1) := 0;

begin

    ---------------------------------------------------------------------------
    -- Synchro horizontale
    --   * Compte de 0 à h_total puis wrap.
    --   * o_hdmi_hs = '1' si counter >= h_sync ET counter /= h_total, sinon '0'.
    --   * r_h_active passe à '1' sur h_start, à '0' sur h_end.
    ---------------------------------------------------------------------------
    p_horizontal : process(i_clk, i_rst_n)
    begin
        if (i_rst_n = '0') then
            r_h_counter <= 0;
            r_h_active  <= '0';
            o_hdmi_hs   <= '1';   -- CORRECTION : init manquante dans la version d'origine
        elsif rising_edge(i_clk) then
            -- Compteur de ligne
            if (r_h_counter = h_total) then
                r_h_counter <= 0;
            else
                r_h_counter <= r_h_counter + 1;
            end if;

            -- Génération de HSYNC (actif bas)
            if (r_h_counter >= h_sync) and (r_h_counter /= h_total) then
                o_hdmi_hs <= '1';
            else
                o_hdmi_hs <= '0';
            end if;

            -- Drapeau "pixel actif" horizontal
            if (r_h_counter = h_start) then
                r_h_active <= '1';
            elsif (r_h_counter = h_end) then
                r_h_active <= '0';
            end if;
        end if;
    end process p_horizontal;

    ---------------------------------------------------------------------------
    -- Synchro verticale
    --   Identique à la synchro horizontale, mais le compteur n'évolue QUE
    --   lorsque le compteur horizontal atteint h_total (fin de ligne).
    ---------------------------------------------------------------------------
    p_vertical : process(i_clk, i_rst_n)
    begin
        if (i_rst_n = '0') then
            r_v_counter <= 0;
            r_v_active  <= '0';
            o_hdmi_vs   <= '1';   -- inactif au reset
        elsif rising_edge(i_clk) then
            -- Le compteur vertical ne bouge qu'en fin de ligne horizontale
            if (r_h_counter = h_total) then
                -- Compteur de trame
                if (r_v_counter = v_total) then
                    r_v_counter <= 0;
                else
                    r_v_counter <= r_v_counter + 1;
                end if;

                -- Génération de VSYNC (actif bas)
                if (r_v_counter >= v_sync) and (r_v_counter /= v_total) then
                    o_hdmi_vs <= '1';
                else
                    o_hdmi_vs <= '0';
                end if;

                -- Drapeau "ligne active" vertical
                if (r_v_counter = v_start) then
                    r_v_active <= '1';
                elsif (r_v_counter = v_end) then
                    r_v_active <= '0';
                end if;
            end if;
        end if;
    end process p_vertical;

    ---------------------------------------------------------------------------
    -- Data Enable (registre)
    --   o_hdmi_de = r_v_active AND r_h_active
    ---------------------------------------------------------------------------
    p_de : process(i_clk, i_rst_n)
    begin
        if (i_rst_n = '0') then
            o_hdmi_de <= '0';
        elsif rising_edge(i_clk) then
            o_hdmi_de <= r_v_active and r_h_active;
        end if;
    end process p_de;

    ---------------------------------------------------------------------------
    -- Générateur d'adresse et de coordonnées pixel
    --   o_pixel_en      : valide pendant les pixels actifs (combinatoire)
    --   o_x_counter     : 0..h_res-1, colonne active courante
    --   o_y_counter     : 0..v_res-1, ligne active courante
    --   o_pixel_address : 0..(h_res*v_res)-1, adresse linéaire
    ---------------------------------------------------------------------------
    o_pixel_en      <= r_v_active and r_h_active;
    o_x_counter     <= r_x_counter;
    o_y_counter     <= r_y_counter;
    o_pixel_address <= r_pixel_address;

    p_pixel : process(i_clk, i_rst_n)
    begin
        if (i_rst_n = '0') then
            r_x_counter     <= 0;
            r_y_counter     <= 0;
            r_pixel_address <= 0;
        elsif rising_edge(i_clk) then
            if (r_v_active = '1') and (r_h_active = '1') then
                -- Incrémentation de l'adresse linéaire (avec wrap)
                if (r_pixel_address = (h_res * v_res) - 1) then
                    r_pixel_address <= 0;
                else
                    r_pixel_address <= r_pixel_address + 1;
                end if;

                -- Coordonnées (x, y) synchronisées
                if (r_x_counter = h_res - 1) then
                    r_x_counter <= 0;
                    if (r_y_counter = v_res - 1) then
                        r_y_counter <= 0;
                    else
                        r_y_counter <= r_y_counter + 1;
                    end if;
                else
                    r_x_counter <= r_x_counter + 1;
                end if;
            end if;
        end if;
    end process p_pixel;

end architecture rtl;
