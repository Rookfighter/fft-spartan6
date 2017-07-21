-- fft16.vhd
--
-- Created on: 20 Jul 2017
--     Author: Fabian Meyer
--
-- Integration component for 16-point FFT.

library ieee;
library work;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fft_helpers.all;

entity fft16 is
    generic(RSTDEF: std_logic := '0');
    port(rst:     in  std_logic; -- reset, RSTDEF active
         clk:     in  std_logic; -- clock, rising edge
         swrst:   in  std_logic; -- software reset, RSTDEF active
         en:      in  std_logic; -- enable, high active
         start:   in  std_logic; -- start FFT, high active
         set:     in  std_logic; -- load FFT with values, high active
         get:     in  std_logic; -- read FFT results, high active
         din:     in  complex;   -- datain for loading FFT
         done:    out std_logic; -- FFT is done, active high
         dout:    out complex);  -- data out for reading results
end fft16;

architecture behavioral of fft16 is

    -- import addr_gen component
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

    -- import membank component
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

    -- import butterfly component
    component butterfly
    generic(RSTDEF: std_logic := '0');
    port(rst:   in std_logic;  -- reset, RSTDEF active
         clk:   in std_logic;  -- clock, rising edge
         swrst: in std_logic;  -- software reset, RSTDEF active
         en:    in std_logic;  -- enable, high active
         din1:  in  complex;   -- first complex in val
         din2:  in  complex;   -- second complex in val
         w:     in  complex;   -- twiddle factor
         dout1: out complex;   -- first complex out val
         dout2: out complex);  -- second complex out val
    end component;

    -- import delay elemnt for logic vectors
    component delay_vec
    generic(RSTDEF:   std_logic := '0';
            DATALEN:  natural := 8;
            DELAYLEN: natural := 8);
    port(rst:   in  std_logic;                              -- reset, RSTDEF active
         clk:   in  std_logic;                              -- clock, rising edge
         swrst: in  std_logic;                              -- software reset, RSTDEF active
         en:    in  std_logic;                              -- enable, high active
         din:   in  std_logic_vector(DATALEN-1 downto 0);   -- data in
         dout:  out std_logic_vector(DATALEN-1 downto 0));  -- data out
    end component;

    -- import delay element for bits
    component delay_bit
    generic(RSTDEF:   std_logic := '0';
            DELAYLEN: natural := 8);
    port(rst:   in  std_logic;   -- reset, RSTDEF active
         clk:   in  std_logic;   -- clock, rising edge
         swrst: in  std_logic;   -- software reset, RSTDEF active
         en:    in  std_logic;   -- enable, high active
         din:   in  std_logic;   -- data in
         dout:  out std_logic);  -- data out
    end component;

    -- import twiddle factor component
    component tf16
    generic(RSTDEF: std_logic := '0';
            FFTEXP: natural   := 4);
    port(rst:   in  std_logic;                           -- reset, RSTDEF active
         clk:   in  std_logic;                           -- clock, rising edge
         swrst: in  std_logic;                           -- software reset, RSTDEF active
         en:    in  std_logic;                           -- enable, high active
         addr:  in  std_logic_vector(FFTEXP-2 downto 0); -- address of twiddle factor
         w:     out complex);                            -- twiddle factor
    end component;

    -- define this FFT as 16-point (exponent = 4)
    constant FFTEXP: natural := 4;
    -- delay write address by 3 cycles
    constant DELWADDR: natural := 3;
    constant DELENAGU: natural := 3;

    -- define states for FSM of FFT
    type TState is (SIDLE, SSET, SGET, SRUN, SENDLVL);
    signal state: TState := SIDLE;

    -- signal to control enable of agu
    signal en_agu_con: std_logic := '0';

    -- address signals from agu to membank A
    signal addra1_agu: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal addra2_agu: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal en_wrta_agu: std_logic := '0';
    -- address signals from agu to membank B
    signal addrb1_agu: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal addrb2_agu: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal en_wrtb_agu: std_logic := '0';
    -- enable signal for agu
    signal en_agu:   std_logic := '0';
    signal lvl_agu:  std_logic_vector(FFTEXP-2 downto 0) := (others => '0');
    signal bfno_agu: std_logic_vector(FFTEXP-2 downto 0) := (others => '0');
    -- address signal for twiddle factor
    signal addrtf_agu: std_logic_vector(FFTEXP-2 downto 0) := (others => '0');

    -- address signals for membank A
    signal addr1_mema: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal addr2_mema: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    -- write signal for membank A
    signal en_wrt_mema: std_logic := '0';
    -- data in ports for membank A
    signal din1_mema: complex := COMPZERO;
    signal din2_mema: complex := COMPZERO;
    --data out ports for membank A
    signal dout1_mema: complex := COMPZERO;
    signal dout2_mema: complex := COMPZERO;

    -- address signals for membank B
    signal addr1_memb: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal addr2_memb: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    -- write signal for membank B
    signal en_wrt_memb: std_logic := '0';
    -- data in ports for membank B
    signal din1_memb: complex := COMPZERO;
    signal din2_memb: complex := COMPZERO;
    --data out ports for membank A
    signal dout1_memb: complex := COMPZERO;
    signal dout2_memb: complex := COMPZERO;

    -- data in ports for butterfly
    signal din1_bf: complex := COMPZERO;
    signal din2_bf: complex := COMPZERO;
    -- data out ports for butterfly
    signal dout1_bf: complex := COMPZERO;
    signal dout2_bf: complex := COMPZERO;
    -- twiddle factor for butterfly
    signal w_bf: complex := COMPZERO;

    -- address signal for twiddle factor unit
    signal addr_tf: std_logic_vector(FFTEXP-2 downto 0) := (others => '0');
    -- data out port for twiddle factor unit
    signal w_tf: complex := COMPZERO;

    -- data in ports for write address delay
    signal din_waddr1: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal din_waddr2: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    -- data out ports for write address delay
    signal dout_waddr1: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal dout_waddr2: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');

    -- data in port for enable agu delay
    signal din_enagu: std_logic := '0';
    -- data out port for enable agu delay
    signal dout_enagu: std_logic := '0';

    signal addr_cnt: unsigned(FFTEXP-1 downto 0) := (others => '0');
    signal addr_rev: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');

begin

    -- done is set if we are in IDLE state
    done <= '1' when state = SIDLE else '0';

    -- multiplex enable signal for agu
    en_agu <= '0' when en = '0' else en_agu_con;

    -- calc bit reversed address
    gen_rev: for i in 0 to FFTEXP-1 generate
        addr_rev(i) <= std_logic(addr_cnt(FFTEXP-1 - i));
    end generate;

    process(clk, rst) is
        -- reset this component
        procedure reset is
        begin
            state <= SIDLE;

            -- reset agu
            lvl_agu    <= (others => '0');
            bfno_agu   <= (others => '0');
            en_agu_con <= '0';

            -- reset membank A
            addr1_mema <= (others => '0');
            addr2_mema <= (others => '0');
            din1_mema  <= COMPZERO;
            din2_mema  <= COMPZERO;
            en_wrt_mema <= '0';

            -- reset membank B
            addr1_memb <= (others => '0');
            addr2_memb <= (others => '0');
            din1_memb  <= COMPZERO;
            din2_memb  <= COMPZERO;
            en_wrt_memb <= '0';

            -- reset butterfly
            din1_bf <= COMPZERO;
            din2_bf <= COMPZERO;
            w_bf <= COMPZERO;

            -- reset twiddle factor unit
            addr_tf <= (others => '0');

            -- reset write address delay element
            din_waddr1 <= (others => '0');
            din_waddr2 <= (others => '0');

            -- reset enable agu delay element
            din_enagu <= '0';

            --reset address counter
            addr_cnt <= (others => '0');
        end;
    begin
        if rst = RSTDEF then
            reset;
        elsif rising_edge(clk) then
            if swrst = RSTDEF then
                reset;
            elsif en = '1' then
                -- process state machine
                case state is
                    when SIDLE =>
                        if set = '1' then
                            -- "set" signal received
                            state <= SSET;

                            -- store transmitted values in membank A in
                            -- bit reversed order
                            -- already store first value from din
                            addr_cnt <= addr_cnt + 1;
                            addr1_mema <= addr_rev;
                            din1_mema <= din;

                            -- also set addr2 and din2 and leave them so they
                            -- will not overwrite any values in the process
                            addr2_mema <= addr_rev;
                            din2_mema <= din;

                            -- enable write mode for membank A
                            en_wrt_mema <= '1';
                        elsif get = '1' then
                            -- "get" signal received
                            state <= SGET;

                            -- read values from membank B in normal order
                            -- addr_cnt defines address to be read
                            -- membanks should always be in read mode when
                            -- FSM is idle
                            addr_cnt <= addr_cnt + 1;
                            addr1_memb <= std_logic_vector(addr_cnt);
                        elsif start = '1' then
                            -- "start" signal received
                            state <= SRUN;
                            -- enable agu
                            en_agu_con <= '1';
                        end if;
                    when SSET  =>
                        -- increment address count
                        -- bit reversed address will be updated automatically
                        addr_cnt <= addr_cnt + 1;
                        addr1_mema <= addr_rev;
                        din1_mema <= din;

                        -- if counter had overflow go back to idle state
                        -- and reset all used resources
                        if addr_cnt = "0000" then
                            -- reset membank addresses and data in ports
                            addr1_mema <= (others => '0');
                            din1_mema <= COMPZERO;
                            addr2_mema <= (others => '0');
                            din2_mema <= COMPZERO;
                            -- disable write mode on membank A
                            en_wrt_mema <= '0';
                            -- reset addr_cnt
                            addr_cnt <= (others => '0');
                            -- go back to idle mode
                            state <= SIDLE;
                        end if;
                    when SGET  =>
                        -- increment address count
                        -- this is the address that we read from
                        addr_cnt <= addr_cnt + 1;
                        addr1_memb <= std_logic_vector(addr_cnt);
                        dout <= dout1_memb;

                        -- if counter had overflow go back to idle state
                        -- and reset all used resources
                        if addr_cnt = "0000" then
                            -- reset addr1 of membank B
                            addr1_memb <= (others => '0');
                            -- set data out to zero
                            dout <= COMPZERO;
                            -- reset addr_cnt
                            addr_cnt <= (others => '0');
                            -- go back to idle mode
                            state <= SIDLE;
                        end if;
                    when SRUN =>
                        -- execute pipeline
                        -- ================
                        -- apply write enables from agu
                        en_wrt_mema <= en_wrta_agu;
                        en_wrt_memb <= en_wrtb_agu;
                        -- apply address twiddle factor
                        addr_tf <= addrtf_agu;
                        -- apply twiddle factor
                        w_bf <= w_tf;

                        -- apply addresses for membanks and
                        -- values from membanks
                        if en_wrta_agu = '1' then
                            -- membank A is in write mode

                            -- feed address of A into delay element
                            din_waddr1 <= addra1_agu;
                            din_waddr2 <= addra2_agu;
                            -- get address for A from delay element
                            addr1_mema <= dout_waddr1;
                            addr2_mema <= dout_waddr2;
                            -- get address directly from AGU
                            addr1_memb <= addrb1_agu;
                            addr2_memb <= addrb2_agu;

                            -- apply values from membank B to butterfly
                            din1_bf <= dout1_memb;
                            din2_bf <= dout2_memb;

                            -- apply values from butterfly to membank A
                            din1_mema <= dout1_bf;
                            din2_mema <= dout2_bf;
                        else
                            -- membank B is in write mode

                            -- feed address of B into delay element
                            din_waddr1 <= addrb1_agu;
                            din_waddr2 <= addrb2_agu;
                            -- get address for mema from delay element
                            addr1_memb <= dout_waddr1;
                            addr2_memb <= dout_waddr2;
                            -- get address directly from AGU
                            addr1_mema <= addra1_agu;
                            addr2_mema <= addra2_agu;

                            -- apply values from membank A to butterfly
                            din1_bf <= dout1_mema;
                            din2_bf <= dout2_mema;

                            -- apply values from butterfly to membank B
                            din1_memb <= dout1_bf;
                            din2_memb <= dout2_bf;
                        end if;

                        -- increment butterfly every cycle
                        bfno_agu <= std_logic_vector(unsigned(bfno_agu) + 1);

                        -- if we have reached last butterfly wait for pipeline
                        -- to finish
                        if bfno_agu = "111" then
                            en_agu_con <= '0';
                            din_enagu <= '1';
                            state <= SENDLVL;
                        end if;
                    when SENDLVL =>
                        din_enagu <= '0';

                        -- wait unit enable signal reaches us
                        if dout_enagu = '1' then
                            -- reset butterfly number
                            bfno_agu <= (others => '0');

                            if lvl_agu = "011" then
                                -- final level was reached: we are done
                                -- reset all internal states
                                -- membanks not included!
                                state <= SIDLE;
                                reset;
                            else
                                -- go to next level
                                -- enable agu again
                                lvl_agu <= std_logic_vector(unsigned(lvl_agu) + 1);
                                en_agu_con <= '1';
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;

    -- create instance of address generation unit
    agu: addr_gen
        generic map(RSTDEF => RSTDEF,
                    FFTEXP => FFTEXP)
        port map(rst     => rst,
                 clk     => clk,
                 swrst   => swrst,
                 en      => en_agu,
                 lvl     => lvl_agu,
                 bfno    => bfno_agu,
                 addra1  => addra1_agu,
                 addra2  => addra2_agu,
                 en_wrta => en_wrta_agu,
                 addrb1  => addrb1_agu,
                 addrb2  => addrb2_agu,
                 en_wrtb => en_wrtb_agu,
                 addrtf  => addrtf_agu);

    -- create instance of twiddle factor unit
    tfu: tf16
        generic map(RSTDEF => RSTDEF,
                    FFTEXP => FFTEXP)
        port map(rst   => rst,
                 clk   => clk,
                 swrst => swrst,
                 en    => en,
                 addr  => addr_tf,
                 w     => w_tf);

    -- create instance of memory bank A
    mem_a: membank
        generic map(RSTDEF => RSTDEF,
                    FFTEXP => FFTEXP)
        port map(rst    => rst,
                 clk    => clk,
                 swrst  => swrst,
                 en     => en,
                 addr1  => addr1_mema,
                 addr2  => addr2_mema,
                 en_wrt => en_wrt_mema,
                 din1   => din1_mema,
                 din2   => din2_mema,
                 dout1  => dout1_mema,
                 dout2  => dout2_mema);

    -- create instance of memory bank B
    mem_b: membank
        generic map(RSTDEF => RSTDEF,
                    FFTEXP => FFTEXP)
        port map(rst    => rst,
                 clk    => clk,
                 swrst  => swrst,
                 en     => en,
                 addr1  => addr1_memb,
                 addr2  => addr2_memb,
                 en_wrt => en_wrt_memb,
                 din1   => din1_memb,
                 din2   => din2_memb,
                 dout1  => dout1_memb,
                 dout2  => dout2_memb);

    -- create instance of butterfly unit
    bfu: butterfly
        generic map(RSTDEF => RSTDEF)
        port map(rst   => rst,
                 clk   => clk,
                 swrst => swrst,
                 en    => en,
                 din1  => din1_bf,
                 din2  => din2_bf,
                 w     => w_bf,
                 dout1 => dout1_bf,
                 dout2 => dout2_bf);

    -- create instance of delay unit for write address 1
    del_waddr1: delay_vec
        generic map(RSTDEF   => RSTDEF,
                    DATALEN  => FFTEXP,
                    DELAYLEN => DELWADDR)
        port map(rst   => rst,
                 clk   => clk,
                 swrst => swrst,
                 en    => en,
                 din   => din_waddr1,
                 dout  => dout_waddr1);

     -- create instance of delay unit for write address 1
     del_waddr2: delay_vec
         generic map(RSTDEF   => RSTDEF,
                     DATALEN  => FFTEXP,
                     DELAYLEN => DELWADDR)
         port map(rst   => rst,
                  clk   => clk,
                  swrst => swrst,
                  en    => en,
                  din   => din_waddr2,
                  dout  => dout_waddr2);

    -- create instance of delay unit for enable signal of agu
    del_enagu: delay_bit
        generic map(RSTDEF   => RSTDEF,
                    DELAYLEN => DELENAGU)
        port map(rst   => rst,
                 clk   => clk,
                 swrst => swrst,
                 en    => en,
                 din   => din_enagu,
                 dout  => dout_enagu);
end;
