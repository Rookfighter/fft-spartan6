-- memory.vhd
--
-- Created on: 18 Jul 2017
--     Author: Fabian Meyer
--
-- memory component that allows simultanuous read and write
-- with two different memory banks.

library ieee;
library work;

use ieee.std_logic_1164.all;
use work.fft_helpers.all;
use ieee.numeric_std.all;

entity memory is
    generic(RSTDEF:  std_logic := '0';
            ADDRLEN: natural   := 4);
    port(rst:    in  std_logic;                            -- reset, RSTDEF active
         clk:    in  std_logic;                            -- clock, rising edge
         swrst:  in  std_logic;                            -- software reset, RSTDEF active
         en:     in  std_logic;                            -- enable, high active
         addr_r: in  std_logic_vector(ADDRLEN-1 downto 0); -- read address
         addr_w: in  std_logic_vector(ADDRLEN-1 downto 0); -- write address
         write1: in  std_logic;                            -- write enable for bank1, high active
         write2: in  std_logic;                            -- write enable for bank2, high active
         din:    in  complex;                              -- input that will be stored
         dout:   out complex);                             -- output that is read from memory
end memory;

architecture behavioral of memory is

    -- memory banks of data
    signal bank1: complex_arr(0 to (2**ADDRLEN)-1) := (others => COMPZERO);
    signal bank2: complex_arr(0 to (2**ADDRLEN)-1) := (others => COMPZERO);

begin

    process (rst, clk) is
    begin
        if rst = RSTDEF then
            bank1 <= (others => COMPZERO);
            bank2 <= (others => COMPZERO);
            dout <= COMPZERO;
        elsif rising_edge(clk) then
            if swrst = RSTDEF then
                -- software reset to reinitialize component
                -- if needed
                bank1 <= (others => COMPZERO);
                bank2 <= (others => COMPZERO);
                dout <= COMPZERO;
            elsif en = '1' then
                -- check if write bit is set for bank1
                if write1 = '1' then
                    bank1(to_integer(unsigned(addr_w))) <= din;
                else
                    dout <= bank1(to_integer(unsigned(addr_r)));
                end if;

                -- check if write bit is set for bank 2
                if write2 = '1' then
                    bank2(to_integer(unsigned(addr_w))) <= din;
                else
                    dout <= bank2(to_integer(unsigned(addr_r)));
                end if;
            end if;
        end if;
    end process;

end behavioral;
