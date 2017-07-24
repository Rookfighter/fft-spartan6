-- i2c_slave.vhd
--
-- Created on: 08 Jun 2017
--     Author: Fabian Meyer

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_slave is
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
end entity;

architecture behavioral of i2c_slave is

    component delay_bit
    generic(RSTDEF: std_logic := '0';
            DELAYLEN: natural := 8);
    port(rst:   in  std_logic;   -- reset, RSTDEF active
         clk:   in  std_logic;   -- clock, rising edge
         swrst: in std_logic;
         en:    in std_logic;
         din:   in  std_logic;   -- data in
         dout:  out std_logic);  -- data out
    end component;

    -- states for FSM
    type TState is (SIDLE, SADDR, SSEND_ACK1, SSEND_ACK2, SRECV_ACK, SREAD, SWRITE);
    signal state: TState := SIDLE;

    -- constant to define cycles per time unit
    constant CLKPERMS: natural := 24000;

    -- counter for measuring time to timeout after 1ms
    constant TIMEOUTLEN:  natural := 15;
    signal   cnt_timeout: unsigned(TIMEOUTLEN-1 downto 0) := (others => '0');

    -- data vector for handling traffic internally
    constant DATALEN: natural := 8;
    signal   data:    std_logic_vector(DATALEN-1 downto 0) := (others => '0');

    -- determines if master reqested read (high) or write (low)
    signal rwbit: std_logic := '0';

    -- sda signal delayed by 1us
    signal sda_del: std_logic := '0';
    -- i2c vectors to store previous and current signal
    signal scl_vec: std_logic_vector(1 downto 0) := (others => '0');
    signal sda_vec: std_logic_vector(1 downto 0) := (others => '0');

    -- counter to count bits received / sent
    signal cnt_bit: unsigned(2 downto 0) := (others => '0');
begin

    -- always let master handle scl
    scl <= 'Z';
    -- lsb is current scl
    scl_vec(0) <= scl;
    -- lsb is delayed sda
    sda_vec(0) <= sda_del;
    -- always busy if not in idle mode
    busy <= '0' when state = SIDLE else '1';

    -- delay sda signal by 24 cylces (= 1us)
    delay1: delay_bit
        generic map(RSTDEF => RSTDEF,
                    DELAYLEN => 24)
        port map(rst   => rst,
                 clk   => clk,
                 swrst => not RSTDEF,
                 en    => '1',
                 din   => sda,
                 dout  => sda_del);

    process(clk, rst)
    begin
        if rst = RSTDEF then
            tx_sent <= '0';
            rx_data <= (others => '0');
            rx_recv <= '0';
            sda <= 'Z';
            state <= SIDLE;
            cnt_timeout <= (others => '0');
            data <= (others => '0');
            rwbit <= '0';
            scl_vec(1) <= '0';
            sda_vec(1) <= '0';
            cnt_bit <= (others => '0');
        elsif rising_edge(clk) then
            -- keep track of previous sda and scl (msb)
            sda_vec(1) <= sda_vec(0);
            scl_vec(1) <= scl_vec(0);

            -- leave sent and recv signals high only one cylce
            tx_sent <= '0';
            rx_recv <= '0';

            -- check for timeout
            cnt_timeout <= cnt_timeout + 1;
            if scl_vec = "01" then
                -- reset timeout on rising scl
                cnt_timeout <= (others => '0');
            elsif to_integer(cnt_timeout) = CLKPERMS then
                -- timeout is reached go into idle state
                cnt_timeout <= (others => '0');
                state <= SIDLE;
                sda <= 'Z';
            end if;

            -- compute state machine for i2c slave
            case state is
                when SIDLE =>
                    -- do nothing
                when SADDR =>
                    if scl_vec = "01" then
                        -- set data bit depending on cnt_bit
                        data(7-to_integer(cnt_bit)) <= sda_vec(0);
                        cnt_bit <= cnt_bit + 1;

                        -- if cnt_bit is full then we have just received last bit
                        if cnt_bit = "111" then
                            rwbit <= sda_vec(0);
                            if data(DATALEN-1 downto 1) = ADDRDEF then
                                -- address matches ours, acknowledge
                                state <= SSEND_ACK1;
                            else
                                -- address doesn't match ours, ignore
                                state <= SIDLE;
                            end if;
                        end if;
                    end if;
                when SSEND_ACK1 =>
                    if scl_vec = "10" then
                        state <= SSEND_ACK2;
                        sda <= '0';
                    end if;
                when SSEND_ACK2 =>
                    if scl_vec = "10" then
                        -- check if master requested read or write
                        if rwbit = '1' then
                            -- master wants to read
                            -- write first bit on bus
                            sda <= tx_data(7);
                            data <= tx_data;
                            -- start from one because we already wrote first bit
                            cnt_bit <= "001";
                            state <= SREAD;
                        else
                            -- master wants to write
                            -- release sda
                            sda <= 'Z';
                            cnt_bit <= (others => '0');
                            state <= SWRITE;
                        end if;
                    end if;
                when SRECV_ACK =>
                    if scl_vec = "01" then
                        if sda_vec(0) /= '0' then
                            -- received nack: master will send stop cond, but we
                            -- can simply jump right to idle state
                            state <= SIDLE;
                        end if;
                    elsif scl_vec = "10" then
                        -- continue read
                        sda <= tx_data(7); -- write first bit on bus
                        data <= tx_data;
                        -- start from 1 because we alreay transmit first bit
                        cnt_bit <= "001";
                        state <= SREAD;
                    end if;
                when SREAD =>
                    if scl_vec = "10" then
                        sda <= data(7-to_integer(cnt_bit));
                        cnt_bit <= cnt_bit + 1;

                        -- if cnt_bit overflowed we finished transmitting last bit
                        -- note: data is not allowed to contain any 1, only Z or 0
                        if cnt_bit = "000" then
                            -- release sda, because we need to listen for ack
                            -- from master
                            sda <= 'Z';
                            state <= SRECV_ACK;
                            -- notify that we have sent the byte
                            tx_sent <= '1';
                        end if;
                    end if;
                when SWRITE =>
                    if scl_vec = "01" then
                        data(7-to_integer(cnt_bit)) <= sda_vec(0);
                        cnt_bit <= cnt_bit + 1;

                        -- if cnt_bit is full we have just revceived the last bit
                        if cnt_bit = "111" then
                            state <= SSEND_ACK1;
                            -- apply received byte to out port
                            rx_data <= data(DATALEN-1 downto 1) & sda_vec(0);
                            -- notify that we have received a new byte
                            rx_recv <= '1';
                        end if;
                    end if;
            end case;

            -- check for stop / start condition
            if scl_vec = "11" and sda_vec = "01" then
                -- i2c stop condition
                state <= SIDLE;
                sda <= 'Z';
            elsif scl_vec = "11" and sda_vec = "10" then
                -- i2c start condition / repeated start condition
                state <= SADDR;
                cnt_bit <= (others => '0');
            end if;

        end if;
    end process;
end architecture;
