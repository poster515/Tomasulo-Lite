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
		slave_reg_en		  : in std_logic; --0 = just write/read data to slave, 1 = expect register internal register also
		write_begin			  : in 	  	std_logic;
		read_begin			   : in 	  	std_logic;
		slave_address		 : in 		std_logic_vector(6 downto 0);
		data_to_slave   : in    	std_logic_vector(7 downto 0); --
		data_from_slave : out   	std_logic_vector(15 downto 0)
	);
end component;

--time delta for waiting between test inputs
constant TIME_DELTA : time := 10 ns;

-- test signals here, map identically to EUT
signal scl,sda, sys_clock, reset_n : std_logic; --these signals get debounced just in case

-- User interface
signal slave_reg_en, write_begin, read_begin  : std_logic; --0 = just write/read data to slave, 1 = expect register internal register also

signal slave_address		  : std_logic_vector(6 downto 0);
signal data_to_slave   	: std_logic_vector(7 downto 0); --
signal data_from_slave 	: std_logic_vector(15 downto 0);

  begin
    
    dut : entity work.I2C_block
      port map(
        scl       => scl,
        sda       => sda, --these signals get debounced just in case
		    sys_clock => sys_clock, 
		    reset_n   => reset_n,

		    slave_reg_en		  => slave_reg_en, --0 = just write/read data to slave, 1 = expect register internal register also
		    write_begin			  => write_begin,
		    read_begin			   => read_begin,
		    slave_address	  => slave_address,
		    data_to_slave   => data_to_slave, --
		    data_from_slave => data_from_slave
      );
      
    sys_clock <=  '1' after TIME_DELTA / 2 when sys_clock = '0' else
                  '0' after TIME_DELTA / 2 when sys_clock = '1'; 
        
    simulation : process
    begin
      --initialize all registers, and wait a few clocks
      reset_n <= '0';
      write_begin <= '0';
      read_begin <= '0';
      wait for TIME_DELTA * 2;
      
      reset_n <= '1';
      
      -- Write to I2C 
      slave_address <= "1010101";
      data_to_slave <= "11110000";
      write_begin   <= '1';
      --NEED TO DETERMINE HOW TO ACK THIS MESSAGE
      wait for TIME_DELTA;
      
      
    end process simulation;

end architecture test;




