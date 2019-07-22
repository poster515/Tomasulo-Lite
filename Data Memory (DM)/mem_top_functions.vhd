library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all; 
use work.control_unit_types.all;
use work.LAB_functions.all;
 
package mem_top_functions is 
	
	function init_st_buff(	st_buff	: in store_buffer)
		return store_buffer;
		
	function check_st_buff_for_address( st_buff	: in store_buffer;
													address	: in std_logic_vector(10 downto 0))
		return std_logic;
		
	function update_st_buff(	st_buff				: in store_buffer;
										address				: in std_logic_vector(10 downto 0);
										data 					: in std_logic_vector(15 downto 0);
										buffer_inst			: in std_logic; --'0' = don't store new instruction, '1' = store new inst		
										shift_st_buff		: in std_logic; --'0' = don't shift down, '1' = shift down
										ROB_in				: in ROB;
										instruction_word	: in std_logic_vector(15 downto 0)) 
		return store_buffer;
	
	function fetch_st_buff_data(	st_buff			: in store_buffer;
											address			: in std_logic_vector(10 downto 0))
		return std_logic_vector;
		
	function check_ROB_for_iwrd(	ROB_in				: ROB;
											instruction_word	: std_logic_vector(15 downto 0))
		return std_logic;
					
	function check_ROB_for_speculation(	ROB_in				: ROB;
													instruction_word	: std_logic_vector(15 downto 0))
		return std_logic;
	
end mem_top_functions; 

package body mem_top_functions is

	--function to initialize st_buff during a reset
	function init_st_buff(	st_buff	: in store_buffer)
		return store_buffer is
		
		variable i			: integer range 0 to 9;
		variable temp_SB	: store_buffer	:= st_buff;
	begin
	
		for i in 0 to 9 loop
			temp_SB(i).iwrd		:= "0000000000000000";	
			temp_SB(i).data		:= "0000000000000000";	
			temp_SB(i).addr  		:= "00000000000";	
			temp_SB(i).valid		:= '0';
			temp_SB(i).specul		:= '0';
		end loop;
		
		return temp_SB;
	
	end function;
	
	--function to check the st_buff for a specific address aka if we have a store queued for that address
	function check_st_buff_for_address( st_buff	: in store_buffer;
													address	: in std_logic_vector(10 downto 0))
		return std_logic is
		
		variable i			: integer range 0 to 9;
		
	begin
	
		for i in 0 to 9 loop
			if st_buff(i).addr = address and st_buff(i).valid = '1' then
				return '1';
			end if;
		end loop;
		
		return '0';
	
	end function;
		
	--only function that updates st_buff
	function update_st_buff(	st_buff				: in store_buffer;
										address				: in std_logic_vector(10 downto 0);
										data 					: in std_logic_vector(15 downto 0);
										buffer_inst			: in std_logic; --'0' = don't store new instruction, '1' = store new inst		
										shift_st_buff		: in std_logic; --'0' = don't shift down, '1' = shift down
										ROB_in				: in ROB;
										instruction_word	: in std_logic_vector(15 downto 0)) 
		return store_buffer is
		
		variable i			: integer range 0 to 9;
		variable temp_SB	: store_buffer	:= st_buff;
		variable n_clear	: std_logic;
		
	begin 
	
			--now update st_buff. options: 
				--1) buffer incoming store: 				
					--buffer_st_in 		= buffer_inst and (inst_is_specul or check_st_buff_for_address(st_buff, MEM_in_1(10 downto 0))) 
					
				--2) shift st_buff down:					
					--DM_wren_in_mux_sel =(check_st_buff_for_address(st_buff, MEM_in_1(10 downto 0)) or (not(load_inst) and (not(buffer_inst) or inst_is_specul))) and st_buff(0).valid and not(st_buff(0).specul)
				
				--3) clear/re-mark st_buff instructions as non-speculative (ROB_in) 
				
			--st_buff <= update_st_buff(st_buff, MEM_in_1(10 downto 0), MEM_in_2, buffer_st_in, DM_wren_in_mux_sel, ROB_in); 
		
		for i in 0 to 8 loop
			--condition covers when we get to a location in st_buff that isn't valid, i.e., we can buffer inst there
			if temp_SB(i).valid = '0' and buffer_inst = '1' then
				if check_ROB_for_iwrd(ROB_in, instruction_word) = '1' then
					--incoming instruction is a new, valid store instruction and should be buffered 
					report "MEM_func: condition 1 reached, i = " & integer'image(i);
					temp_SB(i).iwrd		:= instruction_word;
					temp_SB(i).data		:= data;	
					temp_SB(i).addr  		:= address;	
					temp_SB(i).valid		:= '1';
					temp_SB(i).specul		:= check_ROB_for_speculation(ROB_in, instruction_word);
				else
					report "MEM_func: condition 2 reached, i = " & integer'image(i);
					temp_SB(i)				:= ((others => '0'), (others => '0'), (others => '0'), '0', '0');

				end if;
				exit;
			--condition for when we've gotten to the last valid instruction in the st_buff
			elsif temp_SB(i).valid = '1' and temp_SB(i + 1).valid = '0' then
				
				if buffer_inst = '1' then
					if check_ROB_for_iwrd(ROB_in, temp_SB(i + convert_SL(not(shift_st_buff))).data) = '1' then
						report "MEM_func: condition 3 reached, i = " & integer'image(i);
						--n_clear_zero automatically shifts temp_SB entries
						temp_SB(i + convert_SL(not(shift_st_buff))).iwrd		:= instruction_word;
						temp_SB(i + convert_SL(not(shift_st_buff))).addr		:= address;
						temp_SB(i + convert_SL(not(shift_st_buff))).data		:= data;
						temp_SB(i + convert_SL(not(shift_st_buff))).valid 		:= check_ROB_for_iwrd(ROB_in, instruction_word);
						temp_SB(i + convert_SL(not(shift_st_buff))).specul 	:= check_ROB_for_speculation(ROB_in, instruction_word);
					else
						report "MEM_func: condition 4 reached, i = " & integer'image(i);
						temp_SB(i + convert_SL(not(shift_st_buff)))				:= ((others => '0'), (others => '0'), (others => '0'), '0', '0');	

					end if;
					exit;
				else
					--results_available automatically shifts entries
					if check_ROB_for_iwrd(ROB_in, temp_SB(i).data) = '1' then
						report "MEM_func: condition 5 reached, i = " & integer'image(i);
						temp_SB(i) 	:= temp_SB(i + convert_SL(shift_st_buff));
					else
						report "MEM_func: condition 6 reached, i = " & integer'image(i);
						temp_SB(i)	:= ((others => '0'), (others => '0'), (others => '0'), '0', '0');	

					end if;
					exit;
				end if;
				
			--condition for when we've gotten to the last slot in the st_buff
			elsif temp_SB(i + 1).valid = '1' and i = 8 then
				if buffer_inst = '1' and shift_st_buff = '1' then
					if check_ROB_for_iwrd(ROB_in, temp_SB(i + 1).data) = '1' then
						--we know that we want to store inst at very end of st_buff
						report "MEM_func: condition 7 reached, i = " & integer'image(i);
						temp_SB(i + 1).iwrd		:= instruction_word;
						temp_SB(i + 1).addr		:= address;
						temp_SB(i + 1).data		:= data;
						temp_SB(i + 1).valid 	:= check_ROB_for_iwrd(ROB_in, instruction_word);
						temp_SB(i + 1).specul 	:= check_ROB_for_speculation(ROB_in, instruction_word);
					else 
						report "MEM_func: condition 8 reached, i = " & integer'image(i);
						temp_SB(i + 1)				:= ((others => '0'), (others => '0'), (others => '0'), '0', '0');	
					end if;
					exit;
				elsif buffer_inst = '0' and shift_st_buff = '1' then
					--buffer_inst = '0' and shift_st_buff = '1' makes sense; this is handled appropriately here
					report "MEM_func: condition 9 reached, i = " & integer'image(i);
					temp_SB(i + 1)					:= ((others => '0'), (others => '0'), (others => '0'), '0', '0');	
					exit;
				else
					--we can't get to a scenario with 10 speculative stores, since ROB is only 10 entries long
					--therefore, it is impossible to have buffer_inst = '1' and shift_st_buff = '0' here
					--buffer_inst = '0' and shift_st_buff = '0' means we don't want to overwrite i + 1 data
					report "MEM_func: condition 10 reached, i = " & integer'image(i);
					if check_ROB_for_iwrd(ROB_in, temp_SB(i + 1).data) = '1' then
						temp_SB(i + 1).iwrd		:= temp_SB(i + 1).iwrd;
						temp_SB(i + 1).addr		:= temp_SB(i + 1).addr;
						temp_SB(i + 1).data		:= temp_SB(i + 1).data;
						temp_SB(i + 1).valid 	:= check_ROB_for_iwrd(ROB_in, temp_SB(i + 1).iwrd);
						temp_SB(i + 1).specul 	:= check_ROB_for_speculation(ROB_in, temp_SB(i + 1).iwrd);
					else
						report "MEM_func: condition 11 reached, i = " & integer'image(i);
						temp_SB(i + 1)				:= ((others => '0'), (others => '0'), (others => '0'), '0', '0');	
					end if;
					exit;
				end if;
				
			else
				if check_ROB_for_iwrd(ROB_in, temp_SB(i).data) = '1' and temp_SB(i).valid = '1' then
					--we know that a valid entry exists in ROB and st_buff
					--results_available automatically shifts entries
					report "MEM_func: condition 12 reached, i = " & integer'image(i);
					temp_SB(i).iwrd		:= temp_SB(i + convert_SL(shift_st_buff)).iwrd;
					temp_SB(i).addr		:= temp_SB(i + convert_SL(shift_st_buff)).addr;
					temp_SB(i).data		:= temp_SB(i + convert_SL(shift_st_buff)).data;
					temp_SB(i).valid 		:= check_ROB_for_iwrd(ROB_in, temp_SB(i + convert_SL(shift_st_buff)).iwrd);
					temp_SB(i).specul 	:= check_ROB_for_speculation(ROB_in, temp_SB(i + convert_SL(shift_st_buff)).iwrd);
				else
					report "MEM_func: condition 13 reached, i = " & integer'image(i);
					temp_SB(i)				:= ((others => '0'), (others => '0'), (others => '0'), '0', '0');	
				end if;
			end if; --
		end loop;
		
		return temp_SB;
	
	end function;
	
	function fetch_st_buff_data(	st_buff			: in store_buffer;
											address			: in std_logic_vector(10 downto 0))
		return std_logic_vector is
		
		variable i : integer := 0;
		
	begin
		for i in 9 downto 0 loop	--try to find the last entry for this address
			if st_buff(i).addr = address and st_buff(i).valid = '1' then
				return st_buff(i).data;
			end if;
		end loop;
		
		return "0000000000000000";
	
	end function;
	
	function check_ROB_for_iwrd(	ROB_in				: ROB;
											instruction_word	: std_logic_vector(15 downto 0))
		return std_logic is
		
		variable i : integer := 0;
		
	begin
		for i in 0 to 9 loop	--try to find the last entry for this address
			if ROB_in(i).inst = instruction_word and ROB_in(i).valid = '1' then
				return '1';
			end if;
		end loop;
		
		return '0';
	
	end function;
					
	function check_ROB_for_speculation(	ROB_in				: ROB;
													instruction_word	: std_logic_vector(15 downto 0))
		return std_logic is
		
		variable i : integer := 0;
		
	begin
		for i in 0 to 9 loop	--try to find the last entry for this address
			if ROB_in(i).inst = instruction_word and ROB_in(i).valid = '1' then
				return ROB_in(i).specul;
			end if;
		end loop;
		
		return '0';
	
	end function;
	
end package body mem_top_functions;