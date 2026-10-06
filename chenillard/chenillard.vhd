library ieee;
use ieee.std_logic_1164.all;

entity chenillard is
  port (
    i_clk    : in  std_logic;
    i_rst_n  : in  std_logic;
    o_leds   : out std_logic_vector(5 downto 0)
  );
end entity chenillard;

architecture rtl of chenillard is

  constant C_MAX : natural := 5_000_000;  -- tick toutes les 0,1 s (50 MHz)

  signal r_counter : natural range 0 to C_MAX := 0;
  signal r_tick    : std_logic := '0';
  signal r_leds    : std_logic_vector(5 downto 0) := "000001";

begin

  -- Compteur de ralentissement : génère une impulsion r_tick
  process(i_clk, i_rst_n)
  begin
    if (i_rst_n = '0') then
      r_counter <= 0;
      r_tick    <= '0';
    elsif (rising_edge(i_clk)) then
      if (r_counter = C_MAX) then
        r_counter <= 0;
        r_tick    <= '1';
      else
        r_counter <= r_counter + 1;
        r_tick    <= '0';
      end if;
    end if;
  end process;

  -- Registre du motif : décale le '1' à chaque tick
  process(i_clk, i_rst_n)
  begin
    if (i_rst_n = '0') then
      r_leds <= "000001";
    elsif (rising_edge(i_clk)) then
      if (r_tick = '1') then
        r_leds <= r_leds(4 downto 0) & r_leds(5);  -- rotation circulaire
      end if;
    end if;
  end process;

  o_leds <= r_leds;

end architecture rtl;