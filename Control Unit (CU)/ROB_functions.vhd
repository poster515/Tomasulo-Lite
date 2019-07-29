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
		
	--function to determine whether a given loop index, i, is greater than or equal to the first branch index of the ROB
	function loop_i_gtoet_FBI(	i			: integer;
										branch	: integer)
		return std_logic;
	
	--function to determine whether a given loop index, i, is less than the second branch index of the ROB
	function loop_i_lt_SBI(	i			: integer;
									branch	: integer)
		return std_logic;
		
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
	
	variable ROB_temp			: ROB 			:= ROB_in;
	variable i					: integer range 0 to 9;
	variable n_clear_zero	: integer 		:= 0;
	variable target_index	: integer		:= 0;
	variable speculate		: std_logic		:= '0';
	variable PM_data_buffered : std_logic 	:= '0';
	variable IW_updated		: std_logic		:= '0';
	variable actual_index 	: integer		:= 0;
	 
	begin
		
		n_clear_zero 	:= convert_CZ(not(clear_zero));
		
		for i in 0 to ROB_DEPTH - 2 loop
			target_index 	:= i + convert_CZ(clear_zero) + convert_CZ(loop_i_gtoet_FBI(i, frst_branch_idx) and results_avail and not(condition_met) and loop_i_lt_SBI(i, scnd_branch_idx));
			
			--speculate		:= not(loop_i_gtoet_FBI(i, frst_branch_idx) and results_avail and not(condition_met) and loop_i_lt_SBI(i, scnd_branch_idx));
	
			if loop_i_gtoet_FBI(i, frst_branch_idx) = '1' and loop_i_lt_SBI(i, scnd_branch_idx) = '1' then
				--need to evaluate based on location WRT branch location
				speculate		:= not(results_avail and not(condition_met));
			else
				--just use current speculative value
				speculate		:= ROB_temp(target_index).specul;
			end if;
			
			report "ROB_func: speculate = " & integer'image(convert_CZ(speculate)) & ", clear_zero = " & integer'image(convert_CZ(clear_zero));
			
			if target_index = i then
				actual_index := i;
			elsif results_avail = '1' then --TODO: evaluate whether FBI < i < SBI is a necessary condition here too.
				actual_index := i;
			else
				actual_index := i + n_clear_zero;
			end if;
			
			if target_index < 10 then
				
				if IW_in = ROB_temp(target_index).inst and IW_result_en = '1' and IW_updated = '0' then
					report "ROB_func: 1. i = " & integer'image(i) & ", target_index = " & integer'image(target_index);
					ROB_temp(actual_index).inst		:= ROB_temp(target_index).inst;
					ROB_temp(actual_index).complete	:= '1';
					ROB_temp(actual_index).valid		:= ROB_temp(target_index).valid;
					ROB_temp(actual_index).result 	:= IW_result;
					ROB_temp(actual_index).specul		:= speculate;
					
				elsif results_avail = '1' and condition_met = '1' and loop_i_gtoet_FBI(i, frst_branch_idx) = '1' then
					--need to purge all instruction subsequent to first_branch_idx
					report "ROB_func: 2. i = " & integer'image(i) & ", target_index = " & integer'image(target_index);
					ROB_temp(actual_index)	:= ((others => '0'), '0', '0', (others => '0'), '0');

				elsif ROB_temp(target_index).valid = '0' and PM_buffer_en = '1' and PM_data_buffered = '0' then
					report "ROB_func: 3. i = " & integer'image(i) & ", target_index = " & integer'image(target_index);
					ROB_temp(actual_index).inst		:= PM_data_in;
					ROB_temp(actual_index).valid		:= '1';
					
					if PM_data_in(15 downto 12) = "1010" then
						ROB_temp(actual_index).specul := '1';
					else
						ROB_temp(actual_index).specul	:= speculate;
					end if;
					
					PM_data_buffered := '1';
					
				else
					report "ROB_func: 4. i = " & integer'image(i) & ", target_index = " & integer'image(target_index);
					ROB_temp(actual_index).inst		:= ROB_temp(target_index).inst;
					ROB_temp(actual_index).complete	:= ROB_temp(target_index).complete;
					ROB_temp(actual_index).valid		:= ROB_temp(target_index).valid;
					ROB_temp(actual_index).result 	:= ROB_temp(target_index).result;
					ROB_temp(actual_index).specul		:= ROB_temp(target_index).valid and speculate;
					
				end if;
			elsif (i = 8 and target_index = 10) or (i = 9 and target_index = 11) or (i = 9 and target_index = 10) then
				--clear_zero = '1' and these are instructions resolved due to being in the first branch.
				--either buffer PM_data_in or just write in zeros
				if PM_buffer_en = '1' and PM_data_buffered = '0' then
					report "ROB_func: 5. i = " & integer'image(i) & ", target_index = " & integer'image(target_index);
					ROB_temp(i).inst		:= PM_data_in;
					ROB_temp(i).valid		:= '1';
					PM_data_buffered		:= '1';
				else
					report "ROB_func: 6. i = " & integer'image(i) & ", target_index = " & integer'image(target_index);
					ROB_temp(i)				:= ((others => '0'), '0', '0', (others => '0'), '0');
				end if;
				
			else
				report "ROB_func: 7. i = " & integer'image(i) & ", target_index = " & integer'image(target_index);
				ROB_temp(actual_index)	:= ROB_temp(target_index);
			end if;
		end loop;
		
		return ROB_temp;
	end;
	
	--function to determine whether a given loop index, i, is greater than or equal to the first branch index of the ROB
	function loop_i_gtoet_FBI(	i			: integer;
										branch	: integer)
		return std_logic is
		
	begin
		if i = 0 and branch = 0 then
			return '1';
		elsif i > branch - 1 then
			return '1';
		else 
			return '0';
		end if;
			
	end;
	
	--function to determine whether a given loop index, i, is less than the second branch index of the ROB
	function loop_i_lt_SBI(	i			: integer;
									branch	: integer)
		return std_logic is
		
	begin
		if i < branch then
			return '1';
		else 
			return '0';
		end if;
			
	end;
	
end package body ROB_functions;