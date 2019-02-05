library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--
entity I2C_block_tb is
end I2C_block_tb;

architecture test of I2C_block_tb is
--
component I2C_block is
	generic ( clk_div : integer := 64 ); --this will be clock divider factor i.e., [sys_clock / clk_div]
	port (
		scl, sda         		 : inout 	std_logic; --these signals get debounced just in case
		sys_clock, reset_n  : in    	std_logic;
		write_begin			      : in 	  	std_logic;
		read_begin			       : in 	  	std_logic;
		slave_address		     : in 		  std_logic_vector(6 downto 0);
		data_to_slave       : in    	std_logic_vector(7 downto 0); --
		read_error       		 : out  	 std_logic; --set high if we can't read from slave after ack, after slave_read_retry_max retries
		data_from_slave     : out   	std_logic_vector(7 downto 0);
		slave_ack_success		 : out 	  std_logic_vector(1 downto 0)	:= "01"

	);
end component;

--time delta for waiting between test inputs
constant TIME_DELTA : time := 10 ns;

-- test signals here, map identically to EUT
signal scl,sda : std_logic := 'Z';
signal sys_clock, reset_n : std_logic := '0'; --these signals get debounced just in case

-- User interface
signal write_begin, read_begin, read_error  : std_logic; --0 = just write/read data to slave, 1 = expect register internal register also

signal slave_address		  : std_logic_vector(6 downto 0);
signal data_to_slave   	: std_logic_vector(7 downto 0); --
signal data_from_slave 	: std_logic_vector(7 downto 0);
signal slave_ack_success  : std_logic_vector(1 downto 0) := "01";

  begin
    
    dut : entity work.I2C_block
      port map(
        scl       => scl,
        sda       => sda, --these signals get debounced just in case
		    sys_clock => sys_clock, 
		    reset_n   => reset_n,

		    write_begin			  => write_begin,
		    read_begin			   => read_begin,
		    slave_address	  => slave_address,
		    data_to_slave   => data_to_slave, --
		    read_error      => read_error, --set high if we can't read from slave after ack, after slave_read_retry_max retries
		    data_from_slave => data_from_slave,
		    slave_ack_success		 => slave_ack_success
      );
      
    sys_clock <=  '1' after TIME_DELTA / 2 when sys_clock = '0' else
                  '0' after TIME_DELTA / 2 when sys_clock = '1'; 

    --NOTE: clk_div is 12 for this simulation
    simulation : process
    begin
      --sys_clock <=  '1' after TIME_DELTA / 2 when sys_clock = '0' else
      --            '0' after TIME_DELTA / 2 when sys_clock = '1';
      
      --initialize all registers, and wait a few clock
      write_begin <= '0';
      read_begin <= '0';
      wait for TIME_DELTA * 2;
      
      ---------------------------------------------------------------------------
      --I2C MASTER WRITE CODE--
      --Write to I2C 
      slave_address <= "1010101";
      reset_n <= '1';
      data_to_slave <= "11110000";
      write_begin   <= '1';
      wait for TIME_DELTA;
      
      --ACK slave address
      wait for (2135 ns - (TIME_DELTA * 3));
      sda <= '0';
      wait for (TIME_DELTA * 12); --2255 ns
      sda <= 'Z'; 
      
      --ACK receipt of data from master
      wait for 2220 ns; --4475 ns - 2255 ns = 2220 ns
      sda <= '0';
      wait for (TIME_DELTA * 12); --4595 ns 
      sda <= 'Z';
      write_begin <= '0';
      wait for 400 ns; --just wait for long time, so simulation doesn't repeat
      
      -- --END I2C MASTER WRITE CODE--
      ------------------------------------------------------------------------------
      
      --I2C MASTER READ CODE--
      -- Write to I2C 
      slave_address <= "1010101";
      reset_n <= '1';
      data_to_slave <= "11110000";
      read_begin   <= '1';
      wait for TIME_DELTA;
      
      -- --slave ACKs address
      wait for (2135 ns - (TIME_DELTA * 3));
      sda <= '0';
      wait for (TIME_DELTA * 12); --2255 ns
      sda <= 'Z'; 
      
      -- --Pseudo data from 'slave'
      wait for 170 ns; --2390 ns - 2255 ns = 170 ns, low phase of slave read cycle
      sda <= '0';
      wait for (TIME_DELTA * 26); --takes us to next low phase 
      sda <= '1';
      wait for (TIME_DELTA * 26); --
      sda <= '0';
      wait for (TIME_DELTA * 26); --takes us to next low phase 
      sda <= '1';
      wait for (TIME_DELTA * 26); --takes us to next low phase 
      sda <= '1';
      wait for (TIME_DELTA * 26); --
      sda <= 'X';
      wait for (TIME_DELTA * 26); --takes us to next low phase 
      sda <= '1';
      wait for (TIME_DELTA * 26); --takes us to next low phase 
      sda <= '1';
      
      --Slave Relinquishes SDA line
      wait for (TIME_DELTA * 12); --takes us to next low phase
      sda <= 'Z';
      
      --retransmit data
      wait for 450 ns; --(7 * 26 * 10)
      sda <= '0';
      wait for (TIME_DELTA * 26); --takes us to next low phase 
      sda <= '1';
      wait for (TIME_DELTA * 26); --
      sda <= '0';
      wait for (TIME_DELTA * 26); --takes us to next low phase 
      sda <= '1';
      wait for (TIME_DELTA * 26); --takes us to next low phase 
      sda <= '1';
      wait for (TIME_DELTA * 26); --
      sda <= '0';
      wait for (TIME_DELTA * 26); --takes us to next low phase 
      sda <= '1';
      wait for (TIME_DELTA * 26); --takes us to next low phase 
      sda <= '1';
      
      --Slave Relinquishes SDA line
      wait for (TIME_DELTA * 12); --takes us to next low phase
      sda <= 'Z';
      
      read_begin <= '0'; --allow to go into idle state
      wait for 1000 ns; --just wait for write_begin   <= '1';
      
      --END I2C MASTER READ CODE--
    end process simulation;

end architecture test;




