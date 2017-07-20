-- fft16.vhd
--
-- Created on: 20 Jul 2017
--     Author: Fabian Meyer
--
-- Integration component for 16-point FFT.

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
         lvl:     in  std_logic_vector(FFTEXP-1 downto 0);  -- iteration level of butterflies
         bfno:    in  std_logic_vector(FFTEXP-1 downto 0);  -- butterfly number in current level
         addra1:  out std_logic_vector(FFTEXP-1 downto 0);  -- address1 for membank A
         addra2:  out std_logic_vector(FFTEXP-1 downto 0);  -- address2 for membank A
         en_wrta: out std_logic;                            -- write enable for membank A, high active
         addrb1:  out std_logic_vector(FFTEXP-1 downto 0);  -- address1 for membank B
         addrb2:  out std_logic_vector(FFTEXP-1 downto 0);  -- address2 for membank B
         en_wrtb: out std_logic;                            -- write enable for membank B, high active
         addrtf:  out std_logic_vector(FFTEXP-1 downto 0)); -- twiddle factor address
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

    component delay_vec
    generic(RSTDEF:   std_logic := '0';
            DATALEN:  natural := 8
            DELAYLEN: natural := 8);
    port(rst:   in  std_logic;                              -- reset, RSTDEF active
         clk:   in  std_logic;                              -- clock, rising edge
         swrst: in  std_logic;                              -- software reset, RSTDEF active
         en:    in  std_logic;                              -- enable, high active
         din:   in  std_logic_vector(DATALEN-1 downto 0);   -- data in
         dout:  out std_logic_vector(DATALEN-1 downto 0));  -- data out
    end component;

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

    -- define this FFT as 16-point (exponent = 4)
    constant FFTEXP: natural := 4;
    -- delay write address by 3 cycles
    constant DELWADDR: natural := 3;
    constant DELENAGU: natural := 3;

    -- twiddle factors for 16-Point FFT
    signal w: complex_arr(0 to (2**(FFTEXP-1))-1) := (
        to_complex(1.0, 0.0),
        to_complex(0.9239, 0.3827),
        to_complex(0.7071, 0.7071),
        to_complex(0.3827, 0.9239),
        to_complex(0.0, 1.0),
        to_complex(-0.3827, 0.9239),
        to_complex(-0.7071, 0.7071),
        to_complex(-0.9239, 0.3827)
    );

    -- define states for FSM of FFT
    type TState is (SIDLE, SSET, SGET, SRUN, SENDLVL);
    signal state: TState := IDLE;

    signal addra1: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal addra2: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal addrb1: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal addrb1: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal en_wrta: std_logic := '0';
    signal en_wrtb: std_logic := '0';
    signal en_agu_tmp: std_logic := '0';
    signal swrst_agu_tmp: std_logic := not RSTDEF;

    -- address signals from agu to membank A
    signal addra1_agu: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal addra2_agu: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal en_wrta_agu: std_logic := '0';
    -- address signals from agu to membank B
    signal addrb1_agu: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal addrb2_agu: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal en_wrtb_agu: std_logic := '0';
    -- software reset signal for agu
    signal swrst_agu: std_logic := not RSTDEF;
    -- enable signal for agu
    signal en_agu: std_logic := '0';
    signal lvl_agu:  std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal bfno_agu: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');

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

    signal din_waddr1: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal din_waddr2: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal dout_waddr1: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');
    signal dout_waddr2: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');

    signal din_enagu:  std_logic := '0';
    signal dout_enagu: std_logic := '0';

    -- address signal for twiddle factor
    signal addrtf: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');

    signal addr_cnt: unsigned(FFTEXP-1 downto 0) := (others => '0');
    signal addr_rev: std_logic_vector(FFTEXP-1 downto 0) := (others => '0');

begin

    -- done is set if we are in IDLE state
    done <= '1' when state = SIDLE else '0';

    -- feed only signal of bank in "write" mode into delay element
    din_waddr1 <= addra1_agu when en_wrta_agu = '1' else addrb1_agu;
    din_waddr2 <= addra2_agu when en_wrta_agu = '1' else addrb2_agu;

    -- only use addresses of agu in running state
    addr1_mema <= addra1_agu  when state = SRUN and en_wrta_agu = '0' else -- when in read mode use undelayed
                  dout_waddr1 when state = SRUN and en_wrta_agu = '1' else -- when in write mode use delayed
                  addra1;
    addr2_mema <= addra2_agu  when state = SRUN and en_wrta_agu = '0' else -- when in read mode use undelayed
                  dout_waddr2 when state = SRUN and en_wrta_agu = '1' else -- when in write mode use delayed
                  addra2;
    addr1_memb <= addrb1_agu  when state = SRUN and en_wrtb_agu = '0' else -- when in read mode use undelayed
                  dout_waddr1 when state = SRUN and en_wrtb_agu = '1' else -- when in write mode use delayed
                  addrb1;
    addr2_memb <= addrb2_agu  when state = SRUN and en_wrtb_agu = '0' else -- when in read mode use undelayed
                  dout_waddr2 when state = SRUN and en_wrtb_agu = '1' else -- when in write mode use delayed
                  addrb2;

    -- only use write enable of agu in running state
    en_wrt_mema <= en_wrta_agu when state = SRUN else en_wrta;
    en_wrt_memb <= en_wrtb_agu when state = SRUN else en_wrtb;

    -- addra1 is only used in SSET state
    -- it can always stay bit reversed address
    addra1 <= addr_rev;
    -- addrb1 is only used in SGET state
    -- it can always stay on address counter value
    addrb1 <= addr_cnt;
    -- dout is always read vom dout1 of membank B
    dout <= dout1_memb;

    swrst_agu <= RSTDEF when swrst = RSTDEF else swrst_agu_tmp;
    en_agu    <= '0' when en = '0' else en_agu_tmp;

    -- calc bit reversed address
    gen_rev: for i in 0 to FFTEXP-1 generate
        addr_rev(i) <= std_logic(addr_cnt(FFTEXP-1 - i));
    end generate;

    process(clk, rst) is
        -- reset this component
        procedure reset is
        begin

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
                            addr_cnt <= (others => '0');
                            din1_mema <= din;
                            en_wrta <= '1';
                        elsif get = '1' then
                            -- "get" signal received
                            state <= SGET;

                            -- read values from membank B in normal order
                            addr_cnt <= (others => '0');
                            en_wrtb <= '0';
                        elsif start = '1' then
                            -- "start" signal received
                            state <= SRUN;

                            lvl_agu <= (others => '0');
                            bfno_agu <= (others => '0');
                        end if;
                    when SSET  =>
                        -- increment address count
                        -- bit reversed address will be updated automatically
                        addr_cnt <= addr_cnt + 1;
                        din1_mema <= din;

                        -- if counter is full go back to idle state
                        -- and reset all used resources
                        if addr_cnt = "1111" then
                            addra1 <= (others => '0');
                            din1_mema <= (others => '0');
                            en_wrta <= '0';
                            state <= SIDLE;
                        end if;
                    when SGET  =>
                        -- increment address count
                        -- this is the address that we read from
                        addr_cnt <= addr_cnt + 1;

                        -- if counter is full go back to idle state
                        -- and reset all used resources
                        if addr_cnt = "1111" then
                            addrb1 <= (others => '0');
                            state <= SIDLE;
                        end if;
                    when SRUN =>
                        -- increment butterfly every cycle
                        bfno_agu <= std_logic_vector(unsigned(bfno_agu) + 1);

                        -- if we have reached last butterfly wait for pipeline
                        -- to finish
                        if bfno_agu = "0111" then
                            en_agu <= '0';
                            din_enagu <= '1';
                            state <= SENDLVL;
                        end if;

                    when SENDLVL =>
                        din_enagu <= '0';

                        -- wait unit enable signal reaches us
                        if dout_enagu = '1' then
                            -- reset butterfly number
                            bfno_agu <= (others => '0');

                            if lvl_agu = "0100" then
                                -- final level was reached: we are done
                                -- reset level number
                                state <= SINIT;
                                lvl_agu <= (others => '0');
                            else
                                -- go to next level
                                -- enable agu again
                                lvl_agu <= std_logic_vector(unsigned(lvl_agu + 1));
                                en_agu <= '1';
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
                 swrst   => swrst_agu,
                 en      => en_agu,
                 lvl     => lvl_agu,
                 bfno    => bfno_agu,
                 addra1  => addra1_agu,
                 addra2  => addra2_agu,
                 en_wrta => en_wrta_agu,
                 addrb1  => addrb1_agu,
                 addrb2  => addrb2_agu,
                 en_wrtb => en_wrtb_agu,
                 addrtf  => addrtf);

    -- create instance of memory bank A
    mem_a: membank
        generic map(RSTDEF => RSTDEF,
                    FFTEXP => FFTEXP)
        port map(rst     => rst,
                 clk     => clk,
                 swrst   => swrst,
                 en      => en,
                 addr1   => addr1_mema,
                 addr2   => addr2_mema,
                 en_wrt  => en_wrt_mema,
                 din1    => din1_mema,
                 din2    => din2_mema,
                 dout1   => dout1_mema,
                 dout2   => dout2_mema);

    -- create instance of memory bank B
    mem_b: membank
        generic map(RSTDEF => RSTDEF,
                    FFTEXP => FFTEXP)
        port map(rst     => rst,
                 clk     => clk,
                 swrst   => swrst,
                 en      => en,
                 addr1   => addr1_memb,
                 addr2   => addr2_memb,
                 en_wrt  => en_wrt_memb,
                 din1    => din1_memb,
                 din2    => din2_memb,
                 dout1   => dout1_memb,
                 dout2   => dout2_memb);

    -- create instance of butterfly unit
    bfu: butterfly
        generic map(RSTDEF => RSTDEF)
        port(rst     => rst,
             clk     => clk,
             swrst   => swrst,
             en      => en,
             din1    => din1_bf,
             din2    => din2_bf,
             w       => ,
             dout1   => dout1_bf,
             dout2   => dout2_bf);

    -- create instance of delay unit for write address 1
    del_waddr1: delay_vec
        generic map(RSTDEF   => RSTDEF,
                    DATALEN  => FFTEXP,
                    DELAYLEN => DELWADDR)
        port(rst   => rst,
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
         port(rst   => rst,
              clk   => clk,
              swrst => swrst,
              en    => en,
              din   => din_waddr2,
              dout  => dout_waddr2);

    -- create instance of delay unit for enable signal of agu
    del_enagu: delay_bit
        generic map(RSTDEF   => RSTDEF,
                    DELAYLEN => DELENAGU)
        port(rst   => rst,
             clk   => clk,
             swrst => swrst,
             en    => en,
             din   => din_enagu,
             dout  => dout_enagu);
end;
