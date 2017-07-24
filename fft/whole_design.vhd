-- whole_design.vhd
--
-- Created on: 17 Jul 2017
--     Author: Fabian Meyer
--
-- Whole integration of 16-point FFT communicating over I2C.

library ieee;
library work;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fft_helpers.all;

entity whole_design is
    generic(RSTDEF: std_logic := '0');
    port(rst:      in    std_logic;                     -- reset, RSTDEF active
         clk:      in    std_logic;                     -- clock, rising edge
         sda:      inout std_logic;                     -- serial data of I2C
         scl:      inout std_logic);                    -- serial clock of I2C
end whole_design;

architecture behavioral of whole_design is

    -- import i2c slave
    component i2c_slave
    generic(RSTDEF:  std_logic := '0';
           ADDRDEF: std_logic_vector(6 downto 0) := "0100000");
    port(rst:     in    std_logic;                    -- reset, RSTDEF active
         clk:     in    std_logic;                    -- clock, rising edge
         tx_data: in    std_logic_vector(7 downto 0); -- tx, data to send
         tx_sent: out   std_logic;                    -- tx was sent, high active
         rx_data: out   std_logic_vector(7 downto 0); -- rx, data received
         rx_recv: out   std_logic;                    -- rx received, high active
         busy:    out   std_logic;                    -- busy, high active
         sda:     inout std_logic;                    -- serial data of I2C
         scl:     inout std_logic);                   -- serial clock of I2C
    end component;

    -- import fft16 component
    component fft16
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

    constant FFTEXP: natural := 16;
    constant DELSTARTFFT: natural := 2;

    -- INTERNALS
    -- =========

    -- define states for FSM of whole design
    type TState is (SIDLE, SRECV, SRUN, SSEND1, SSEND2);
    signal state: TState := SIDLE;

    -- INPUTS
    -- ======

    signal byte_cnt: unsigned(1 downto 0) := (others => '0');
    signal sample_cnt: unsigned(FFTEXP-1 downto 0) := (others => '0');

    -- send buffer for I2C
    signal tx_data_i2c: std_logic_vector(7 downto 0) := (others => '0');

    signal en_fft:     std_logic := '1';
    signal start_fft:  std_logic := '0';
    signal set_fft:    std_logic := '0';
    signal get_fft:    std_logic := '0';
    signal din_fft:    complex   := COMPZERO;

    signal din_start_fft: std_logic := '0';

    -- OUTPUTS
    -- =======

    -- receive buffer for I2C
    signal rx_data_i2c: std_logic_vector(7 downto 0);
    signal rx_recv_i2c: std_logic;
    signal tx_sent_i2c: std_logic;
    signal busy_i2c: std_logic;

    signal done_fft: std_logic;
    signal dout_fft: complex;

    signal dout_start_fft: std_logic;

begin

    start_fft <= dout_start_fft;

    process(rst, clk) is
        procedure reset is
        begin
            state <= SIDLE;

            -- reset counters
            byte_cnt <= (others => '0');
            sample_cnt <= (others => '0');

            -- reset I2C
            tx_data_i2c <= (others => '0');

            -- reset fft
            en_fft <= '1';
            set_fft <= '0';
            get_fft <= '0';
            din_fft <= (COMPZERO);

            -- reset delay start
            din_start_fft <= '0';
        end procedure;

        variable byte_cnt_shift: unsigned(1 downto 0) := (others => '0');
    begin
        if rst = RSTDEF then
            reset;
        elsif rising_edge(clk) then
            -- always only stay high for one cylce
            din_start_fft <= '0';
            -- only stay high for one cycle
            get_fft <= '0';
            set_fft <= '0';

            case state is
                when SIDLE =>
                    -- we have received something
                    if rx_recv_i2c = '1' then
                        state <= SRECV;

                        byte_cnt <= byte_cnt + 1;
                        byte_cnt_shift := shift_left(byte_cnt, 3);
                        din_fft.r(FIXLEN-to_integer(byte_cnt_shift)-1 downto FIXLEN-to_integer(byte_cnt_shift)-8)
                            <= signed(rx_data_i2c);
                    end if;
                when SRECV =>
                    -- disable fft until we get next number
                    en_fft <= '0';

                    if rx_recv_i2c = '1' then
                        -- received another byte

                        byte_cnt <= byte_cnt + 1;
                        byte_cnt_shift := shift_left(byte_cnt, 3);
                        din_fft.r(FIXLEN-to_integer(byte_cnt_shift)-1 downto FIXLEN-to_integer(byte_cnt_shift)-8)
                            <= signed(rx_data_i2c);

                        if byte_cnt = "10" then
                            -- we have received 3 bytes
                            -- now enable fft for 1 cycle to read this value
                            set_fft <= '1';
                            en_fft <= '1';
                            -- reset byte_cnt
                            byte_cnt <= (others => '0');
                            -- inc sample counter
                            sample_cnt <= sample_cnt + 1;

                            if sample_cnt = "1111" then
                                -- we have received all samples
                                -- go into computation mode
                                state <= SRUN;
                                -- reset sample counter
                                sample_cnt <= (others => '0');
                                -- trigger start of FFT
                                din_start_fft <= '1';
                            end if;
                        end if;
                    end if;
                when SRUN =>
                    -- if fft is done and start signal is not set, it has finished
                    -- computing and we can send the result
                    if dout_start_fft = '0' and done_fft = '1' then
                        -- send get signal
                        get_fft <= '1';
                        state <= SSEND1;
                    end if;
                when SSEND1 =>
                    state <= SSEND2;
                when SSEND2 =>
                    en_fft <= '0';

                    if busy_i2c = '0' then
                        -- increment byte counter
                        byte_cnt <= byte_cnt + 1;
                        byte_cnt_shift := shift_left(byte_cnt, 3);
                        -- apply current result data to I2C component
                        tx_data_i2c <= std_logic_vector(
                                dout_fft.r(FIXLEN-to_integer(byte_cnt_shift)-1 downto FIXLEN-to_integer(byte_cnt_shift)-8)
                            );

                        -- if we have sent 3 bytes then go to next result
                        if byte_cnt = "10" then
                            -- enable FFT for one cycle to get next result
                            en_fft <= '1';

                            -- reset byte_cnt
                            byte_cnt <= (others => '0');
                            -- inc sample counter
                            sample_cnt <= sample_cnt + 1;

                            -- if sample counter is full we just sent last result
                            if sample_cnt = "1111" then
                                sample_cnt <= (others => '0');
                                state <= SIDLE;
                            end if;
                        end if;
                    end if;
            end case;
        end if;
    end process;

    i2c: i2c_slave
        generic map(RSTDEF  => RSTDEF,
                    ADDRDEF => "0100000")
        port map(rst     => rst,
                 clk     => clk,
                 tx_data => tx_data_i2c,
                 tx_sent => tx_sent_i2c,
                 rx_data => rx_data_i2c,
                 rx_recv => rx_recv_i2c,
                 busy    => busy_i2c,
                 sda     => sda,
                 scl     => scl);

    fft: fft16
        generic map(RSTDEF  => RSTDEF)
        port map(rst   => rst,
                 clk   => clk,
                 swrst => not RSTDEF,
                 en    => en_fft,
                 start => start_fft,
                 set   => set_fft,
                 get   => get_fft,
                 din   => din_fft,
                 done  => done_fft,
                 dout  => dout_fft);

    del_start_fft: delay_bit
        generic map(RSTDEF   => RSTDEF,
                    DELAYLEN => DELSTARTFFT)
        port map(rst   => rst,
                 clk   => clk,
                 swrst => not RSTDEF,
                 en    => '1',
                 din   => din_start_fft,
                 dout  => dout_start_fft);

end architecture;
