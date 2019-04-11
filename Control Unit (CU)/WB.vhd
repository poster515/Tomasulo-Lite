--Written by: Joe Post

--This file generates control signals necessary to forward data to other pipeline stages and write back data to RF.
--This file will not contain the RF however. 
--This file will also contain a ROB which contains each instruction as it is issued from PM (i.e., in order), and 
-- will only commit in-order the results. 


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.arrays.ALL;
use work.LAB_functions.ALL;
use work.ROB_functions.ALL;
use work.control_unit_types.all;

entity WB is
	generic ( ROB_DEPTH : integer := 10 );
   port ( 
		--Input data and clock
		reset_n, reset_MEM 	: in std_logic;
		sys_clock				: in std_logic;	
		IW_in, PM_data_in		: in std_logic_vector(15 downto 0); --IW from MEM and from PM, via LAB, respectively
		LAB_stall_in			: in std_logic;		--set high when an upstream CU block needs this 
		MEM_out_top				: in std_logic_vector(15 downto 0);
		GPIO_out					: in std_logic_vector(15 downto 0);
		I2C_out					: in std_logic_vector(15 downto 0);
		condition_met			: in std_logic;		--signal to WB for ROB. as soon as "results_available" goes high, need to evaluate all instructions after first branch
		results_available		: in std_logic;		--signal to WB for ROB. as soon as it goes high, need to evaluate all instructions after first branch
		
		--Control
		RF_in_demux				: out std_logic_vector(4 downto 0); -- selects which register to write back to
		RF_wr_en					: out std_logic;	--
					
		--Outputs
		stall_out		: out std_logic;
		WB_data_out		: out std_logic_vector(15 downto 0);
		ROB_out			: out ROB
	);
end WB;

architecture behavioral of WB is

	component mux_4_new is
	PORT
	(
		data0x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		data1x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		data2x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		data3x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		sel			: IN STD_LOGIC_VECTOR (1 DOWNTO 0);
		result		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
	end component mux_4_new;

	signal WB_out_mux_sel								: std_logic_vector(1 downto 0); --selects data input to redirect to RF
	signal stall, zero_inst_match						: std_logic; 					--overall stall signal;
	signal PM_data_in_reg, IW_to_update 			: std_logic_vector(15 downto 0);
	signal WB_data											: std_logic_vector(15 downto 0);
	signal PM_data_valid, IW_update_en				: std_logic;
	signal clear_zero_inst, speculate_results		: std_logic;
	signal i, j												: integer range 0 to ROB_DEPTH;
	signal frst_branch_index, scnd_branch_index	: integer range 0 to ROB_DEPTH;
	signal ROB_actual										: ROB;
	
	--signal tracks whether the next IW is a memory address (for jumps, loads, etc)
	signal next_IW_is_addr	: std_logic;

begin

	--mux for WB output
	WB_out_mux	: mux_4_new
	port map (
		data0x	=> ROB_actual(0).result,
		data1x  	=> MEM_out_top, 		
		data2x  	=> GPIO_out,
		data3x	=> I2C_out,
		sel 		=> WB_out_mux_sel,
		result  	=> WB_data
	);
	
	stall <= LAB_stall_in;
	
	--update whether ROB zeroth instruction matches the new IW_in, does not depend on ROB(0).inst itself since it won't change
	process(IW_in, ROB_actual, results_available, condition_met)
	begin
		if ROB_actual(0).inst = IW_in and ROB_actual(0).valid = '1' and zero_inst_match = '0' then
			zero_inst_match <= '1';
		
		elsif ROB_actual(1).inst = IW_in and ROB_actual(1).valid = '1' and zero_inst_match = '1' then
			zero_inst_match <= '1';
			
		elsif ROB_actual(0).inst(15 downto 12) = "1010" and (ROB_actual(0).specul = '0' or (results_available = '1' and condition_met = '1')) then
			zero_inst_match <= '1';
			
		else
			zero_inst_match <= '0';
		end if;
		
	end process;

	process(reset_n, sys_clock, stall)
	begin
		if reset_n = '0' then
		
			ROB_actual 			<= initialize_ROB(ROB_actual, ROB_DEPTH);
			speculate_results <= '0';
			next_IW_is_addr 	<= '0';
			stall_out 			<= '0';
			RF_in_demux 		<= "00000";
			RF_wr_en 			<= '0';
			WB_out_mux_sel 	<= "01";
			clear_zero_inst 	<= '0'; 
			IW_update_en		<= '0';
			PM_data_valid		<= '0';
			PM_data_in_reg 	<= "0000000000000000";
			IW_to_update		<= "0000000000000000";
			
		elsif rising_edge(sys_clock) then
			
			if stall = '0' then

--				--have to ensure that new PM_data_in is buffered, if its not EOP or a stall
--				if PM_data_in(15 downto 0) /= "1111111111111111" then
--					PM_data_in_reg 	<= PM_data_in;
--					PM_data_valid		<= '1';	--enables buffering PM_data_in into ROB
--				end if; 
--				
				stall_out <= '0';
				
				if PM_data_in(15 downto 0) /= "1111111111111111" and reset_MEM = '1' then
				
					if next_IW_is_addr = '1' then
						next_IW_is_addr <= '0';
						
					else 
						--if the instruction is a branch or ld/st, then the next IW will be a memory address vice another instruction
						if PM_data_in(15 downto 12) = "1000" or PM_data_in(15 downto 12) = "1010" then
							next_IW_is_addr <= '1';
						end if;
					end if; --next_IW_is_addr
					
					if PM_data_in(15 downto 12) = "1010" then
						speculate_results 	<= '1';
						
					elsif results_available = '1' and condition_met = '1' then
						speculate_results 	<= '0';
					
					end if;
					
					--update_ROB(ROB_in, PM_data_in, PM_buffer_en, IW_in, IW_result, IW_result_en, clear_zero, results_avail, condition_met
					--				speculate_res, frst_branch_idx, scnd_branch_idx, ROB_DEPTH	)
				
					if (zero_inst_match = '1' and (ROB_actual(0).specul = '0' or (results_available = '1' and condition_met = '0'))) or ROB_actual(0).complete = '1' then 
						report "1. writing back ROB(0) results to RF";
						--incoming MEM IW matches zeroth ROB entry which should be committed in specul = '0'
						ROB_actual 	<= update_ROB(	ROB_actual, PM_data_in, not(PM_data_in(15) and not(PM_data_in(14)) and not(PM_data_in(13)) and PM_data_in(12)) and not(next_IW_is_addr), 
															IW_in, WB_data, '0', '1', results_available, condition_met, speculate_results, frst_branch_index, scnd_branch_index, ROB_DEPTH);

						RF_in_demux 		<= IW_in(11 downto 7);	--use IW to find destination register for the aforementioned instructions
						
						--only if zeroth instruction is non-speculative can we write back results to RF
						clear_zero_inst 	<= '1'; 	--enable clearing the zeroth instruction since zero_inst_match = '1'
						
						--commit results if its not a branch or jump 
						if ROB_actual(0).inst(15 downto 12)	/= "1010" and ROB_actual(0).inst(15 downto 12) /= "1001" then
							RF_wr_en 		<= '1';	--enable writing back into RF
						end if;
						
					elsif zero_inst_match = '1' and ROB_actual(0).specul = '1' then 
						report "2. can't write speculative ROB(0) results to RF";
						--incoming MEM IW matches zeroth ROB entry which can't be committed since specul = '1'
						ROB_actual 	<= update_ROB(	ROB_actual, PM_data_in, not(next_IW_is_addr), IW_in, WB_data, '1', '0', 
															results_available, condition_met, '1', frst_branch_index, scnd_branch_index, ROB_DEPTH);
						clear_zero_inst 	<= '0'; 
						
					elsif zero_inst_match = '0' and ROB_actual(0).complete = '0' then 
						report "3. can't write ROB(0) results (if applicable) to RF";
						--incoming MEM IW does not match zeroth ROB entry so just update ROB entry for IW_in
						ROB_actual 	<= update_ROB(	ROB_actual, PM_data_in, not(PM_data_in(15) and not(PM_data_in(14)) and not(PM_data_in(13)) and PM_data_in(12)) and not(next_IW_is_addr), 
															IW_in, WB_data, '1', '0', results_available, condition_met, speculate_results, frst_branch_index, scnd_branch_index, ROB_DEPTH);
						
						clear_zero_inst 	<= '0'; 
												
					elsif ROB_actual(1).complete = '1' and clear_zero_inst = '1' and ROB_actual(1).specul = '0' and ROB_actual(0).specul = '0' then		
						report "4. can write complete, non-speculative ROB(1) results to RF";
						--previous clock cycle had a non-speculative zero_inst_match, and it happened again this clock cycle
						ROB_actual 	<= update_ROB(	ROB_actual, PM_data_in, not(next_IW_is_addr), IW_to_update, WB_data, IW_update_en, clear_zero_inst, 
															results_available, condition_met, speculate_results, frst_branch_index, scnd_branch_index, ROB_DEPTH);
						clear_zero_inst 	<= '0'; 	
						
						--only if first instruction is non-speculative can we write back results to RF
						if ROB_actual(1).inst(15 downto 12)	/= "1010" and ROB_actual(1).inst(15 downto 12) /= "1001" then
							RF_wr_en 		<= not(ROB_actual(1).specul);
						end if;
						
						clear_zero_inst 	<= not(ROB_actual(1).specul);	--enable clearing zeroth instruction if its complete
						RF_in_demux 		<= ROB_actual(1).inst(11 downto 7);	--
						
					else
						report "5. not sure. buffering PM_data_in and updating ROB with results.";
						ROB_actual 	<= update_ROB(	ROB_actual, PM_data_in, not(next_IW_is_addr), IW_to_update, WB_data, '1', clear_zero_inst, 
															results_available, condition_met, speculate_results, frst_branch_index, scnd_branch_index, ROB_DEPTH);
						clear_zero_inst 	<= '0'; 				
					end if;
					
				elsif reset_MEM = '0' then
					report "6. CPU not stalled, have a no-op, and MEM_reset is '0'.";
					
					ROB_actual 	<= update_ROB(	ROB_actual, PM_data_in, '1', IW_to_update, WB_data, '0', clear_zero_inst, 
														results_available, condition_met, speculate_results, frst_branch_index, scnd_branch_index, ROB_DEPTH);
					clear_zero_inst 	<= '0'; 	
					
				else
					report "7. reached else statement.";
					
					ROB_actual 	<= update_ROB(	ROB_actual, PM_data_in, '0', IW_to_update, WB_data, '0', clear_zero_inst, 
														results_available, condition_met, speculate_results, frst_branch_index, scnd_branch_index, ROB_DEPTH);
					clear_zero_inst 	<= '0'; 	
					
				end if; --PM_data_in
				
--				if zero_inst_match = '1' and (ROB_actual(0).specul = '0' or (results_available = '1' and condition_met = '0')) then --have a non-speculative match to zeroth ROB inst and therefore re-issue result
--					
--					if reset_MEM = '1' then
--						report "Incoming IW from MEM matches zeroth instruction in ROB.";
--						IW_update_en		<= '0'; 						--don't want to update ROB since we just want to update RF
--						RF_in_demux 		<= IW_in(11 downto 7);	--use IW to find destination register for the aforementioned instructions
--						
--						--only if zeroth instruction is non-speculative can we write back results to RF
--						clear_zero_inst 	<= '1'; 	--enable clearing the zeroth instruction since zero_inst_match = '1'
--						
--						--commit results if its not a branch or jump 
--						if ROB_actual(0).inst(15 downto 12)	/= "1010" and ROB_actual(0).inst(15 downto 12) /= "1001" then
--							RF_wr_en 		<= '1';	--enable writing back into RF
--						end if;
--						
--					else
--						RF_wr_en 			<= '0'; --disable writing back into RF
--						clear_zero_inst 	<= '0'; --disable clearing the zeroth instruction since zero_inst_match = '1'
--
--					end if; --reset_MEM	
--					
--				else --IW_in does not match zeroth instruction, or instruction result is speculative, therefore need to buffer results in ROB
--
--					--if reset_MEM = '1', then we know incoming data and IW_in are valid, and can choose to do something with them
--					if reset_MEM = '1' then
--					
--						IW_to_update	<= IW_in;
--						
--						if IW_in(15 downto 0) /= "1111111111111111" then
--							IW_update_en		<= '1';
--						else
--							IW_update_en		<= '0';
--						end if;
--						--condition covers the case when the previous clock cycle we had a match for the zeroth instruction, and we another match
--						--and the result is valid
--						if ROB_actual(1).complete = '1' and clear_zero_inst = '1' and ROB_actual(1).specul = '0' and ROB_actual(0).specul = '0' then
--							--only if first instruction is non-speculative can we write back results to RF
--							if ROB_actual(1).inst(15 downto 12)	/= "1010" and ROB_actual(1).inst(15 downto 12) /= "1001" then
--								RF_wr_en 		<= not(ROB_actual(1).specul);
--							end if;
--							clear_zero_inst 	<= not(ROB_actual(1).specul);	--enable clearing zeroth instruction if its complete
--							RF_in_demux 		<= ROB_actual(1).inst(11 downto 7);	--
--
--						else 
--							RF_wr_en 			<= '0';
--							clear_zero_inst 	<= '0'; --disable clearing the zeroth instruction for the next instruction in ROB
--							
--						end if;
--						
--					else
--						--don't buffer IW_in results since reset_MEM = '0'
--						IW_update_en		<= '0';
--						RF_wr_en 			<= '0';
--						
--					end if;
--					
--				end if; --zero_inst_match
				
				--this if..else series assigns the correct data input corresponding to IW_in
				if (ROB_actual(0).complete = '1') or (ROB_actual(1).complete = '1' and clear_zero_inst = '1') then
					WB_out_mux_sel <= "00";
					
				--for loads and ALU operations, forward MEM_top_data to RF
				elsif ((IW_in(15 downto 12) = "1000") and (IW_in(1) = '0')) or (IW_in(15) = '0') or
						(IW_in(15 downto 12) = "1100") then
					WB_out_mux_sel <= "01";
					
				--GPIO reads
				elsif (IW_in(15 downto 12) = "1011" and IW_in(1 downto 0) = "00") then
					WB_out_mux_sel <= "10";
								
				--I2C reads	
				elsif (IW_in(15 downto 12) = "1011" and IW_in(1 downto 0) = "10") then
					WB_out_mux_sel <= "11";
					
				else
					WB_out_mux_sel <= "00";
					
				end if; ----IW_in (various)
				
			elsif stall = '1' then
				
				RF_wr_en <= '0';
				stall_out <= '1';
				PM_data_valid	<= '0';
				
			end if; --LAB_stall_in

		end if; --reset_n
	end process;
	
	process(reset_n, sys_clock, ROB_actual)
	begin
		if reset_n = '0' then
			frst_branch_index <= ROB_DEPTH;
			scnd_branch_index <= ROB_DEPTH;
			
		elsif rising_edge(sys_clock) then
		
			for i in 0 to ROB_DEPTH - 1 loop
				if ROB_actual(i).inst(15 downto 12) = "1010" and ROB_actual(i).specul = '1' then
					frst_branch_index <= i;
					for j in 0 to ROB_DEPTH - 1 loop
						--this statement sets the index of the first, speculative branch that hasn't been resolved yet in the ROB_actual
						if ROB_actual(j).inst(15 downto 12) = "1010" and ROB_actual(j).specul = '1' and j > i then
							scnd_branch_index <= i;
							exit;
						elsif j = ROB_DEPTH - 1 then 
							scnd_branch_index <= ROB_DEPTH;
							exit;
						end if;
					end loop;
				elsif i = ROB_DEPTH - 1 then 
					frst_branch_index <= ROB_DEPTH;
					exit;
				end if;
			end loop;
		end if; --reset_n
	end process;
	
--	ROB_process : process(reset_n, sys_clock, ROB_actual)
--	begin
--		if reset_n = '0' then
--		
--			--reset ROB
--			ROB_actual 			<= initialize_ROB(ROB_actual, ROB_DEPTH);
--			speculate_results <= '0';
--			next_IW_is_addr 	<= '0';
--			
--		elsif sys_clock'event and sys_clock = '1' then
--			--update_ROB parameters:
--			
----			ROB_in 				: in ROB;
----			PM_data_in			: in std_logic_vector(15 downto 0);
----			PM_buffer_en		: in std_logic;
----			IW_in					: in std_logic_vector(15 downto 0);
----			IW_result			: in std_logic_vector(15 downto 0);
----			IW_result_en		: in std_logic;
----			clear_zero			: in std_logic;			--this remains '0' if the ROB(0).specul = '1'
----			results_avail		: in std_logic;
----			condition_met		: in std_logic;
----			speculate_res		: in std_logic;			--ONLY FOR PM_data_in (this is set upon receiving a branch, to let ROB know that subsequent instructions are speculative)
----			frst_branch_idx	: in integer;
----			scnd_branch_idx	: in integer;
----			ROB_DEPTH			: in integer
--			
--			if next_IW_is_addr = '1' then
--				next_IW_is_addr <= '0';
--			else 
--				--if the instruction is a jump, branch, or ld/st, then the next IW will be a memory address vice another instruction
--				if PM_data_in(15 downto 12) = "1000" or PM_data_in(15 downto 12) = "1001"  or PM_data_in(15 downto 12) = "1010" then
--					next_IW_is_addr <= '1';
--				end if;
--				
--				--don't buffer jumps because they are unconditional
--				if PM_data_in(15 downto 12) /= "1001" and next_IW_is_addr = '0' then
--				
--					if PM_data_in(15 downto 12) = "1010" then
--						speculate_results 	<= '1';
--						ROB_actual 				<= update_ROB(	ROB_actual, PM_data_in_reg, PM_data_valid, IW_to_update, WB_data, IW_update_en, clear_zero_inst, 
--																		results_available, condition_met, '1', frst_branch_index, scnd_branch_index, ROB_DEPTH);
--					elsif results_available = '1' and condition_met = '1' then
--						speculate_results 	<= '0';
--						ROB_actual 				<= update_ROB(	ROB_actual, PM_data_in_reg, PM_data_valid, IW_to_update, WB_data, IW_update_en, clear_zero_inst, 
--																		results_available, condition_met, '0', frst_branch_index, scnd_branch_index, ROB_DEPTH);
--					else 
--						ROB_actual 				<= update_ROB(	ROB_actual, PM_data_in_reg, PM_data_valid, IW_to_update, WB_data, IW_update_en, clear_zero_inst, 
--																		results_available, condition_met, speculate_results, frst_branch_index, scnd_branch_index, ROB_DEPTH);
--					end if;
--					
--				end if;
--				
--			end if;
--			
--		end if; --reset_n
--	end process;
	
	ROB_out 		<= ROB_actual;
	WB_data_out	<= WB_data;
	
end behavioral;