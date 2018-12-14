library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity ION is
  port (
   --Input data and clock
	clk 				: in std_logic;
	digital_in		: in std_logic_vector(15 downto 0);	--reading digital inputs on chip
	slave_address	: in std_logic_vector(6 downto 0); --dedicated signal from CU, data comes from 
	 
	--Control signals
	reset_n								: in std_logic; --all registers reset to 0 when this goes low
	GPIO_r_en, GPIO_wr_en 			: in std_logic; --enables read/write for GPIO 
	read_en, write_en					: in std_logic; --used to initiate reads and writes of the I2C block only
	A_bus_out_sel, B_bus_out_sel	: in std_logic; --enables A or B bus onto output_buffer
	A_bus_in_sel, B_bus_in_sel		: in std_logic; --enables input_buffer on A or B bus
	 
   --Outputs
   digital_out			: out std_logic_vector(15 downto 0); --
	I2C_error			: out	std_logic;	--in case we can't write to slave after three attempts
	
	--Input/Outputs
	I2C_sda, I2C_scl	: inout std_logic; --high level chip inputs/outputs
	A_bus, B_bus		: inout std_logic_vector(15 downto 0)
   );
end ION;
 
architecture behavioral of ION is

	--import I2C block
	component I2C_block is
	port
	(
		scl, sda         		: inout 	std_logic; --these signals get debounced just in case
		sys_clock, reset_n  	: in    	std_logic;
		write_begin				: in 	  	std_logic;
		read_begin				: in 	  	std_logic;
		slave_address			: in 		std_logic_vector(6 downto 0);
		data_to_slave   		: in    	std_logic_vector(7 downto 0); --
		read_error       		: out  	std_logic := '0'; --set high if we can't read from slave after ack, after slave_read_retry_max retries
		data_from_slave 		: out   	std_logic_vector(7 downto 0);
		slave_ack_success		: out 	std_logic_vector(1 downto 0)	:= "01" --00 = no ack success, 10 = successful ack, 01/10 = no result yet
	);
	end component I2C_block;

--buffers for GPIOs
signal input_buffer, output_buffer		: std_logic_vector(15 downto 0);

--I2C block-specific signals
signal scl_reg, sda_reg											: std_logic;
signal data_to_slave, data_from_slave, slave_address 	: std_logic_vector(15 downto 0);
signal read_error, slave_addr_OK								: std_logic;
signal slave_ack_success, read_begin, write_begin		: std_logic;

begin
		
	I2C_master : I2C_block
	port map(
		scl 					=> scl, --this is a top level pin that will physically be on the chip
		sda 					=> sda, --this is a top level pin that will physically be on the chip
		sys_clock 			=> clk, 
		reset_n 				=> reset_n, --places I2C block in idle state
		write_begin			=> write_begin
		read_begin			=> read_begin
		slave_address		=> slave_address	--if read/write_begin = '1', also send this address to choose the slave
		data_to_slave   	=> data_to_slave, --if read/write_begin = '1', also send this data to the slave, as applicable
		read_error       	=> read_error,
		data_from_slave	=> data_from_slave,
		slave_ack_success	=> slave_ack_success
	);
	
	--buffer inputs and outputs of high level chip
	process(reset_n, clk)
	begin
		if reset_n = '0' then
			input_buffer 	<= "0000000000000000";
			
		elsif clk'event and clk = '1' then
			digital_out <= output_buffer;
			input_buffer <= digital_in; -- read inputs every clock cycle
			
		end if; --reset_n
	end process;
	
	--write results to A and B bus as applicable
	process(reset_n, clk, GPIO_wr_en, A_bus_out_sel, B_bus_out_sel, A_bus_in_sel, B_bus_in_sel)
	begin
		if reset_n = '0' then

		elsif clk'event and clk = '1' then
			if (A_bus_out_sel = '1' and GPIO_wr_en = '1') then
				output_buffer <= A_bus;
			
			elsif (B_bus_out_sel = '1' and GPIO_wr_en = '1') then
				output_buffer <= B_bus;
				
			elsif (A_bus_in_sel = '1') then
				A_bus <= input_buffer;
				
			elsif (B_bus_in_sel = '1') then
				B_bus <= input_buffer;
			
			else
				A_bus <= "ZZZZZZZZZZZZZZZZ";
				B_bus <= "ZZZZZZZZZZZZZZZZ";
			end if; --bus select
		end if; -- clock
	end process;
	
	--write data to I2C module
	process (I2C_scl, I2C_sda)
	begin
		--1) read slave address from either A or B bus
		--2) read data from either A or B bus, as applicable
		--3) initiate either read or write, as applicable
		--4) send status (write) or data and status (read) to CU
	end process; --I2C
end behavioral;