-- membank.vhd
--
-- Created on: 18 Jul 2017
--     Author: Fabian Meyer
--
-- 2 port memory bank component.

library ieee;
library work;

use ieee.std_logic_1164.all;
use work.fft_helpers.all;
use ieee.numeric_std.all;

entity membank is
    generic(RSTDEF:  std_logic := '0';
            ADDRLEN: natural   := 4);
    port(rst:    in  std_logic;                            -- reset, RSTDEF active
         clk:    in  std_logic;                            -- clock, rising edge
         swrst:  in  std_logic;                            -- software reset, RSTDEF active
         en:     in  std_logic;                            -- enable, high active
         addr1:  in  std_logic_vector(ADDRLEN-1 downto 0); -- address1
         addr2:  in  std_logic_vector(ADDRLEN-1 downto 0); -- address2
         en_wrt: in  std_logic;                            -- write enable for bank1, high active
         din1:   in  complex;                              -- input that will be stored
         din2:   in  complex;                              -- input that will be stored
         dout1:  out complex);                             -- output that is read from memory
         dout1:  out complex);                             -- output that is read from memory
end membank;

architecture behavioral of memory is

    -- memory bank of data
    signal bank: complex_arr(0 to (2**ADDRLEN)-1) := (others => COMPZERO);

    signal addr1_: unsigned(ADDRLEN-1 downto 0);
    signal addr2_: unsigned(ADDRLEN-1 downto 0);
begin

    addr1_ <= unsigned(addr1);
    addr2_ <= unsigned(addr2);

    process (rst, clk) is
    begin
        if rst = RSTDEF then
            bank <= (others => COMPZERO);
            dout1 <= COMPZERO;
            dout2 <= COMPZERO;
        elsif rising_edge(clk) then
            if swrst = RSTDEF then
                -- software reset to reinitialize component
                -- if needed
                bank <= (others => COMPZERO);
                dout1 <= COMPZERO;
                dout2 <= COMPZERO;
            elsif en = '1' then
                -- check if write bit is set for bank1
                if en_wrt = '1' then
                    bank(to_integer(addr1_)) <= din1;
                    bank(to_integer(addr2_)) <= din2;
                else
                    dout1 <= bank(to_integer(addr1_));
                    dout2 <= bank(to_integer(addr2_));
                end if;
            end if;
        end if;
    end process;

end behavioral;
