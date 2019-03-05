library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all; 
use work.LAB_functions.all;
 
package ROB_functions is 
	function initialize_ROB(ROB_in : in ROB)
		return ROB;

	function convert_CZ ( clear_zero : in std_logic )
		return integer;
		
	function update_ROB( 
		ROB_in 			: in ROB;
		PM_data_in		: in std_logic_vector(15 downto 0);
		PM_buffer_en	: in std_logic;
		IW_in			: in std_logic_vector(15 downto 0);
		IW_result		: in std_logic_vector(15 downto 0);
		IW_result_en	: in std_logic;
		clear_zero		: in std_logic	)

		return ROB;
end ROB_functions; 

package body ROB_functions is

	function initialize_ROB(ROB_in : in ROB)
   
	return ROB is
	
	variable ROB_temp	: ROB := ROB_in;
	variable i			: integer range 0 to ROB_DEPTH - 1;
	
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
	
	--this function reorders the buffer to eliminate stale/committed instructions and results
	function update_ROB( 
		ROB_in 			: in ROB;
		PM_data_in		: in std_logic_vector(15 downto 0);
		PM_buffer_en	: in std_logic;
		IW_in			: in std_logic_vector(15 downto 0);
		IW_result		: in std_logic_vector(15 downto 0);
		IW_result_en	: in std_logic;
		clear_zero		: in std_logic;			--this remains '0' if the ROB(0).specul = '1'
		results_avail	: in std_logic;
		condition_met	: in std_logic;
		speculate_res	: in std_logic			--this is set upon receiving a branch, to let ROB know that subsequent instructions are speculative
		)
   
	return ROB is
	
	variable ROB_temp		: ROB := ROB_in;
	variable i				: integer range 0 to ROB_DEPTH - 1;
	variable n_clear_zero	: integer 	:= 0;
	variable IW_updated		: std_logic := '0';
	variable branch_updated	: std_logic := '0';
	 
	begin
		IW_updated		:= '0';
		n_clear_zero 	:= convert_CZ(not(clear_zero));
		--updating n_clear_zero based on whether 0th result is speculative or not
		--n_clear_zero 	:= convert_CZ(not(clear_zero and ROB_temp(0).specul));
		
		for i in 0 to 8 loop

			--condition covers when we get to a location in the ROB that isn't valid, i.e., we can buffer PM_data_in there
			if ROB_temp(i).valid = '0' then
			
				if PM_buffer_en = '1' then
					ROB_temp(i).inst 	:= PM_data_in;
					ROB_temp(i).valid 	:= '1';
					--"condition_met" isn't ready until next clock cycle
					if PM_data_in(15 downto 12) = "1010" then
						ROB_temp(i).specul	:= '1';
					else
						ROB_temp(i).specul	:= '0';
					end if;
					exit;
				end if;
				
			--condition for when we've gotten to the last valid instruction in the ROB
			elsif ROB_temp(i).valid = '1' and ROB_temp(i + 1).valid = '0' then
				
				if PM_buffer_en = '1' then
					--n_clear_zero automatically shifts ROB entries
					ROB_temp(i + n_clear_zero).inst 	:= PM_data_in;
					ROB_temp(i + n_clear_zero).valid 	:= '1';
					
					--"condition_met" isn't ready until next clock cycle
					if PM_data_in(15 downto 12) = "1010" then
						ROB_temp(i + n_clear_zero).specul	:= '1';
					else
						ROB_temp(i + n_clear_zero).specul	:= '0';
					end if;
					exit;
				end if;

			--condition for when the next instruction is valid and matches IW_in, so we can shift ROB down and update IW_in result
			elsif ROB_temp(i + 1).valid = '1' and ROB_temp(i + 1).inst = IW_in and ROB_temp(i + 1).specul = '0' then
				
				--if we can update IW_in entry, and we haven't updated any result yet, in case of identical instructions
				if IW_result_en = '1' and IW_updated = '0' then
					--n_clear_zero automatically shifts ROB entries
					--TODO, figure out how to handle branch clearing
					ROB_temp(i + n_clear_zero).result 		:= IW_result;
					ROB_temp(i + n_clear_zero).inst 		:= ROB_temp(i + 1).inst;
					ROB_temp(i + n_clear_zero).valid 		:= '1';
					ROB_temp(i + n_clear_zero).complete 	:= '1';
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
						ROB_temp(ROB_DEPTH - 1).specul	:= '0';
					end if;
				end if;
			
			else
				--clear_zero automatically shifts ROB entries
				--TODO, figure out how to handle branch clearing
				ROB_temp(i) := ROB_temp(i + convert_CZ(clear_zero));
				
			end if; --ROB_temp(i).valid
			
		end loop;
		
		return ROB_temp;
	end;
	
	
end package body ROB_functions;