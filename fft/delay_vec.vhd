-- delay_vec.vhd
--
-- Created on: 08 Jun 2017
--     Author: Fabian Meyer
--
-- Component that delays an input vector by
-- a given amount of cycles.

library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity delay_vec is
    generic(RSTDEF:   std_logic := '0';
            DATALEN:  natural := 8;
            DELAYLEN: natural := 8);
    port(rst:   in  std_logic;                              -- reset, RSTDEF active
         clk:   in  std_logic;                              -- clock, rising edge
         swrst: in  std_logic;                              -- software reset, RSTDEF active
         en:    in  std_logic;                              -- enable, high active
         din:   in  std_logic_vector(DATALEN-1 downto 0);   -- data in
         dout:  out std_logic_vector(DATALEN-1 downto 0));  -- data out
end entity;

architecture behavioral of delay_vec is
    -- vector through which signal is chained
    type del_dat is array(DELAYLEN-1 downto 0) of std_logic_vector(DATALEN-1 downto 0);
    constant ZERODAT: std_logic_vector(DATALEN-1 downto 0) := (others => '0');

    signal dvec: del_dat := (others => ZERODAT);
begin

    dout <= dvec(DELAYLEN-1);

    process(rst, clk)
    begin
        if rst = RSTDEF then
            dvec <= (others => ZERODAT);
        elsif rising_edge(clk) then
            if swrst = RSTDEF then
                dvec <= (others => ZERODAT);
            elsif en = '1' then
                dvec <= dvec(DELAYLEN-1 downto 1) & din;
            end if;
        end if;
    end process;
end architecture;
