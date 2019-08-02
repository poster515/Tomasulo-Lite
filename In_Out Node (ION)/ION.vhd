library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ION is
  port (
   --Input data and clock
	clk 				: in std_logic;
	digital_in		: in std_logic_vector(15 downto 0);	--reading digital inputs on chip
	ION_data_in		: in std_logic_vector(15 downto 0);	--data from MEM block
	slave_addr		: in std_logic_vector(6 downto 0); --dedicated signal from CU, data comes from R2 field of IW, only 31 slave addresses available
	 
	--Control signals
	reset_n								: in std_logic; --all registers reset to 0 when this goes low
	GPIO_in_en, GPIO_wr_en 			: in std_logic; --enables read/write for GPIO (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
	I2C_r_en, I2C_wr_en				: in std_logic; --initiates reads/writes for I2C (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)

   --Outputs
   digital_out			: out std_logic_vector(15 downto 0); --
	I2C_error			: out	std_logic;	--in case we can't write to slave after three attempts
	I2C_op_run			: out std_logic;	--when high, lets CU know that there is a CU operation occurring
	GPIO_out, I2C_out	: out std_logic_vector(15 downto 0); --GPIO and I2C module outputs
	I2C_complete		: out std_logic;
	
	--Input/Outputs
	I2C_sda, I2C_scl	: inout std_logic --high level chip inputs/outputs
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
	signal GPIO_out_reg, I2C_out_reg, output_buffer		: std_logic_vector(15 downto 0);

	--I2C block-specific signals
	signal scl_reg, sda_reg						: std_logic;
	signal data_from_slave						: std_logic_vector(7 downto 0); 
	signal slave_address 						: std_logic_vector(6 downto 0);
	signal r_wr_comp, I2C_op_complete		: std_logic;
	signal read_begin, write_begin			: std_logic;
	signal I2C_error_reg							: std_logic := '0';
	signal slave_ack_success					: std_logic_vector(1 downto 0);
	signal I2C_out_buffer, I2C_in_buffer	: std_logic_vector(15 downto 0);

	type I2C_op	is (idle, begin_write, begin_read, wait_op, unknown);
	signal I2C_op_state	: I2C_op := idle;

begin
		
	I2C_master : I2C_block
	port map(
		scl 					=> I2C_scl, --this is a top level pin that will physically be on the chip
		sda 					=> I2C_sda, --this is a top level pin that will physically be on the chip
		sys_clock 			=> clk, 
		reset_n 				=> reset_n, --places I2C block in idle state
		write_begin			=> write_begin,
		read_begin			=> read_begin,
		slave_address		=> slave_address(6 downto 0),	--if read/write_begin = '1', also send this address to choose the slave
		data_to_slave   	=> I2C_out_buffer(7 downto 0), --if read/write_begin = '1', also send this data to the slave, as applicable
		read_error       	=> I2C_error_reg,
		data_from_slave	=> data_from_slave(7 downto 0),
		r_wr_complete		=> r_wr_comp --only high for a single clock cycle
	);
	
	--send this single clock cycle signal to CU asynchronously
	I2C_complete <= r_wr_comp;
	
	process(reset_n, clk, GPIO_in_en, GPIO_wr_en, I2C_r_en, I2C_wr_en)
	begin
		if reset_n = '0' then
			GPIO_out_reg 	<= "0000000000000000";
			output_buffer	<= "0000000000000000";
			
		elsif rising_edge(clk) then
		
			--prioritize GPIO reads first, then I2C reads
			if GPIO_in_en = '1' then
				GPIO_out_reg <= digital_in;
				
			--now for I2C reads
			elsif I2C_r_en = '1' then
				--if we're done this clock cycle, just pull data from I2C slave directly
				if r_wr_comp = '1' then
					I2C_out_reg <= "00000000" & data_from_slave;
					
				--otherwise, if we know the result was buffered previously, just grab it
				elsif I2C_op_complete = '1' then
					I2C_out_reg <= I2C_in_buffer;
					
				end if; --r_wr_comp

			end if; --GPIO_in_en
			
			if GPIO_wr_en = '1' then
				output_buffer <= ION_data_in;

			else
				output_buffer <= output_buffer;
				
			end if; --bus select
			
		end if; --reset_n
	end process;
	
	digital_out <= output_buffer;
	
	--write data to I2C module
	process (reset_n, clk, I2C_wr_en, I2C_r_en)
	begin
		
		if reset_n = '0' then
		
			write_begin <= '0';
			read_begin 	<= '0';
			I2C_error 	<= '0';
			I2C_op_run 	<= '0';
			--I2C_out_buffer <= (others => '0');

		elsif rising_edge(clk) then
			
			--this register is for top level (i.e., ION) awareness
			I2C_op_complete <= r_wr_comp;
			I2C_error <= I2C_error_reg;
			
			case I2C_op_state is
			
				when idle => 
					write_begin <= '0';
					I2C_op_run <= '0';
					I2C_in_buffer <= "00000000" & data_from_slave;
					
					if I2C_wr_en = '1' then
						I2C_op_state <= begin_write;
						
						-- read data from ION_data_in to send to slave
						I2C_out_buffer <= ION_data_in;

						
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

					--2) initiate write
					write_begin <= '1';
					
					--3) send status to CU
					I2C_op_run <= '1';
					
					--4) wait for operation to complete
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
--						
--					elsif I2C_error_reg = '1' then
--						--restore system
--						read_begin <= '0';
--						I2C_op_run <= '0';
--						
--						--go back to idle
--						I2C_op_state <= idle;
					else
						I2C_op_state <= wait_op;
						
					end if;
				
				when unknown =>
					report "Ended up in impossible state.";
					I2C_op_state <= idle;
					
			end case;
		end if; -- reset_n
	end process; --I2C
	
	GPIO_out		<= GPIO_out_reg;
	I2C_out		<= I2C_out_reg;
--	I2C_sda <= sda_reg;
--	I2C_scl <= scl_reg;
	
end behavioral;