library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity chenillard is
    port (
        i_clk   : in  std_logic;                     -- FPGA_CLK1_50 : PIN_AF14
        i_rst_n : in  std_logic;                     -- KEY0         : PIN_AH17
        o_leds   : out std_logic_vector(7 downto 0)   -- LED0..LED7
    );
end entity chenillard;

architecture rtl of chenillard is

    -- periode du pas : 1 000 000 coups d'horloge = 20 ms a 50 MHz
    constant C_MAX    : natural := 1_000_000;
    constant C_TICK   : natural := C_MAX - 1;

    signal r_counter  : natural range 0 to C_TICK;
    signal r_tick     : std_logic;              -- impulsion 'avance d'un pas'
    signal r_led      : std_logic_vector(7 downto 0) := "00000001";
    signal r_dir      : std_logic;              -- '0' = vers LED7, '1' = vers LED0

begin

    ------------------------------------------------------------------
    -- Diviseur d'horloge : genere un tick toutes les 20 ms
    ------------------------------------------------------------------
    process(i_clk, i_rst_n)
    begin
        if i_rst_n = '0' then
            r_counter <= 0;
            r_tick    <= '0';
        elsif rising_edge(i_clk) then
            if r_counter = C_TICK then
                r_counter <= 0;
                r_tick    <= '1';
            else
                r_counter <= r_counter + 1;
                r_tick    <= '0';
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- Registre a decalage + gestion de la direction
    ------------------------------------------------------------------
    process(i_clk, i_rst_n)
    begin
        if i_rst_n = '0' then
            r_led <= "00000001";
            r_dir <= '0';
        elsif rising_edge(i_clk) then
            if r_tick = '1' then
                if r_dir = '0' then
                    r_led <= r_led(6 downto 0) & '0';   -- decalage vers la gauche
                else
                    r_led <= '0' & r_led(7 downto 1);   -- decalage vers la droite
                end if;

                -- inversion de direction aux bouts
                if r_led = "10000000" then
                    r_dir <= '1';
                elsif r_led = "00000001" then
                    r_dir <= '0';
                end if;
            end if;
        end if;
    end process;

    o_leds <= r_led;

end architecture rtl;