library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all; 
use work.control_unit_types.all;
 
package mem_top_functions is 
	
	function init_st_buff(	st_buff	: in store_buffer)
		return store_buffer;
		
	function check_st_buff_for_address( st_buff	: in store_buffer;
													address	: in std_logic_vector(10 downto 0))
		return std_logic;
		
	function store_new_store(	st_buff				: in store_buffer;
										address				: in std_logic_vector(10 downto 0);
										data 					: in std_logic_vector(15 downto 0);
										inst_is_specul		: in std_logic;
										shift_st_buff		: in std_logic)
		return store_buffer;
	
	function fetch_st_buff_data(	st_buff			: in store_buffer;
											address			: in std_logic_vector(10 downto 0))
		return std_logic_vector;
	
end mem_top_functions; 

package body mem_top_functions is

	--function to initialize st_buff during a reset
	function init_st_buff(	st_buff	: in store_buffer)
		return store_buffer is
		
		variable i			: integer range 0 to 9;
		variable temp_SB	: store_buffer	:= st_buff;
	begin
	
		for i in 0 to 9 loop
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
			if st_buff(i).addr = address then
				return '1';
			end if;
		end loop;
		
		return '0';
	
	end function;
		
	--only function that updates st_buff
	function store_new_store(	st_buff				: in store_buffer;
										address				: in std_logic_vector(10 downto 0);
										data 					: in std_logic_vector(15 downto 0);
										store_inst			: in std_logic; --'0' = don't store new instruction, '1' = store new inst		
										shift_st_buff		: in std_logic) --'0' = don't shift down, '1' = shift down

		return store_buffer is
		
		variable i			: integer range 0 to 9;
		variable temp_SB	: store_buffer	:= st_buff;
		variable n_clear	: std_logic;
		
	begin 

		for i in 0 to 8 loop
			--condition covers when we get to a location in st_buff that isn't valid, i.e., we can buffer inst there
			if temp_SB(i).valid = '0' and store_inst = '1' then
				--incoming instruction is a new, valid store instruction and should be buffered 
				temp_SB(i).data		:= data;	
				temp_SB(i).addr  		:= address;	
				temp_SB(i).valid		:= '1';
				temp_SB(i).specul		:= store_inst;
				exit;
				
			--condition for when we've gotten to the last valid instruction in the st_buff
			elsif temp_SB(i).valid = '1' and temp_SB(i + 1).valid = '0' then
				
				if store_inst = '1' then
					--n_clear_zero automatically shifts temp_SB entries
					temp_SB(i + not(shift_st_buff)).addr		:= address;
					temp_SB(i + not(shift_st_buff)).data		:= data;
					temp_SB(i + not(shift_st_buff)).valid 		:= store_inst;
					temp_SB(i + not(shift_st_buff)).specul 	:= store_inst;
					exit;
				else
					--results_available automatically shifts entries
					temp_SB(i) := temp_SB(i + shift_st_buff);
					exit;
				end if;

			--TODO: CHECK THIS CONDITION
			elsif i = 8 and results_available = '1' and addr_valid = '1' then

				if store_inst = '1' then
					--n_clear_zero automatically shifts temp_SB entries
					temp_SB(i + not(shift_st_buff)).addr		:= address;
					temp_SB(i + not(shift_st_buff)).data		:= data;
					temp_SB(i + not(shift_st_buff)).valid 		:= store_inst;
					temp_SB(i + not(shift_st_buff)).specul 	:= store_inst;
					exit;
				else
					--results_available automatically shifts entries
					temp_SB(i) := temp_SB(i + shift_st_buff);
					exit;
				end if;
				
			--TODO: CHECK THIS CONDITION	
			else
				--results_available automatically shifts entries
				temp_SB(i) := temp_SB(i + shift_st_buff);
				
			end if; --
		
		return temp_SB;
	
	end function;
	
	function fetch_st_buff_data(	st_buff			: in store_buffer;
											address			: in std_logic_vector(10 downto 0))
		return std_logic_vector;
	
	
	
end package body mem_top_functions;