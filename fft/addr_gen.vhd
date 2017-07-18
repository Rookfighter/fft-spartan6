-- addr_gen.vhd
--
-- Created on: 18 Jul 2017
--     Author: Fabian Meyer
--

library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity addr_gen is
    generic(RSTDEF: std_logic := '0';
            ADDRLEN: natural  := 4;
            LVLLEN: natural   := 3);
    port(rst:     in  std_logic;                             -- reset, RSTDEF active
         clk:     in  std_logic;                             -- clock, rising edge
         swrst:   in  std_logic;                             -- software reset, RSTDEF active
         en:      in  std_logic;                             -- enable, high active
         lvl:     in  std_logic_vector(LVLLEN-1 downto 0);   -- iteration level of butterflies
         bfno:    in  std_logic_vector(ADDRLEN-1 downto 0);  -- butterfly number in current level
         addra1:  out std_logic_vector(ADDRLEN-1 downto 0);  -- address1 for membank A
         addra2:  out std_logic_vector(ADDRLEN-1 downto 0);  -- address2 for membank A
         en_wrta: out std_logic;                             -- write enable for membank A, high active
         addrb1:  out std_logic_vector(ADDRLEN-1 downto 0);  -- address1 for membank B
         addrb2:  out std_logic_vector(ADDRLEN-1 downto 0);  -- address2 for membank B
         en_wrtb: out std_logic;                             -- write enable for membank B, high active
         addrtf:  out std_logic_vector(ADDRLEN-1 downto 0)); -- twiddle factor address
end addr_gen;

architecture behavioral of addr_gen is
    signal en_wrta_t: std_logic := '0';
begin

    -- if lvl is even then en_wrta is active
    -- if it is odd then en_wrtb is active
    en_wrta_t <= not lvl(0);

    process(rst, clk) is
        -- reset this component
        procedure reset is
        begin
            addra1  <= (others => '0');
            addra2  <= (others => '0');
            en_wrta <= '0';
            addrb1  <= (others => '0');
            addrb2  <= (others => '0');
            en_wrtb <= '0';
            addrtf  <= (others => '0');
        end;

        -- calculates the read address
        function read_addr(x: std_logic_vector(ADDRLEN-1 downto 0);
                           y: std_logic_vector(LVLLEN-1 downto 0))
                           return std_logic_vector is
        begin
            -- rotate left y times
            return std_logic_vector(rotate_left(unsigned(x), to_integer(unsigned(y))));
        end function;

        variable tfidx: natural := 0;
        variable j:     std_logic_vector(ADDRLEN-1 downto 0) := (others => '0');
        variable j_inc: std_logic_vector(ADDRLEN-1 downto 0) := (others => '0');

    begin
        if rst = RSTDEF then
            reset;
        elsif rising_edge(clk) then
            if swrst = RSTDEF then
                -- software reset to reinitialize component
                -- if needed
                reset;
            elsif en = '1' then
                -- make sure only one write enable is set at a time
                en_wrta <= en_wrta_t;
                en_wrtb <= not en_wrta_t;

                -- calc twiddle factor address
                tfidx := ADDRLEN-2-to_integer(unsigned(lvl));
                addrtf <= (others => '0');
                addrtf(ADDRLEN-1 downto tfidx) <= bfno(ADDRLEN-1 downto tfidx);

                -- pre compute j for address generation
                j     := std_logic_vector(shift_left(unsigned(bfno), 1));
                j_inc := std_logic_vector(unsigned(j) + 1);

                if en_wrta_t = '1' then
                    -- a is the one to write

                    -- target write address is simply in order
                    -- addr1: current bfno * 2
                    -- addr2: (current bfno * 2) + 1
                    addra1 <= j;
                    addra1 <= j_inc;

                    addrb1 <= read_addr(j, lvl);
                    addrb2 <= read_addr(j_inc, lvl);
                else
                    -- b is the one to write

                    -- target write address is simply in order
                    -- addr1: current bfno * 2
                    -- addr2: (current bfno * 2) + 1
                    addrb1 <= j;
                    addrb1 <= j_inc;

                    addra1 <= read_addr(j, lvl);
                    addra2 <= read_addr(j_inc, lvl);
                end if;
            end if;
        end if;
    end process;

end behavioral;
