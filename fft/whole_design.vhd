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

    constant FFTEXP: natural := 4;
    -- =========

    -- define states for FSM of whole design
    type TState is (SIDLE, SRECV, SRUN1, SRUN2, SSEND1, SSEND2, SSEND3);
    signal state: TState := SIDLE;
    
    signal tx_data_tmp: std_logic_vector(7 downto 0) := (others => '0');

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

    -- OUTPUTS
    -- =======

    -- receive buffer for I2C
    signal rx_data_i2c: std_logic_vector(7 downto 0);
    signal rx_recv_i2c: std_logic;
    signal tx_sent_i2c: std_logic;
    signal busy_i2c: std_logic;

    signal done_fft: std_logic;
    signal dout_fft: complex;

begin

    -- convert high to Z for i2c send buffer
    i2c_out: for i in 7 downto 0 generate
        tx_data_i2c(i) <= 'Z' when tx_data_tmp(i) = '1' else '0';
    end generate;

    process(rst, clk) is
        procedure reset is
        begin
            state <= SIDLE;

            -- reset counters
            byte_cnt <= (others => '0');
            sample_cnt <= (others => '0');

            -- reset I2C
            tx_data_tmp <= (others => '0');

            -- reset fft
            en_fft <= '1';
            set_fft <= '0';
            get_fft <= '0';
            din_fft <= (COMPZERO);
            start_fft <= '0';

        end procedure;

        variable byte_cnt_shift: unsigned(4 downto 0) := (others => '0');
        variable byte_start: natural := 0;
        variable byte_end: natural := 0;
    begin
        if rst = RSTDEF then
            reset;
        elsif rising_edge(clk) then
            -- only stay high for one cycle
            start_fft <= '0';
            get_fft <= '0';
            set_fft <= '0';

            case state is
                when SIDLE =>
                    -- we have received something
                    if rx_recv_i2c = '1' then
                        state <= SRECV;

                        en_fft <= '0';
                        byte_cnt <= byte_cnt + 1;
                        -- multiply byte count by 8
                        byte_cnt_shift := shift_left(resize(byte_cnt, 5), 3);
                        byte_start := FIXLEN-to_integer(byte_cnt_shift)-1;
                        byte_end := FIXLEN-to_integer(byte_cnt_shift)-8;
                        -- write rx of I2C to din of FFT
                        din_fft.r( byte_start downto byte_end) <= signed(rx_data_i2c);
                    end if;

                    -- we have sent something
                    -- first byte is without any information
                    -- it just indicates that someone wants to read
                    if tx_sent_i2c = '1' then
                        -- send get signal
                        get_fft <= '1';
                        state <= SSEND1;
                    end if;
                when SRECV =>
                    -- disable fft until we get next number
                    en_fft <= '0';

                    if rx_recv_i2c = '1' then
                        -- received another byte

                        byte_cnt <= byte_cnt + 1;
                        -- multiply byte count by 8
                        byte_cnt_shift := shift_left(resize(byte_cnt, 5), 3);
                        byte_start := FIXLEN-to_integer(byte_cnt_shift)-1;
                        byte_end := FIXLEN-to_integer(byte_cnt_shift)-8;
                        -- write rx of I2C to din of FFT
                        din_fft.r(byte_start downto byte_end) <= signed(rx_data_i2c);

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
                                state <= SRUN1;
                                -- reset sample counter
                                sample_cnt <= (others => '0');
                            end if;
                        end if;
                    end if;
                when SRUN1 =>
                    if done_fft = '1' then
                        -- wait until fft is done and has finished writing data to memory
                        -- the start computing FFT
                        start_fft <= '1';
                        state <= SRUN2;
                    end if;
                when SRUN2 =>
                    if start_fft = '0' and done_fft = '1' then
                        -- go back to idle mode, fft is done
                        state <= SIDLE;
                    end if;
                when SSEND1 =>
                    byte_cnt <= byte_cnt + 1;
                    if byte_cnt = "01" then
                        byte_cnt <= (others => '0');
                        state <= SSEND2;
                    end if;
                when SSEND2 =>
                    en_fft <= '0';

                    if tx_sent_i2c = '1' then
                        -- if we have sent the byte process next one
                        byte_cnt <= byte_cnt + 1;
                        -- multiply byte count by 8
                        byte_cnt_shift := shift_left(resize(byte_cnt, 5), 3);
                        byte_start := FIXLEN-to_integer(byte_cnt_shift)-1;
                        byte_end := FIXLEN-to_integer(byte_cnt_shift)-8;
                        -- apply current result data to I2C component
                        tx_data_tmp <= std_logic_vector(dout_fft.r(byte_start downto byte_end));

                        -- if we have sent 3 bytes then go to next result
                        if byte_cnt = "10" then
                            -- enable FFT for one cycle to get next result
                            en_fft <= '1';

                            -- reset byte_cnt
                            byte_cnt <= (others => '0');
                            -- inc sample counter
                            sample_cnt <= sample_cnt + 1;

                            -- if sample counter overflows we just sent last result
                            if sample_cnt = "1111" then
                                sample_cnt <= (others => '0');
                                state <= SSEND3;
                            end if;
                        end if;
                    end if;
                when SSEND3 =>
                    -- wait until also last byte was sent
                    if tx_sent_i2c = '1' then
                        state <= SIDLE;
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
end architecture;
