--Written by: Joe Post

--This file receives data and memory addresses from the EX stage and executes data memory operations via control instructions to MEM_top and ION.
--This file will not contain the DM however. 


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity MEM is
   port ( 
		--Input data and clock
		reset_n, sys_clock	: in std_logic;	
		IW_in						: in std_logic_vector(15 downto 0);
		LAB_stall_in			: in std_logic;
		WB_stall_in				: in std_logic;		--set high when an upstream CU block needs this 
		I2C_error				: in std_logic;	--in case we can't write to slave after three attempts
		I2C_op_run				: in std_logic;	--when high, lets CU know that there is a CU operation occurring
		
		--MEM Control Outputs
		MEM_in_sel		: out std_logic; --selects bus for MEM_top to select data from 
		MEM_out_en		: out std_logic; --enables MEM output on busses, goes to CSAM for arbitration
		MEM_wr_en		: out std_logic; --write enable for data memory
		MEM_op			: out std_logic;

		--ION Control Outputs
		GPIO_r_en, GPIO_wr_en 	: out std_logic; --enables read/write for GPIO (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
		I2C_r_en, I2C_wr_en		: out std_logic; --initiates reads/writes for I2C (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
		ION_out_en					: out std_logic; --enables input_buffer onto either A or B bus for GPIO reads, goes to CSAM for arbitration
		ION_in_sel					: out std_logic; --enables A or B bus onto output_buffer for digital writes, goes to CSAM for arbitration
		slave_addr					: out std_logic_vector(6 downto 0);
		
		--Outputs
		I2C_error_out	: out std_logic;	--in case we can't write to slave after three attempts, send to LAB for arbitration
		IW_out			: out std_logic_vector(15 downto 0);
		stall_out		: out std_logic
		--reset_out		: out std_logic
	);
end MEM;

architecture behavioral of MEM is
	signal reset_reg								: std_logic := '0';
	signal stall_in								: std_logic := '0';
	signal I2C_stall, I2C_GPIO_arb_stall	: std_logic;
	signal I2C_out_en, GPIO_out_en			: std_logic; --output enables from the I2C read and GPIO read processes respectively
	signal ION_results_ready_reg				: std_logic := '0'; --register tracking whether ION results are ready, make asynchronous

	type I2C_state is (idle, running, unknown);
	signal I2C_machine : I2C_state := idle;
	
begin
	--combinational logic to compute stall signals
	stall_in 	<= LAB_stall_in or WB_stall_in;
	stall_out 	<= I2C_stall or I2C_GPIO_arb_stall or stall_in;
	
	--combinational logic to de-conflict ION output writes. should prioritize I2C reads since they take the longest	
	ION_out_en 				<= I2C_out_en or GPIO_out_en;
	I2C_GPIO_arb_stall 	<= I2C_out_en and GPIO_out_en;

	--process to just handle I2C operations
	I2C_operation : process(reset_n, sys_clock, IW_in, I2C_op_run) 
	begin
	
		if reset_n = '0' then
			--reset_reg 		<= '0';
			I2C_r_en 		<= '0'; 	-- IW_in(1 downto 0) = "10"
			I2C_wr_en 		<= '0'; 	-- IW_in(1 downto 0) = "11"
			I2C_machine 	<= idle;
			I2C_stall 		<= '0';
			I2C_out_en  	<= '0';
			I2C_error_out 	<= '0';
			slave_addr		<= "0000000";
		
		elsif rising_edge(sys_clock) then
			
			--reset_reg <= '1';
		
			case I2C_machine is
				
				when idle => 
				
					I2C_stall 		<= '0';
					I2C_out_en  	<= '0';
					I2C_error_out 	<= '0';
				
					if IW_in(15 downto 12) = "1011" and IW_in(1) = '1' then
					
						slave_addr		<= "00" & IW_in(6 downto 2);
						I2C_r_en 		<= IW_in(1) and not(IW_in(0)); 		-- IW_in(1 downto 0) = "10"
						I2C_wr_en 		<= IW_in(1) and IW_in(0); 				-- IW_in(1 downto 0) = "11"
						I2C_machine 	<= running;
					end if;
				
				when running => 
				
					if IW_in(15 downto 12) = "1011" and IW_in(1) = '1' then
						--have a conflict here, since the I2C interface is already begin used.
						--can either buffer instruction or stall pipeline. former is more preferable, but stall for now. 
						I2C_stall <= '1';
						
					end if;
					
					if I2C_op_run = '1' then
						I2C_machine 	<= running;
						
					elsif I2C_error = '1' then
						I2C_error_out <= '1';
						
					elsif I2C_op_run = '0' then --I2C operation is complete, write results onto bus
					
						if IW_in(1 downto 0) = "10" then --I2C read operation
							I2C_out_en  	<= '1';
						end if; 
						
						I2C_machine 	<= idle;
						I2C_stall 		<= '0'; --since I2C operation is complete, can execute next command and there is no more stall
						
						if I2C_stall = '1' then --if there was a waiting I2C instruction, modify outputs here
							
							if IW_in(15 downto 12) = "1011" and IW_in(1) = '1' then
					
								slave_addr		<= "00" & IW_in(6 downto 2);
								I2C_r_en 		<= IW_in(1) and not(IW_in(0)); 		-- IW_in(1 downto 0) = "10"
								I2C_wr_en 		<= IW_in(1) and IW_in(0); 				-- IW_in(1 downto 0) = "11"
								I2C_machine 	<= running;
							end if;
							
						end if; --I2C_stall = '1'
						
					end if;

				when unknown => 
				
					report "Ended up in impossible state.";
					I2C_machine <= idle;
				
			end case;
			
		end if; --reset_n
		
	end process;
				
	--process to handle just GPIO and data memory operations
	GPIO_operation : process(reset_n, sys_clock)
	begin
		if reset_n = '0' then
			
			IW_out <= "0000000000000000";
		
			GPIO_r_en 	<= '0'; 	-- IW_in(1 downto 0) = "00"
			GPIO_out_en	<= '0'; 	-- IW_in(1 downto 0) = "00", signal goes to out_en_arbitration process for arbitration
			
			GPIO_wr_en 	<= '0'; 	-- IW_in(1 downto 0) = "01"
			ION_in_sel	<= '0'; 	-- IW_in(1 downto 0) = "01", signal goes to CSAM for arbitration
			
			MEM_op 		<= '0';	--else its not a memory operation
			MEM_in_sel	<= '0';	--IW_in(1) = '1' is for stores
			MEM_out_en	<= '0';	--IW_in(1) = '0' is for loads
			MEM_wr_en	<= '0';	--IW_in(1) = '1' is for stores

		elsif rising_edge(sys_clock) then
			
			if stall_in = '0' then
			
				IW_out <= IW_in;	--forward IW to WB stage
				
				--for GPIO operations (1011) 
				if IW_in(15 downto 12) = "1011" then 
					
					GPIO_r_en 	<= not(IW_in(1)) and not(IW_in(0)); -- IW_in(1 downto 0) = "00"
					GPIO_out_en	<= not(IW_in(1)) and not(IW_in(0)); -- IW_in(1 downto 0) = "00", goes to out_en_arbitration process for arbitration
					
					GPIO_wr_en 	<= not(IW_in(1)) and IW_in(0); 		-- IW_in(1 downto 0) = "01"
					ION_in_sel	<= not(IW_in(1)) and IW_in(0); 		-- IW_in(1 downto 0) = "01", signal goes to CSAM for arbitration
					
					MEM_op 		<= '0';	--
					MEM_in_sel	<= '0';	--
					MEM_out_en	<= '0';	--
					MEM_wr_en	<= '0';	--
					
				--for Data Memory operations (1000)
				elsif IW_in(15 downto 12) = "1000" then
				
					MEM_op 		<= '1';
					MEM_in_sel	<= IW_in(1);		--IW_in(1) = '1' is for stores
					MEM_out_en	<= not(IW_in(1));	--IW_in(1) = '0' is for loads
					MEM_wr_en	<= IW_in(1);		--IW_in(1) = '1' is for stores 
				
				--for all other instructions
				else
				
					GPIO_r_en 	<= '0'; -- IW_in(1 downto 0) = "00"
					GPIO_out_en	<= '0'; -- IW_in(1 downto 0) = "00", goes to out_en_arbitration process for arbitration
					GPIO_wr_en 	<= '0'; -- IW_in(1 downto 0) = "01"
					ION_in_sel	<= '0';
				
					MEM_op 		<= '0';	--else its not a memory operation
					MEM_in_sel	<= '0';	--IW_in(1) = '1' is for stores
					MEM_out_en	<= '0';	--IW_in(1) = '0' is for loads
					MEM_wr_en	<= '0';	--IW_in(1) = '1' is for stores
					
				end if;

			else
				
			end if; --stall_in

		end if; --reset_n
	end process;
	
	--latch inputs
	
	--latch outputs
	--reset_out <= reset_reg;
	
end behavioral;