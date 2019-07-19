library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all; 
use work.control_unit_types.all;
 
package ROB_functions is 
	
	function initialize_ROB(ROB_in 		: in ROB;
									ROB_DEPTH	: in integer)
		return ROB;
		
	function no_ROB_match( 	ROB_in 		: in ROB;
									IW_in			: in std_logic_vector(15 downto 0);
									ROB_DEPTH	: in integer)
		return std_logic;

	function convert_CZ ( clear_zero : in std_logic )
		return integer;
		
	function update_ROB( 
		ROB_in 				: in ROB;
		PM_data_in			: in std_logic_vector(15 downto 0);
		PM_buffer_en		: in std_logic;
		IW_in					: in std_logic_vector(15 downto 0);
		IW_result			: in std_logic_vector(15 downto 0);
		IW_result_en		: in std_logic;
		clear_zero			: in std_logic;			--this remains '0' if the ROB(0).specul = '1'
		results_avail		: in std_logic;
		condition_met		: in std_logic;
		speculate_res		: in std_logic;			--ONLY FOR PM_data_in (this is set upon receiving a branch, to let ROB know that subsequent instructions are speculative)
		frst_branch_idx	: in integer;
		scnd_branch_idx	: in integer;
		ROB_DEPTH			: in integer)

		return ROB;
end ROB_functions; 

package body ROB_functions is

	function initialize_ROB(ROB_in 		: in ROB;
									ROB_DEPTH	: in integer)
   
	return ROB is
	
	variable ROB_temp	: ROB := ROB_in;
	variable i			: integer range 0 to 9;
	
	begin
		
		for i in 0 to ROB_DEPTH - 1 loop
			
			ROB_temp(i).valid 	:= '0';
			ROB_temp(i).complete := '0';
			ROB_temp(i).inst 		:= "0000000000000000";
			ROB_temp(i).result	:= "0000000000000000";
			ROB_temp(i).specul	:= '0';
		end loop;
  
		return ROB_temp;
   end;
	
	function no_ROB_match( 	ROB_in 		: in ROB;
									IW_in			: in std_logic_vector(15 downto 0);
									ROB_DEPTH	: in integer)
		return std_logic is

	begin
	
		for i in 0 to ROB_DEPTH	- 1 loop
			if IW_in = ROB_in(i).inst then
				return '1';
			end if;
		end loop;
		
		return '0';
	end;
	
	--function to type convert std_logic to integer
	function convert_CZ ( clear_zero : in std_logic )
	
	return integer is

	begin
	
		if clear_zero = '1' then
			return 1;
		else
			return 0;
		end if;
		
	end;
	
	--update_ROB(ROB_actual, PM_data_in_reg, PM_data_valid, IW_to_update, WB_data_out, IW_update_en, clear_zero_inst, results_available, condition_met, '1');
	--this function reorders the buffer to eliminate stale/committed instructions and results
	function update_ROB( 
		ROB_in 				: in ROB;
		PM_data_in			: in std_logic_vector(15 downto 0);
		PM_buffer_en		: in std_logic;
		IW_in					: in std_logic_vector(15 downto 0);
		IW_result			: in std_logic_vector(15 downto 0);
		IW_result_en		: in std_logic;
		clear_zero			: in std_logic;			--this remains '0' if the ROB(0).specul = '1'
		results_avail		: in std_logic;
		condition_met		: in std_logic;
		speculate_res		: in std_logic;			--ONLY FOR PM_data_in (this is set upon receiving a branch, to let ROB know that subsequent instructions are speculative)
		frst_branch_idx	: in integer;
		scnd_branch_idx	: in integer;
		ROB_DEPTH			: in integer
		)
   
	return ROB is
	
	variable ROB_temp			: ROB 		:= ROB_in;
	variable i					: integer range 0 to 9;
	variable n_clear_zero	: integer 	:= 0;
	variable IW_updated		: std_logic := '0';
	variable branch_updated	: std_logic := '0';
	 
	begin
		IW_updated		:= '0';
		n_clear_zero 	:= convert_CZ(not(clear_zero));
		
		for i in 0 to ROB_DEPTH - 2 loop
			--frst_branch_idx and scnd_branch_idx default to 10 if there are no branches in ROB. 
			
--			update_ROB(	ROB_actual, PM_data_in, not(PM_data_in(15) and not(PM_data_in(14)) and not(PM_data_in(13)) and PM_data_in(12)) and not(next_IW_is_addr), 
--							IW_in, WB_data, '1', '0', results_available, condition_met, speculate_results, frst_branch_index, scnd_branch_index, ROB_DEPTH);
--		
			if i < frst_branch_idx then 
				--report "ROB_func: made it to condition 1, i = " & integer'image(i);	
				if ROB_temp(i + 1).valid = '1' and ROB_temp(i + 1).inst = IW_in then
					if IW_result_en = '1' and IW_updated = '0' then
						report "ROB_func: update ROB entry, shift down [frst_br>inst]";
						--n_clear_zero automatically shifts ROB entries
						ROB_temp(i + n_clear_zero).result 	:= IW_result;
						ROB_temp(i + n_clear_zero).inst 		:= ROB_temp(i + 1).inst;
						ROB_temp(i + n_clear_zero).complete	:= '1';
						IW_updated := '1';
					else
						ROB_temp(i + n_clear_zero) := ROB_temp(i + 1);
					end if;
					
				elsif PM_buffer_en = '1' and ROB_temp(i).valid = '0' then
					report "ROB_func: buffer PM_data_in, shift down [frst_br>inst]";
					ROB_temp(i).inst 		:= PM_data_in;
					ROB_temp(i).valid 	:= '1';
					ROB_temp(i).specul	:= speculate_res;
					exit;
					
				elsif ROB_temp(i + 1).valid = '0' and PM_buffer_en = '1' then
					report "ROB_func: buffer PM_data_in, shift down [frst_br>inst]";
					ROB_temp(i + n_clear_zero).inst 		:= PM_data_in;
					ROB_temp(i + n_clear_zero).valid 	:= '1';
					ROB_temp(i + n_clear_zero).specul	:= speculate_res;
					exit;
				
				else
					report "ROB_func: shifting ROB if applicable, i = " & integer'image(i);
					ROB_temp(i) := ROB_temp(i + convert_CZ(clear_zero));
					
--					if ROB_temp(i + convert_CZ(clear_zero)).inst(15 downto 12) = "1010" then
--						--if results_avail = '1' and condition_met = '1' then
--						if results_avail = '1' and condition_met = '0' then
--							report "ROB_func: just shift ROB entry down, and mark branch as complete.";
--							ROB_temp(i).complete := '1';
--							ROB_temp(i).specul	:= '0';
--						--elsif results_avail = '1' and condition_met = '0' then
--						elsif results_avail = '1' and condition_met = '1' then
--							report "ROB_func: just shift ROB entry down and clear branch.";
--							ROB_temp(i) 			:= ((others => '0'), '0', '0', (others => '0'), '0');
--						else
--							report "ROB_func: hit i < frst_branch_idx at i = " & integer'image(i);
--						end if;
--					else
--						report "ROB_func: unknown. i < frst_branch_idx at i = " & integer'image(i);
--					end if;
						
				end if;
				
			--elsif i >= frst_branch_idx and results_avail = '1' and condition_met = '0' and i < scnd_branch_idx then
				--if the first ROB branch condition is not met, then we've wasted time buffering a bunch of invalid instructions
				--need to purge the ROB after frst_branch_idx entirely
			elsif i >= (frst_branch_idx) and results_avail = '1' and condition_met = '1' then
				--if the first ROB branch condition is met, then we've wasted time buffering a subsequent bunch of invalid instructions
				--need to purge the ROB after frst_branch_idx entirely
				--report "ROB_func: made it to condition 2, i = " & integer'image(i);	
				report "ROB_func: clearing entry since branch was wrong.";
				ROB_temp(i) 	:= ((others => '0'), '0', '0', (others => '0'), '0');

			--elsif i >= frst_branch_idx and results_avail = '1' and condition_met = '1' and i < scnd_branch_idx then
				--shift all instructions down, and buffer PM_data_in or update ROB results as applicable
				--report "i>=frst_branch_idx and results_avail='1', condition_met='1', i=" & Integer'image(i);
				--mark all speculative results as non-speculative, from first_branch_index to second_branch_index, and clear first branch from ROB
			elsif i >= (frst_branch_idx) and results_avail = '1' and condition_met = '0' and i < (scnd_branch_idx) then
				--if the first ROB branch condition is not met, then we've correctly buffered the subsequent instructions
				--report "ROB_func: made it to condition 3, i = " & integer'image(i);	
				if ROB_temp(i + 1).valid = '0' then 
					--we can buffer PM_data_in right here, and shift down this range of instructions since the branch condition was met
					if PM_buffer_en = '1' then
						report "ROB_func: buffer PM_data_in, shift down [frst_br < insts < scnd_br]";
						ROB_temp(i + n_clear_zero).inst 		:= PM_data_in;
						ROB_temp(i + n_clear_zero).valid 	:= '1';
						ROB_temp(i + n_clear_zero).specul	:= speculate_res;
						exit;
					else
						ROB_temp(i + n_clear_zero)	:= ROB_temp(i + 1);
					end if;
				elsif IW_in = ROB_temp(i + 1).inst and ROB_temp(i + 1).valid = '1' then 
					--we can shift the matching instruction down a slot
					if IW_result_en = '1' and IW_updated = '0' then
						report "ROB_func: shift matching IW_in inst down a slot";
						--n_clear_zero automatically shifts ROB entries
						ROB_temp(i + n_clear_zero).result 	:= IW_result;
						ROB_temp(i + n_clear_zero).inst 		:= ROB_temp(i + 1).inst;
						IW_updated := '1';
					else
						
					end if;
				end if;
			
			--elsif i >= scnd_branch_idx and results_avail = '1' and condition_met = '1' then
			elsif i >= (scnd_branch_idx) and results_avail = '1' and condition_met = '0' then
				--report "ROB_func: made it to condition 4, i = " & integer'image(i);
				--these results are still speculative. buffer PM_data_in or update ROB results as applicable
				if ROB_temp(i + 1).valid = '0' then 
					--we can buffer PM_data_in right here, mark as speculative
					if PM_buffer_en = '1' then
						report "ROB_func: buffer PM_data, mark all future results as speculative.";
						ROB_temp(i + n_clear_zero).inst 		:= PM_data_in;
						ROB_temp(i + n_clear_zero).valid 	:= '1';
						ROB_temp(i + n_clear_zero).specul	:= '1';
						IW_updated := '1';
						exit;
					else
						
					end if;--PM_buffer_en
				elsif IW_in = ROB_temp(i + 1).inst and ROB_temp(i + 1).valid = '1' then 
					--we can shift the matching instruction down a slot
					if IW_result_en = '1' and IW_updated = '0' then
						--n_clear_zero automatically shifts ROB entries
						report "ROB_func: shift ROB down as appropriate.";
						ROB_temp(i + n_clear_zero).result 	:= IW_result;
						ROB_temp(i + n_clear_zero).inst 		:= ROB_temp(i + 1).inst;
						IW_updated := '1';
					else
						
					end if;
				end if;

			elsif results_avail = '0' then
				--report "ROB_func: made it to condition 5, i = " & integer'image(i);
				--condition covers when we get to a location in the ROB that isn't valid, i.e., we can buffer PM_data_in there
				if ROB_temp(i).valid = '0' then
					
					if PM_buffer_en = '1' then
						--just insert here 
						report "ROB_func: buffer PM_data in ROB.";
						ROB_temp(i).inst 		:= PM_data_in;
						ROB_temp(i).valid 	:= '1';
						ROB_temp(i).specul	:= speculate_res;
						exit;
					end if;
					
				--condition for when we've gotten to the last valid instruction in the ROB
				elsif ROB_temp(i).valid = '1' and ROB_temp(i + 1).valid = '0' then
					
					if PM_buffer_en = '1' then
						--n_clear_zero automatically shifts ROB entries
						report "ROB_func: buffer PM_data in ROB and shift ROB down."; 
						ROB_temp(i + n_clear_zero).inst 		:= PM_data_in;
						ROB_temp(i + n_clear_zero).valid 	:= '1';
						ROB_temp(i + n_clear_zero).specul	:= speculate_res;
						exit;
					else
						report "ROB_func: can't do anything, shift ROB down.";
						--n_clear_zero automatically shifts ROB entries
						ROB_temp(i + n_clear_zero) 			:= ROB_temp(i + 1);
					end if;

				--condition for when the next instruction is valid and matches IW_in, so we can shift ROB down and update IW_in result
				elsif ROB_temp(i + 1).valid = '1' and ROB_temp(i + 1).inst = IW_in then
					
					--if we can update IW_in entry, and we haven't updated any result yet, in case of identical instructions
					if IW_result_en = '1' and IW_updated = '0' then
						report "ROB_func: update IW in ROB and shift ROB down.";
						--n_clear_zero automatically shifts ROB entries
						ROB_temp(i + n_clear_zero).result 		:= IW_result;
						ROB_temp(i + n_clear_zero).inst 			:= ROB_temp(i + 1).inst;
						ROB_temp(i + n_clear_zero).valid 		:= '1';
						ROB_temp(i + n_clear_zero).complete 	:= '1';
						ROB_temp(i + n_clear_zero).specul 		:= ROB_temp(i + 1).specul;
						
						IW_updated := '1';
						
					else 
						report "ROB_func: can't do anything, just shift ROB down.";
						--n_clear_zero automatically shifts ROB entries
						ROB_temp(i) := ROB_temp(i + convert_CZ(clear_zero));
					
					end if;
					
				--condition for when the ROB is full, we want to buffer incoming PM_data_in, and can clear the zeroth instruction (i.e., make room)
				elsif i = ROB_DEPTH - 2 and clear_zero = '1' and ROB_temp(ROB_DEPTH - 1).valid = '1' then
					
					if PM_buffer_en = '1' then
						
						ROB_temp(ROB_DEPTH - 1).inst 		:= PM_data_in;
						ROB_temp(ROB_DEPTH - 1).valid 	:= '1';
						--"condition_met" isn't ready until next clock cycle
						if PM_data_in(15 downto 12) = "1010" then
							ROB_temp(ROB_DEPTH - 1).specul	:= '1';
						else
							ROB_temp(ROB_DEPTH - 1).specul	:= speculate_res;
						end if;
						exit;
					end if;
				
				else
					report "ROB_func: can't do anything, just shift ROB down.";
					--clear_zero automatically shifts ROB entries
					ROB_temp(i)	:= ROB_temp(i + convert_CZ(clear_zero));
					
				end if; --ROB_temp(i).valid
			else
				report "ROB_func: Unknown state reached.";
				
			end if; --results_available = '1' and condition_met = '1'
			
		end loop;
		
		return ROB_temp;
	end;
	
	
end package body ROB_functions;