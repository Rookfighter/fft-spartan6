-- i2c_slave_tb.vhd
--
-- Created on: 08 Jun 2017
--     Author: Fabian Meyer

library ieee;
use ieee.std_logic_1164.all;

entity i2c_slave_write_tb is
end entity;

architecture behavior of i2c_slave_write_tb is

    -- Component Declaration for the Unit Under Test (UUT)
    component i2c_slave
    generic(RSTDEF:  std_logic := '0';
            ADDRDEF: std_logic_vector(6 downto 0) := "0100000");
    port(rst:     in    std_logic;                                       -- reset, RSTDEF active
         clk:     in    std_logic;                                       -- clock, rising edge
         swrst:   in    std_logic;                                       -- software reset, RSTDEF active
         en:      in    std_logic;                                       -- enable, high active
         tx_data: in    std_logic_vector(7 downto 0);                    -- tx, data to send
         tx_sent: out   std_logic := '0';                                -- tx was sent, high active
         rx_data: out   std_logic_vector(7 downto 0) := (others => '0'); -- rx, data received
         rx_recv: out   std_logic := '0';                                -- rx received, high active
         busy:    out   std_logic := '0';                                -- busy, high active
         sda:     inout std_logic := 'Z';                                -- serial data of I2C
         scl:     inout std_logic := 'Z');                               -- serial clock of I2C
    end component;

    constant RSTDEF: std_logic := '0';

    --Inputs
    signal rst:     std_logic := RSTDEF;
    signal clk:     std_logic := '0';
    signal swrst:   std_logic := RSTDEF;
    signal en:      std_logic := '0';
    signal tx_data: std_logic_vector(7 downto 0) := (others => '0');

    --BiDirs
    signal sda: std_logic := '1';
    signal scl: std_logic := '1';

    --Outputs
    signal tx_sent: std_logic;
    signal rx_data: std_logic_vector(7 downto 0);
    signal rx_recv: std_logic;
    signal busy:    std_logic;

    -- Clock period definitions
    constant clk_period: time := 10 ns;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: i2c_slave
        generic map(RSTDEF => '0',
                    ADDRDEF => "0010111") -- address 0x17
        port map(rst     => rst,
                 clk     => clk,
                 swrst   => swrst,
                 en      => en,
                 tx_data => tx_data,
                 tx_sent => tx_sent,
                 rx_data => rx_data,
                 rx_recv => rx_recv,
                 busy    => busy,
                 sda     => sda,
                 scl     => scl);

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

        -- sends a single bit over I2C
        procedure send_bit(tosend: std_logic) is
        begin
            scl <= '0';
            sda <= tosend;
            -- wait for delay element to take over new value
            wait for 25*clk_period;
            -- allow slave to read
            scl <= '1';
            wait for clk_period;
        end procedure;

        -- receive a single bit over I2C
        procedure recv_bit is
        begin
            scl <= '0';
            sda <= 'Z';
            wait for clk_period;
            scl <= '1';
            wait for clk_period;
        end procedure;

        -- sends start / repeated start condition over I2C
        procedure send_start is
        begin
            send_bit('1');
            -- rise sda without changing clk
            sda <= '0';
            wait for 25*clk_period;
        end procedure;

        -- sends stop condition over I2C
        procedure send_stop is
        begin
            send_bit('0');
            -- rise sda without changing clk
            sda <= '1';
            wait for 25*clk_period;
        end procedure;

        -- wait for an ack from slave over I2C
        procedure wait_ack is
        begin
            send_bit('Z');
            -- wait additional cycle for slave to release SDA again
            scl <= '0';
            wait for clk_period;
        end procedure;

        -- send ack to slave
        procedure send_ack is
        begin
            send_bit('0');
        end procedure;

        -- send nack to slave
        procedure send_nack is
        begin
            send_bit('1');
        end procedure;

    begin
        -- hold reset state for 100 ns.
        wait for clk_period*10;
        rst   <= not RSTDEF;
        swrst <= not RSTDEF;
        en    <= '1';

        -- init transmission
        send_start;

        -- send correct address
        send_bit('0'); -- address bit 1
        send_bit('0'); -- address bit 2
        send_bit('1'); -- address bit 3
        send_bit('0'); -- address bit 4
        send_bit('1'); -- address bit 5
        send_bit('1'); -- address bit 6
        send_bit('1'); -- address bit 7
        send_bit('0'); -- direction bit

        -- slave should send ack
        wait_ack;

        -- send data
        send_bit('1'); -- data bit 1
        send_bit('1'); -- data bit 2
        send_bit('0'); -- data bit 3
        send_bit('0'); -- data bit 4
        send_bit('1'); -- data bit 5
        send_bit('1'); -- data bit 6
        send_bit('0'); -- data bit 7
        send_bit('1'); -- data bit 8

        -- rx_data should be "11001101"
        -- rx_recv should '1' for one cylce
        -- slave should send ack
        wait_ack;

        -- send data
        send_bit('1'); -- data bit 1
        send_bit('0'); -- data bit 2
        send_bit('1'); -- data bit 3
        send_bit('0'); -- data bit 4
        send_bit('0'); -- data bit 5
        send_bit('1'); -- data bit 6
        send_bit('1'); -- data bit 7
        send_bit('0'); -- data bit 8

        -- rx_data should be "10100110"
        -- rx_recv should '1' for one cylce
        -- slave should send ack
        wait_ack;

        -- terminate transmission
        send_stop;

        -- init next transmission
        send_start;

        -- send wrong address 0x13
        send_bit('0'); -- address bit 1
        send_bit('0'); -- address bit 2
        send_bit('1'); -- address bit 3
        send_bit('0'); -- address bit 4
        send_bit('0'); -- address bit 5
        send_bit('1'); -- address bit 6
        send_bit('1'); -- address bit 7
        send_bit('0'); -- direction bit

        -- slave should send no ack and go back to idle mode
        wait_ack;

        -- send data
        -- slave should not record it
        send_bit('0'); -- data bit 1
        send_bit('0'); -- data bit 2
        send_bit('1'); -- data bit 3
        send_bit('0'); -- data bit 4
        send_bit('0'); -- data bit 5
        send_bit('1'); -- data bit 6
        send_bit('0'); -- data bit 7
        send_bit('1'); -- data bit 8

        -- slave should send no ack and go back to idle mode
        wait_ack;

        -- terminate transmission
        send_stop;

        wait for clk_period*10;

        wait;
    end process;

end;
