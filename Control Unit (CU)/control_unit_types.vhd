library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all; 
 
package control_unit_types is 

	type branch_addr is
		record
			addr_met		: std_logic_vector(15 downto 0);	--buffers branch address
			addr_unmet	: std_logic_vector(15 downto 0);	--buffers PC_reg + 1, at time that branch is fetched from PM
			addr_valid  : std_logic; 						--0 = not valid/not used, 1 = valid and in pipeline or waiting for commit 
		end record;
		
	type branch_addrs is array (9 downto 0) of branch_addr;

	--LAB declarations
	type LAB_entry is
		record
			inst			: std_logic_vector(15 downto 0);	--buffers instruction
			inst_valid  : std_logic; 							--0 = not valid/not used, 1 = valid and in pipeline or waiting for commit 	
			addr			: std_logic_vector(15 downto 0);	--buffers memory address, if applicable
			addr_valid  : std_logic; 							--0 = not valid/not used, 1 = valid and in pipeline or waiting for commit 	
		end record;
	
	--type declaration for actual LAB, which has 5 entries, one for each pipeline stage
	type LAB_actual is array(4 downto 0) of LAB_entry;
	
	type ROB_entry is
		record
		  inst			: std_logic_vector(15 downto 0);	--buffers instruction
		  complete  	: std_logic; 							-- 0 = no result yet, 1 = valid result buffered
		  valid			: std_logic;							--tracks if valid instruction buffered
		  result			: std_logic_vector(15 downto 0); --buffers result. 
		  specul			: std_logic;							--'0' = not speculative, '1' = speculative
		end record;
	
	type ROB is array(9 downto 0) of ROB_entry;
	
	type SIB_entry is
		record
		  inst			: std_logic_vector(15 downto 0);	--buffers instruction
		  valid			: std_logic;							--tracks if valid instruction buffered
		end record;
	
	type SIB is array(9 downto 0) of SIOB_entry;

end control_unit_types;