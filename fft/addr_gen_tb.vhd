-- addr_gen_tb.vhd
--
-- Created on: 19 Jul 2017
--     Author: Fabian Meyer

library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity addr_gen_tb is
end entity;

architecture behavioral of addr_gen_tb is

    -- Component Declaration for the Unit Under Test (UUT)
    component addr_gen
    generic(RSTDEF: std_logic := '0';
            FFTEXP: natural   := 4);
    port(rst:     in  std_logic;                            -- reset, RSTDEF active
         clk:     in  std_logic;                            -- clock, rising edge
         swrst:   in  std_logic;                            -- software reset, RSTDEF active
         en:      in  std_logic;                            -- enable, high active
         lvl:     in  std_logic_vector(FFTEXP-2 downto 0);  -- iteration level of butterflies
         bfno:    in  std_logic_vector(FFTEXP-2 downto 0);  -- butterfly number in current level
         addra1:  out std_logic_vector(FFTEXP-1 downto 0);  -- address1 for membank A
         addra2:  out std_logic_vector(FFTEXP-1 downto 0);  -- address2 for membank A
         en_wrta: out std_logic;                            -- write enable for membank A, high active
         addrb1:  out std_logic_vector(FFTEXP-1 downto 0);  -- address1 for membank B
         addrb2:  out std_logic_vector(FFTEXP-1 downto 0);  -- address2 for membank B
         en_wrtb: out std_logic;                            -- write enable for membank B, high active
         addrtf:  out std_logic_vector(FFTEXP-2 downto 0)); -- twiddle factor address
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
    signal lvl:     std_logic_vector(FFTEXP-2 downto 0) := (others => '0');
    signal bfno:    std_logic_vector(FFTEXP-2 downto 0) := (others => '0');

    -- Outputs
    signal addra1:  std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal addra2:  std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal en_wrta: std_logic := '0';
    signal addrb1:  std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal addrb2:  std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal en_wrtb: std_logic := '0';
    signal addrtf:  std_logic_vector(FFTEXP-2 downto 0) := (others => '0');

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: addr_gen
        generic map(RSTDEF => RSTDEF,
                    FFTEXP => FFTEXP)
        port map(rst     => rst,
                 clk     => clk,
                 swrst   => swrst,
                 en      => en,
                 lvl     => lvl,
                 bfno    => bfno,
                 addra1  => addra1,
                 addra2  => addra2,
                 en_wrta => en_wrta,
                 addrb1  => addrb1,
                 addrb2  => addrb2,
                 en_wrtb => en_wrtb,
                 addrtf  => addrtf);

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

        procedure inc_step is
            variable tmp: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
        begin
            tmp := std_logic_vector(unsigned('0' & bfno) + 1);
            bfno <= tmp(FFTEXP-2 downto 0);

            -- check if butterflies had overflow
            -- then we reach next level of FFT
            -- remark: bfno is always one bit too long
            if tmp(FFTEXP-1) = '1' then
                lvl <= std_logic_vector(unsigned(lvl) + 1);
            end if;

            wait for clk_period;
        end procedure;

    begin
        -- hold reset state for 100 ns.
        wait for clk_period*10;

        rst <= '1';
        swrst <= '1';
        en <= '1';

        wait for clk_period;

        -- do 11 steps after initial for full 8-point FFT
        for i in 0 to 10 loop
            inc_step;
        end loop;

        wait;
    end process;

end;
