library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all; 
use work.control_unit_types.all;
 
package RF_top_functions is 
	
	function RF_complete_in_ROB(	ROB_in		: in ROB;	
											RF_out_mux	: in std_logic_vector(4 downto 0))
		return std_logic;
		
	function get_RF_data_from_ROB(	ROB_in		: in ROB;	
												RF_out_mux	: in std_logic_vector(4 downto 0))
		return std_logic_vector;
	
end RF_top_functions; 

package body RF_top_functions is

	function RF_complete_in_ROB(	ROB_in		: in ROB;	
											RF_out_mux	: in std_logic_vector(4 downto 0))
		return std_logic is
		
	variable i : integer	:= 0;
	begin
		
		for i in 9 downto 0 loop
			
			if ROB_in(i).inst(11 downto 7) = RF_out_mux and ROB_in(i).complete = '1' and
				not(ROB_in(i).inst(15 downto 12) = "1010") and
				not(ROB_in(i).inst(15 downto 12) = "1000" and ROB_in(i).inst(1) = '1') and 
				not(ROB_in(i).inst(15 downto 12) = "1011" and ROB_in(i).inst(0) = '1') then
				--if we've found the instruction in the ROB, and it's complete, and it's not a DM or GPIO write instruction or branch, then we're good
				return '1';
				
			elsif ROB_in(i).inst(11 downto 7) = RF_out_mux and ROB_in(i).complete = '0' and
				not(ROB_in(i).inst(15 downto 12) = "1010") and
				not(ROB_in(i).inst(15 downto 12) = "1000" and ROB_in(i).inst(1) = '1') and 
				not(ROB_in(i).inst(15 downto 12) = "1011" and ROB_in(i).inst(0) = '1') then
				--if we've found the instruction in the ROB, and it's not complete, and it's not a DM or GPIO write instruction or branch, then we're not good
				return '0';
				
			elsif i = 0 then
				return '0';
			end if;
			
		end loop;
	
		return '1';
		
	end function;
		
	function get_RF_data_from_ROB(	ROB_in		: in ROB;	
												RF_out_mux	: in std_logic_vector(4 downto 0))
		return std_logic_vector is
		
	variable i : integer	:= 0;
	begin
		
		for i in 9 downto 0 loop
			
			if ROB_in(i).inst(11 downto 7) = RF_out_mux and ROB_in(i).complete = '1' then
				return ROB_in(i).result;
			end if;
			
		end loop;
		return ROB_in(0).result;
	end function;
	
end package body RF_top_functions;