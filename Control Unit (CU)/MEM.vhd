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
		MEM_stall_in			: in std_logic;
		I2C_error				: in std_logic;	--in case we can't write to slave after three attempts
		I2C_op_run				: in std_logic;	--when high, lets CU know that there is a CU operation occurring
		
		--MEM Control Outputs
		MEM_out_mux_sel		: out std_logic_vector(1 downto 0); --enables MEM output 
		MEM_wr_en				: out std_logic; --write enable for data memory

		--ION Control Outputs
		GPIO_in_en, GPIO_wr_en 	: out std_logic; --enables read/write for GPIO (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
		I2C_r_en, I2C_wr_en		: out std_logic; --initiates reads/writes for I2C (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
		slave_addr					: out std_logic_vector(6 downto 0);
		
		--Outputs
		I2C_error_out	: out std_logic;	--in case we can't write to slave after three attempts, send to LAB for arbitration
		IW_out			: out std_logic_vector(15 downto 0);
		stall_out		: out std_logic;
		reset_out		: out std_logic
	);
end MEM;

architecture behavioral of MEM is
	signal reset_reg								: std_logic := '0';
	signal ION_results_ready_reg				: std_logic := '0'; --register tracking whether ION results are ready, make asynchronous
	signal I2C_IW_reg								: std_logic_vector(15 downto 0); --tracks the last incoming IW for an I2C command
	
	type I2C_state is (idle, running, unknown);
	signal I2C_machine : I2C_state := idle;
	
begin

	--process to just handle I2C operations
	I2C_operation : process(reset_n, sys_clock) 
	begin
		--this process can and should be independent of external stalls, because it takes so long
		if reset_n = '0' then
			reset_reg 		<= '0';
			I2C_r_en 		<= '0'; 	-- IW_in(1 downto 0) = "10"
			I2C_wr_en 		<= '0'; 	-- IW_in(1 downto 0) = "11"
			I2C_machine 	<= idle;
			I2C_error_out 	<= '0';
			slave_addr		<= "0000000";
			I2C_IW_reg <= "0000000000000000";
		
		elsif rising_edge(sys_clock) then
			
			reset_reg <= '1';
		
			case I2C_machine is
				
				when idle => 
				
					I2C_error_out 	<= '0';
				
					if IW_in(15 downto 12) = "1011" and IW_in(1) = '1' then
						I2C_IW_reg		<= IW_in;
						slave_addr		<= "00" & IW_in(6 downto 2);
						I2C_r_en 		<= IW_in(1) and not(IW_in(0)); 		-- IW_in(1 downto 0) = "10"
						I2C_wr_en 		<= IW_in(1) and IW_in(0); 				-- IW_in(1 downto 0) = "11"
						I2C_machine 	<= running;
						
					else
						I2C_r_en			<= '0';
						I2C_wr_en		<= '0';
					end if;
				
				when running => 
				
					if I2C_op_run = '1' then
						I2C_machine 	<= running;
						
					elsif I2C_error = '1' then
						I2C_error_out <= '1';
						I2C_machine 	<= idle;
						
					elsif I2C_op_run = '0' then --I2C operation is complete, write results onto bus
					
						I2C_machine 	<= idle;
						
					end if;

				when unknown => 
				
					report "Ended up in impossible state.";
					I2C_machine <= idle;
				
			end case;
			
		end if; --reset_n
		
	end process;
	
	reset_out <= reset_reg;
				
	--process to handle just GPIO and data memory operations
	GPIO_operation : process(reset_n, sys_clock)
	begin
		if reset_n = '0' then
			
			IW_out <= "0000000000000000";
			MEM_out_mux_sel <= "00"; --goes to MEM_top but oh well
			GPIO_in_en	<= '0'; 	--
			GPIO_wr_en 	<= '0'; 	--
			MEM_wr_en	<= '0';	--

		elsif rising_edge(sys_clock) then
			
			if MEM_stall_in = '0' then
				
				IW_out <= IW_in;	--forward IW to WB stage
				
				--loads (1000..0X), need to forward data from data memory
				if (IW_in(15) and not(IW_in(14)) and not(IW_in(13)) and not(IW_in(12)) and not(IW_in(1))) = '1' then
					MEM_wr_en	<= '0';	--don't want to enable writing to DM here
					MEM_out_mux_sel <= "01";
					
				--stores (1000..1X)
				elsif IW_in(15 downto 12) = "1000" and IW_in(1) = '1' then
					MEM_wr_en	<= '1';		--
					--MEM_out_mux_sel <= "00";
					MEM_out_mux_sel <= "11";
					
				--for all ALU (i.e., 0XXX) operations or LOGI (1100), need to forward ALU_out_1 data through MEM block to WB	
				elsif (IW_in(15) = '0') or (IW_in(15 downto 13) = "110") then
					MEM_wr_en	<= '0';	--don't want to enable writing to DM here
					MEM_out_mux_sel <= "10";
					
				--else just forward on '0' through MEM block (not sure this can ever happen)
				else	
					MEM_wr_en	<= '0';	--don't want to enable writing to DM here
					MEM_out_mux_sel <= "00";
					
				end if;
				
				--for GPIO operations (1011) 
				if IW_in(15 downto 12) = "1011" then 
					
					GPIO_in_en	<= not(IW_in(1)) and not(IW_in(0)); -- IW_in(1 downto 0) = "00", enables digital input data to be latched (read)
					GPIO_wr_en 	<= not(IW_in(1)) and IW_in(0); 		-- IW_in(1 downto 0) = "01", enables writing data to digital outputs (write)
					
				--for all other instructions
				else
					GPIO_in_en	<= '0'; -- IW_in(1 downto 0) = "00"
					GPIO_wr_en 	<= '0'; -- IW_in(1 downto 0) = "01"
					
				end if;

			else
				--don't want these signals enabled, could have unintended consequences during stall
				GPIO_in_en	<= '0'; 	--
				GPIO_wr_en 	<= '0'; 	--
				MEM_wr_en	<= '0';	--
				
				--if we're stalled that means an I2C operation is complete
				IW_out <= I2C_IW_reg;
				
			end if; --stall_in
		end if; --reset_n
	end process;
	
	--latch inputs
	
	--latch outputs
	--reset_out <= reset_reg;
	
end behavioral;