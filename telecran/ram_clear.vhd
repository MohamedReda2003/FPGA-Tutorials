library ieee;
use ieee.std_logic_1164.all;

entity ram_clear is
    generic (
        g_MEM_SIZE : positive := 720 * 480  -- Nombre d'adresses du framebuffer
    );
    port (
        i_clk    : in  std_logic;  -- Horloge système (50 MHz)
        i_rst_n  : in  std_logic;  -- Reset asynchrone (actif bas)
        i_clk_en : in  std_logic;  -- Impulsion 1 kHz (échantillonnage du bouton)
        i_btn_n  : in  std_logic;  -- Bouton poussoir (actif bas : '0' = appuyé)
        o_busy   : out std_logic;  -- '1' pendant l'effacement (= écriture de '0')
        o_addr   : out natural range 0 to g_MEM_SIZE - 1  -- Adresse à effacer
    );
end entity ram_clear;

architecture rtl of ram_clear is

    type t_state is (IDLE, CLEARING);
    signal r_state : t_state := IDLE;

    -- Échantillonnage du bouton (2 bascules D, comme pour les encodeurs)
    signal r_btn_pipe : std_logic_vector(1 downto 0) := "11";
    signal s_press    : std_logic;

    signal r_addr : natural range 0 to g_MEM_SIZE - 1 := 0;

begin

    ------------------------------------------------------------------
    -- 1. Échantillonnage du bouton à 1 kHz (filtre anti-rebond)
    ------------------------------------------------------------------
    process(i_clk, i_rst_n)
    begin
        if (i_rst_n = '0') then
            r_btn_pipe <= "11";
        elsif rising_edge(i_clk) then
            if (i_clk_en = '1') then
                r_btn_pipe <= r_btn_pipe(0) & i_btn_n;
            end if;
        end if;
    end process;

    -- Appui = front descendant (bouton actif bas : 1 avant, 0 maintenant)
    s_press <= r_btn_pipe(1) and not r_btn_pipe(0);

    ------------------------------------------------------------------
    -- 2. Machine à états : parcours de toutes les adresses
    ------------------------------------------------------------------
    process(i_clk, i_rst_n)
    begin
        if (i_rst_n = '0') then
            r_state <= IDLE;
            r_addr  <= 0;
        elsif rising_edge(i_clk) then
            case r_state is
                when IDLE =>
                    r_addr <= 0;
                    if (s_press = '1' and i_clk_en = '1') then
                        r_state <= CLEARING;
                    end if;

                when CLEARING =>
                    if (r_addr = g_MEM_SIZE - 1) then
                        r_state <= IDLE;
                        r_addr  <= 0;
                    else
                        r_addr <= r_addr + 1;
                    end if;
            end case;
        end if;
    end process;

    o_busy <= '1' when (r_state = CLEARING) else '0';
    o_addr <= r_addr;

end architecture rtl;
