-- whole_design_tb.vhd
--
-- Created on: 17 Jul 2017
--     Author: Fabian Meyer

library ieee;
library work;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fft_helpers.all;

entity whole_design_tb is
end entity;

architecture behavioral of whole_design_tb is

    -- Component Declaration for the Unit Under Test (UUT)
    component whole_design
    generic(RSTDEF: std_logic := '0');
    port(rst:      in    std_logic;                     -- reset, RSTDEF active
         clk:      in    std_logic;                     -- clock, rising edge
         sda:      inout std_logic;                     -- serial data of I2C
         scl:      inout std_logic);                    -- serial clock of I2C
    end component;

    -- Clock period definitions
    constant clk_period: time := 10 ns;

    constant BYTES: natural := 3;
    constant SAMPLES: natural := 16;

    constant test_data: complex_arr(0 to 15) := (
        to_complex(0.0,0.0),
        to_complex(1.0,0.0),
        to_complex(2.0,0.0),
        to_complex(3.0,0.0),
        to_complex(4.0,0.0),
        to_complex(5.0,0.0),
        to_complex(6.0,0.0),
        to_complex(7.0,0.0),
        to_complex(8.0,0.0),
        to_complex(9.0,0.0),
        to_complex(10.0,0.0),
        to_complex(11.0,0.0),
        to_complex(12.0,0.0),
        to_complex(13.0,0.0),
        to_complex(14.0,0.0),
        to_complex(15.0,0.0)
    );

    -- Generics
    constant RSTDEF: std_logic := '0';

    -- Inputs
    signal rst:     std_logic := '0';
    signal clk:     std_logic := '0';

    --BiDirs
    signal sda: std_logic := '1';
    signal scl: std_logic := '1';

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: whole_design
        generic map(RSTDEF => RSTDEF)
        port map(rst => rst,
                 clk => clk,
                 sda => sda,
                 scl => scl);

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
            wait for 24*clk_period;
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

        procedure send_sample(data: signed(FIXLEN-1 downto 0)) is
            variable byte_start: natural := 0;
            variable byte_end: natural := 0;
        begin
            for i in 0 to BYTES-1 loop
                byte_start := FIXLEN - (i * 8) - 1;
                byte_end   := FIXLEN - (i * 8) - 8;

                for j in byte_start downto byte_end loop
                    send_bit(data(j));
                end loop;

                wait_ack;
            end loop;
        end;
    begin
        -- hold reset state for 100 ns.
        wait for clk_period*10;

        rst <= '1';

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
        send_bit('1'); -- direction bit

        -- send samples
        for i in 0 to 15 loop
            send_sample(test_data(i).r);
        end loop;

        -- terminate transmission
        send_stop;

        -- do FFT
        wait for 50*clk_period;

        -- receive results
        for i in 0 to 15 loop
            for j in 0 to BYTES-1 loop
                recv_bit; -- data bit 1
                recv_bit; -- data bit 2
                recv_bit; -- data bit 3
                recv_bit; -- data bit 4
                recv_bit; -- data bit 5
                recv_bit; -- data bit 6
                recv_bit; -- data bit 7
                recv_bit; -- data bit 8
                send_ack;
            end loop;
        end loop;

        wait;
    end process;

end;
