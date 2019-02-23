library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all; 
 
package LAB_functions is 

	--LAB declarations
	type LAB_entry is
		record
		  inst			: std_logic_vector(15 downto 0);	--buffers instruction
		  inst_valid   : std_logic; 							--0 = not valid/not used, 1 = valid and in pipeline or waiting for commit 	
		  addr			: std_logic_vector(15 downto 0);	--buffers memory address, if applicable
		  addr_valid   : std_logic; 							--0 = not valid/not used, 1 = valid and in pipeline or waiting for commit 	
		end record;
	
	--type declaration for actual LAB, which has 5 entries, one for each pipeline stage
	type LAB_actual is array(4 downto 0) of LAB_entry;
	
	--function which initializes LAB	tags									
	function init_LAB (	LAB_in	: in LAB_actual;
								LAB_MAX	: in integer		) 
		return LAB_actual; 
		
	function shiftLAB_and_bufferPM(	LAB_in		: in LAB_actual;
												PM_data_in	: in std_logic_vector(15 downto 0);
												issued_inst	: in integer;
												LAB_MAX		: in integer 		)
		return LAB_actual;
	
end LAB_functions; 

package body LAB_functions is

	--function which initializes LAB	tags									
	function init_LAB (	LAB_in	: in 	LAB_actual;
								LAB_MAX	: in integer		) 
		return LAB_actual is
								
		variable i 			: integer 		:= 0;	
		variable LAB_temp : LAB_actual 	:= LAB_in;
		
	begin
		
		for i in 0 to LAB_MAX - 1 loop
			LAB_temp(i).inst				:= "0000000000000000";
			LAB_temp(i).inst_valid		:= '0';
			LAB_temp(i).addr				:= "0000000000000000";
			LAB_temp(i).addr_valid		:= '1';
		end loop; --for i
		
		return LAB_temp;
	end function;
	
	--function to shift LAB down and buffer Program Memory input
	function shiftLAB_and_bufferPM(	LAB_in		: in LAB_actual;
												PM_data_in	: in std_logic_vector(15 downto 0);
												issued_inst	: in integer; --location of instruction that was issued, start shift here
												LAB_MAX		: in integer 		)
		return LAB_actual is
								
		variable i 			: integer 		:= issued_inst;	
		variable LAB_temp	: LAB_actual	:= LAB_in;
		
	begin
		
		for i in 0 to LAB_MAX - 2 loop
			if i >= issued_inst then
				if (LAB_temp(i).inst_valid = '1') and (LAB_temp(i + 1).inst_valid = '0') then
				
					LAB_temp(i).inst := PM_data_in;
					LAB_temp(i + 1).addr			:= (others => '0');
					
					if PM_data_in(15 downto 14) = "10" and ((PM_data_in(1) nand PM_data_in(0)) = '1') then
						LAB_temp(i + 1).addr_valid	:= '0';
					else
						LAB_temp(i + 1).addr_valid	:= '1';
					end if;
					
				elsif i = LAB_MAX - 2 and LAB_temp(i).inst_valid = '1' and LAB_temp(i + 1).inst_valid = '1' then
				
					LAB_temp(i + 1).inst 		:= PM_data_in;
					LAB_temp(i + 1).addr			:= (others => '0');
						
					if PM_data_in(15 downto 14) = "10" and ((PM_data_in(1) nand PM_data_in(0)) = '1') then
						LAB_temp(i + 1).addr_valid	:= '0';
					else
						LAB_temp(i + 1).addr_valid	:= '1';
					end if;
					
				else
					LAB_temp(i) := LAB_temp(i + 1);
				end if;
			end if; --i >= issued_inst
		end loop; --for i
		
		return LAB_temp; --come here if there are no spots available
	end function;

end package body LAB_functions;
