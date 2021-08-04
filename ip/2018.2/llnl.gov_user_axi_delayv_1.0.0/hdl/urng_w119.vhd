LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

entity urng_w119 is
  generic(
    W:integer:=119
  );
  port(
    clk:in std_logic;
    ce : in std_logic;
    load_en : in std_logic;
    load_data : in std_logic;
    rng:out std_logic_vector(W-1 downto 0)
  );
end urng_w119;

architecture RTL of urng_w119 is
begin
  assert W=119 report "This RNG only does W=119" severity failure;

  the : entity work.rng_n119_r119_t5_k0_s16a6
    port map(clk=>clk,ce=>ce,mode=>load_en,s_in=>load_data,rng=>rng);
end RTL;
