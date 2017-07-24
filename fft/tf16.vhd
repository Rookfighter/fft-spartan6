-- tf16.vhd
--
-- Created on: 17 Jul 2017
--     Author: Fabian Meyer
--
-- Clock synchronous twiddle factor provider for 16-point FFT.

library ieee;
library work;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fft_helpers.all;

entity tf16 is
    generic(RSTDEF: std_logic := '0';
            FFTEXP: natural   := 4);
    port(rst:   in  std_logic;                           -- reset, RSTDEF active
         clk:   in  std_logic;                           -- clock, rising edge
         swrst: in  std_logic;                           -- software reset, RSTDEF active
         en:    in  std_logic;                           -- enable, high active
         addr:  in  std_logic_vector(FFTEXP-2 downto 0); -- address of twiddle factor
         w:     out complex);                            -- twiddle factor
end tf16;

architecture behavioral of tf16 is

    -- twiddle factors for 16-Point FFT
    constant WFACS: complex_arr(0 to (2**(FFTEXP-1))-1) := (
        to_complex(1.0, 0.0),
        to_complex(0.9239, 0.3827),
        to_complex(0.7071, 0.7071),
        to_complex(0.3827, 0.9239),
        to_complex(0.0, 1.0),
        to_complex(-0.3827, 0.9239),
        to_complex(-0.7071, 0.7071),
        to_complex(-0.9239, 0.3827)
    );

    signal w_tmp: complex := COMPZERO;

begin

    w <= w_tmp;

    process(rst, clk) is
    begin
        if rst = RSTDEF then
            w_tmp <= COMPZERO;
        elsif rising_edge(clk) then
            if swrst = RSTDEF then
                w_tmp <= COMPZERO;
            elsif en = '1' then
                w_tmp <= WFACS(to_integer(unsigned(addr)));
            end if;
        end if;
    end process;

end architecture;
