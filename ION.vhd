library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.arrays.ALL;
 
entity ION is
  port (
   --Input data and clock
	clk 				: in std_logic;
	digital_in		: in std_logic_vector(15 downto 0);	--reading digital inputs on chip
	slave_addr		: in std_logic_vector(6 downto 0); --dedicated signal from CU, data comes from 
	 
	--Control signals
	reset_n								: in std_logic; --all registers reset to 0 when this goes low
	GPIO_r_en, GPIO_wr_en 			: in std_logic; --enables read/write for GPIO 
	I2C_r_en, I2C_wr_en				: in std_logic; --used to initiate reads and writes of the I2C block only
	A_bus_out_sel, B_bus_out_sel	: in std_logic; --enables A or B bus onto output_buffer
	A_bus_in_sel, B_bus_in_sel		: in std_logic; --enables input_buffer on A or B bus
	 
   --Outputs
   digital_out			: out std_logic_vector(15 downto 0); --
	I2C_error			: out	std_logic;	--in case we can't write to slave after three attempts
	I2C_op_run			: out std_logic;	--when high, lets CU know that there is a CU operation occurring
	
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
		r_wr_complete			: out 	std_logic
	);
	end component I2C_block;

	--buffers for GPIOs
	signal input_buffer, output_buffer		: std_logic_vector(15 downto 0);

	--I2C block-specific signals
	signal scl_reg, sda_reg						: std_logic;
	signal data_to_slave, data_from_slave	: std_logic_vector(7 downto 0); 
	signal slave_address 						: std_logic_vector(6 downto 0);
	signal r_wr_comp								: std_logic;
	signal read_begin, write_begin			: std_logic;
	signal slave_ack_success					: std_logic_vector(1 downto 0);
	signal I2C_out_buffer, I2C_in_buffer	: std_logic_vector(15 downto 0);

	type I2C_op	is (idle, begin_write, begin_read, wait_op, unknown);
	signal I2C_op_state	: I2C_op := idle;

--	--procedure to write to A and B bus, solely based on instructions in instruction buffer
--	procedure write_data(	data	: in std_logic_vector(15 downto 0);	
--									
--									A_bus	: out std_logic_vector(15 downto 0);
--									B_bus	: out std_logic_vector(15 downto 0) 	) 
--	begin
--		
--	end procedure;

begin
		
	I2C_master : I2C_block
	port map(
		scl 					=> scl_reg, --this is a top level pin that will physically be on the chip
		sda 					=> sda_reg, --this is a top level pin that will physically be on the chip
		sys_clock 			=> clk, 
		reset_n 				=> reset_n, --places I2C block in idle state
		write_begin			=> write_begin,
		read_begin			=> read_begin,
		slave_address		=> slave_address(6 downto 0),	--if read/write_begin = '1', also send this address to choose the slave
		data_to_slave   	=> data_to_slave(7 downto 0), --if read/write_begin = '1', also send this data to the slave, as applicable
		read_error       	=> I2C_error,
		data_from_slave	=> data_from_slave(7 downto 0),
		r_wr_complete		=> r_wr_comp
	);
	
	process(reset_n, clk, A_bus_out_sel, B_bus_out_sel, GPIO_r_en, GPIO_wr_en, I2C_r_en, I2C_wr_en)
	begin
		if reset_n = '0' then
		
		elsif clk'event and clk = '1' then
		
			--prioritize GPIO reads first onto A/B bus, then I2C reads
			if A_bus_out_sel = '1' and GPIO_r_en = '1' then
				--TODO: should I directly pass through data from GPIOs instead of buffering first?
				A_bus <= input_buffer;
				
			elsif B_bus_out_sel = '1' and GPIO_r_en = '1' then
				--TODO: should I directly pass through data from GPIOs instead of buffering first?
				B_bus <= input_buffer;
				
			elsif I2C_r_en = '1' and A_bus_out_sel = '1' then
				A_bus <= I2C_in_buffer;
				
			elsif I2C_r_en = '1' and B_bus_out_sel = '1' then
				B_bus <= I2C_in_buffer;
			
			else
				A_bus <= "ZZZZZZZZZZZZZZZZ";
				B_bus <= "ZZZZZZZZZZZZZZZZ";
			
			end if; --A_bus_in_sel
		end if; --reset_n
	end process;
	
	--buffer inputs and outputs of high level chip
	process(reset_n, clk)
	begin
		if reset_n = '0' then
			input_buffer 	<= "0000000000000000";
			
		elsif clk'event and clk = '1' then
			--constantly buffer inputs and buffer outputs every clock cycle
			digital_out <= output_buffer;
			input_buffer <= digital_in; 
			
		end if; --reset_n
	end process;
	
	--read data in from A and B bus as applicable
	process(reset_n, clk, GPIO_wr_en, A_bus_out_sel, B_bus_out_sel, A_bus_in_sel, B_bus_in_sel)
	begin
		if reset_n = '0' then

		elsif clk'event and clk = '1' then
			if (A_bus_out_sel = '1' and GPIO_wr_en = '1') then
				output_buffer <= A_bus;
			
			elsif (B_bus_out_sel = '1' and GPIO_wr_en = '1') then
				output_buffer <= B_bus;
				
			else
				output_buffer <= output_buffer;
				
			end if; --bus select
		end if; -- clock
	end process;
	
	--write data to I2C module
	process (reset_n, clk, I2C_wr_en, I2C_r_en, A_bus_in_sel, B_bus_in_sel)
	begin
		
		if reset_n = '0' then
		
			write_begin <= '0';
			read_begin 	<= '0';
			I2C_out_buffer <= (others => '0');

		elsif clk'event and clk = '1' then
		
			case I2C_op_state is
			
				when idle => 
					write_begin <= '0';
					I2C_op_run <= '0';
					I2C_in_buffer <= "00000000" & data_from_slave;
					I2C_op_run <= '0';
					
					if I2C_wr_en = '1' then
						I2C_op_state <= begin_write;
						
					elsif I2C_r_en = '1' then
						I2C_op_state <= begin_read;

					else
						I2C_op_state <= idle;
						
					end if;
					
					
				when begin_read =>
					--1) read slave address
					slave_address <= slave_addr;

					--2) initiate write
					read_begin <= '1';
					
					--3) send status to CU
					I2C_op_run <= '1';
					
					--4) wait for operation to complete
					I2C_op_state <= wait_op;
					
				when begin_write => 
				
					--1) read slave address
					slave_address <= slave_addr;

					--2) read data from either A or B bus, as applicable
					if A_bus_in_sel = '1' then
						I2C_out_buffer <= A_bus;
					
					elsif B_bus_in_sel = '1' then
						I2C_out_buffer <= B_bus;
						
					end if;
					
					--3) initiate write
					write_begin <= '1';
					
					--4) send status to CU
					I2C_op_run <= '1';
					
					--5) wait for operation to complete
					I2C_op_state <= wait_op;
					
				when wait_op =>
					if r_wr_comp = '1' then
					
						if I2C_r_en = '1' then
							--report results
							I2C_in_buffer <= "00000000" & data_from_slave;
						end if;
						
						--restore system
						read_begin <= '0';
						write_begin <= '0';
						I2C_op_run <= '0';
						
						--go back to idle
						I2C_op_state <= idle;
						
					else
						I2C_op_state <= wait_op;
						
					end if;
				
				when unknown =>
					report "Ended up in impossible state.";
					I2C_op_state <= idle;
					
			end case;
		end if; -- reset_n
	end process; --I2C
	
	--latch output buffer into I2C block
	data_to_slave <= I2C_out_buffer(7 downto 0);
	
	I2C_sda <= sda_reg;
	I2C_scl <= scl_reg;
	
end behavioral;