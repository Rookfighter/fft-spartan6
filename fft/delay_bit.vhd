-- delay_bit.vhd
--
-- Created on: 08 Jun 2017
--     Author: Fabian Meyer
--
-- Component that delays an input bit by
-- a given amount of cycles.

library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity delay_bit is
    generic(RSTDEF:   std_logic := '0';
            DELAYLEN: natural := 8);
    port(rst:   in  std_logic;   -- reset, RSTDEF active
         clk:   in  std_logic;   -- clock, rising edge
         swrst: in  std_logic;   -- software reset, RSTDEF active
         en:    in  std_logic;   -- enable, high active
         din:   in  std_logic;   -- data in
         dout:  out std_logic);  -- data out
end entity;

architecture behavioral of delay_bit is
    -- vector through which signal is chained
    signal dvec: std_logic_vector(DELAYLEN-1 downto 0) := (others => '0');
begin

    dout <= dvec(DELAYLEN-1);

    process(rst, clk)
    begin
        if rst = RSTDEF then
            dvec <= (others => '0');
        elsif rising_edge(clk) then
            if swrst = RSTDEF then
                dvec <= (others => '0');
            elsif en = '1' then
                dvec <= dvec(DELAYLEN-2 downto 0) & din;
            end if;
        end if;
    end process;
end architecture;
