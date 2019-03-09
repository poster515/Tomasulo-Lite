library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all; 
use work.control_unit_types.all;
 
package ROB_functions is 
	
	function initialize_ROB(ROB_in 		: in ROB;
									ROB_DEPTH	: in integer)
		return ROB;

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
		
			if i < frst_branch_idx and results_avail = '1' and condition_met = '1' then 
				--by default, there are no valid spots in this area to buffer PM_data_in
				
				if ROB_temp(i + 1).valid = '1' and ROB_temp(i + 1).inst = IW_in then
					if IW_result_en = '1' and IW_updated = '0' then
						--n_clear_zero automatically shifts ROB entries
						ROB_temp(i + n_clear_zero).result 	:= IW_result;
						ROB_temp(i + n_clear_zero).inst 		:= ROB_temp(i + 1).inst;
						IW_updated := '1';
					end if;
				else
					ROB_temp(i) := ROB_temp(i + convert_CZ(clear_zero));
				end if;
				
			elsif i >= frst_branch_idx and results_avail = '1' and condition_met = '1' and i < scnd_branch_idx then
				--shift all instructions down, and buffer PM_data_in or update ROB results as applicable
				if ROB_temp(i + 1).valid = '0' then 
					--we can buffer PM_data_in right here, and shift down this range of instructions since the branch condition was met
					if PM_buffer_en = '1' then
						ROB_temp(i + n_clear_zero).inst 		:= PM_data_in;
						ROB_temp(i + n_clear_zero).valid 	:= '1';
						ROB_temp(i + n_clear_zero).specul	:= '1';
						ROB_temp(i + n_clear_zero).specul	:= '0';
						exit;
					end if;
				elsif IW_in = ROB_temp(i + 1).inst and ROB_temp(i + 1).valid = '1' then 
					--we can shift the matching instruction down a slot
					if IW_result_en = '1' and IW_updated = '0' then
						--n_clear_zero automatically shifts ROB entries
						ROB_temp(i + n_clear_zero).result 	:= IW_result;
						ROB_temp(i + n_clear_zero).inst 		:= ROB_temp(i + 1).inst;
						IW_updated := '1';
					end if;
				end if;
			
			elsif i >= scnd_branch_idx and results_avail = '1' and condition_met = '1' then
				--these results are still speculative. buffer PM_data_in or update ROB results as applicable
				if ROB_temp(i + 1).valid = '0' then 
					--we can buffer PM_data_in right here, mark as speculative
					if PM_buffer_en = '1' then
						ROB_temp(i + n_clear_zero).inst 		:= PM_data_in;
						ROB_temp(i + n_clear_zero).valid 	:= '1';
						ROB_temp(i + n_clear_zero).specul	:= '1';
						IW_updated := '1';
						exit;
					end if;--PM_buffer_en
				elsif IW_in = ROB_temp(i + 1).inst and ROB_temp(i + 1).valid = '1' then 
					--we can shift the matching instruction down a slot
					if IW_result_en = '1' and IW_updated = '0' then
						--n_clear_zero automatically shifts ROB entries
						ROB_temp(i + n_clear_zero).result 	:= IW_result;
						ROB_temp(i + n_clear_zero).inst 		:= ROB_temp(i + 1).inst;
						IW_updated := '1';
						
					end if;
				end if;
				
			elsif results_avail = '0'then

				--condition covers when we get to a location in the ROB that isn't valid, i.e., we can buffer PM_data_in there
				if ROB_temp(i).valid = '0' then
				
					if PM_buffer_en = '1' then
						--just insert here 
						ROB_temp(i).inst 		:= PM_data_in;
						ROB_temp(i).valid 	:= '1';
						ROB_temp(i).specul	:= speculate_res;
						exit;
					end if;
					
				--condition for when we've gotten to the last valid instruction in the ROB
				elsif ROB_temp(i).valid = '1' and ROB_temp(i + 1).valid = '0' then
					
					if PM_buffer_en = '1' then
						--n_clear_zero automatically shifts ROB entries
						ROB_temp(i + n_clear_zero).inst 		:= PM_data_in;
						ROB_temp(i + n_clear_zero).valid 	:= '1';
						ROB_temp(i + n_clear_zero).specul	:= speculate_res;
						exit;
					end if;

				--condition for when the next instruction is valid and matches IW_in, so we can shift ROB down and update IW_in result
				elsif ROB_temp(i + 1).valid = '1' and ROB_temp(i + 1).inst = IW_in then
					
					--if we can update IW_in entry, and we haven't updated any result yet, in case of identical instructions
					if IW_result_en = '1' and IW_updated = '0' then
						--n_clear_zero automatically shifts ROB entries
						ROB_temp(i + n_clear_zero).result 		:= IW_result;
						ROB_temp(i + n_clear_zero).inst 			:= ROB_temp(i + 1).inst;
						ROB_temp(i + n_clear_zero).valid 		:= '1';
						ROB_temp(i + n_clear_zero).complete 	:= '1';
						ROB_temp(i + n_clear_zero).specul 		:= ROB_temp(i + 1).specul;
						
						IW_updated := '1';
						
					else 
						--n_clear_zero automatically shifts ROB entries
						ROB_temp(i) := ROB_temp(i + convert_CZ(clear_zero));
					
					end if;
					
				--condition for when the ROB is full, we want to buffer incoming PM_data_in, and can clear the zeroth instruction (i.e., make room)
				elsif i = ROB_DEPTH - 2 and clear_zero = '1' and ROB_temp(ROB_DEPTH - 1).valid = '1' then
					
					if PM_buffer_en = '1' then
						
						ROB_temp(ROB_DEPTH - 1).inst 	:= PM_data_in;
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
					--clear_zero automatically shifts ROB entries
					ROB_temp(i)	:= ROB_temp(i + convert_CZ(clear_zero));
					
				end if; --ROB_temp(i).valid
				
			end if; --results_available = '1' and condition_met = '1'
			
		end loop;
		
		return ROB_temp;
	end;
	
	
end package body ROB_functions;