-- membank_tb.vhd
--
-- Created on: 19 Jul 2017
--     Author: Fabian Meyer

library ieee;
library work;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fft_helpers.all;

entity membank_tb is
end entity;

architecture behavioral of membank_tb is

    -- Component Declaration for the Unit Under Test (UUT)
    component membank
    generic(RSTDEF:  std_logic := '0';
            FFTEXP:  natural   := 4);
    port(rst:    in  std_logic;                           -- reset, RSTDEF active
         clk:    in  std_logic;                           -- clock, rising edge
         swrst:  in  std_logic;                           -- software reset, RSTDEF active
         en:     in  std_logic;                           -- enable, high active
         addr1:  in  std_logic_vector(FFTEXP-1 downto 0); -- address1
         addr2:  in  std_logic_vector(FFTEXP-1 downto 0); -- address2
         en_wrt: in  std_logic;                           -- write enable for bank1, high active
         din1:   in  complex;                             -- input1 that will be stored
         din2:   in  complex;                             -- input2 that will be stored
         dout1:  out complex;                             -- output1 that is read from memory
         dout2:  out complex);                            -- output2 that is read from memory
    end component;

    -- Clock period definitions
    constant clk_period: time := 10 ns;

    -- Generics
    constant RSTDEF: std_logic := '0';
    constant FFTEXP: natural   := 3; -- 8-point FFT

    -- Inputs
    signal rst:     std_logic := '0';
    signal clk:     std_logic := '0';
    signal swrst:   std_logic := '0';
    signal en:      std_logic := '0';
    signal addr1:   std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal addr2:   std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal en_wrt:  std_logic := '0';
    signal din1:    complex := COMPZERO;
    signal din2:    complex := COMPZERO;

    -- Outputs
    signal dout1:   complex := COMPZERO;
    signal dout2:   complex := COMPZERO;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: membank
        generic map(RSTDEF => RSTDEF,
                    FFTEXP => FFTEXP)
        port map(rst     => rst,
                 clk     => clk,
                 swrst   => swrst,
                 en      => en,
                 addr1   => addr1,
                 addr2   => addr2,
                 en_wrt  => en_wrt,
                 din1    => din1,
                 din2    => din2,
                 dout1   => dout1,
                 dout2   => dout2);

    -- Clock process definitions
    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Stimulus process
    stim_proc: process

        procedure read_data(addr1_n, addr2_n: natural) is
        begin
            en_wrt <= '0';

            addr1 <= std_logic_vector(to_unsigned(addr1_n, FFTEXP));
            addr2 <= std_logic_vector(to_unsigned(addr2_n, FFTEXP));

            wait for clk_period;
        end procedure;

        procedure write_data(addr1_n, addr2_n: natural;
                             dat1, dat2:   complex) is
        begin
            en_wrt <= '1';

            addr1 <= std_logic_vector(to_unsigned(addr1_n, FFTEXP));
            addr2 <= std_logic_vector(to_unsigned(addr2_n, FFTEXP));

            din1 <= dat1;
            din2 <= dat2;

            wait for clk_period;
        end procedure;

        constant test_data: complex_arr(0 to (2**FFTEXP)-1) := (
            (X"000010",X"000100"),
            (X"000001",X"000030"),
            (X"000500",X"000001"),
            (X"0000ff",X"0000f0"),
            (X"000f01",X"000fff"),
            (X"00055f",X"0001f5"),
            (X"000110",X"00030f"),
            (X"00001f",X"000105")
        );
    begin
        -- hold reset state for 100 ns.
        wait for clk_period*10;

        rst <= '1';
        swrst <= '1';
        en <= '1';

        for i in 0 to 3 loop
            write_data(2*i, (2*i)+1, test_data(2*i), test_data((2*i)+1));
        end loop;

        for i in 0 to 3 loop
            read_data(2*i, (2*i)+1);
        end loop;

        wait;
    end process;

end;
