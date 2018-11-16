-- Written by Joe Post

--Credit for a majority of this source goes to Peter Samarin: https://github.com/oetr/FPGA-I2C-Slave/blob/master/I2C_slave.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
------------------------------------------------------------
entity LAB is
	port (

		sys_clock, reset_n  	: in std_logic;
		stall_pipeline			: in std_logic; --needed when waiting for certain commands, should be formulated in top level CU module
		ID_op1, ID_op2			: in std_logic_vector(4 downto 0); --source registers for instruction in ID stage
		EX_op1, EX_op2			: in std_logic_vector(4 downto 0); --source registers for instruction in EX stage
		MEM_op1, MEM_op2		: in std_logic_vector(4 downto 0); --source registers for instruction in MEM stage (results available)
		WB_op1, WB_op2			: in std_logic_vector(4 downto 0); --source registers for instruction in WB stage (results available)
		tag_to_commit			: in integer;	--input from WB stage, which denotes the tag of the instruction that has been written back, only valid for single clock

		
		PM_data_in		: in 	std_logic_vector(15 downto 0);
		PC					: out std_logic_vector(10 downto 0);
		IW					: out std_logic_vector(15 downto 0)
	);
end entity LAB;

------------------------------------------------------------
architecture arch of LAB is

	
	type MOAB_entry is
		record
		  data		: std_logic_vector(15 downto 0);	--buffers data such as memory addresses 
		  tag       : integer range 0 to 4; 			--associated with inst currently in LAB
		  valid     : std_logic; 							--0 = not valid/not used, 1 = valid and in pipeline or waiting for commit 	
		end record;

	type LAB_entry is
		record
		  inst		: std_logic_vector(15 downto 0);	--buffers instruction
		  tag       : integer range 0 to 4; 			--provides unique identifier for inst in pipeline
		  valid     : std_logic; 							--0 = not valid/not used, 1 = valid and in pipeline or waiting for commit 	
		end record;
	
	--type declaration for actual MOAB, which has 5 entries, one for each pipeline stage
	type MOAB_actual is array(4 downto 0) of MOAB_entry;
	
	--type declaration for actual LAB, which has 5 entries, one for each pipeline stage
	type LAB_actual is array(4 downto 0) of LAB_entry;
		
	--create array of LAB_entry to create LAB, and initialize to all zeroes
	signal LAB	: LAB_actual;
	
	--input buffer for PM (i.e., program instructions)
	signal PM_data_reg	: std_logic_vector(15 downto 0);
	
	--PM output register
	signal PC_reg		: std_logic_vector(10 downto 0);
	
	--signal to denote that LAB is full and we need to stall PM input clock
	signal LAB_full	: std_logic := '0';
	
	--register for IW output
	signal IW_reg		: std_logic_vector(15 downto 0);
	
	--signal to denote that the next IW is actually a memory or auxiliary value, and should go to MOAB
	signal next_IW_to_MOAB : std_logic := '0';
	
	--signal for last LAB spot found
	signal last_LAB_spot	: integer := 0;
	
--	component PM is
--	port (
--		address	: IN STD_LOGIC_VECTOR (10 DOWNTO 0);
--		clken		: IN STD_LOGIC  := '1';
--		clock		: IN STD_LOGIC  := '1';
--		q			: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
--	);
--	end component PM;
	
	--function which initializes LAB	tags									
	function init_LAB (	LAB_in	: in 	LAB_actual ) 
		return LAB_actual is
								
		variable i 			: integer 		:= 0;	
		variable LAB_temp : LAB_actual 	:= LAB_in;
		
	begin
		
		for i in 0 to 4 loop
			LAB_temp(i).inst		:= "0000000000000000";
			LAB_temp(i).tag 		:= i;
			LAB_temp(i).valid		:= '0';
		end loop; --for i
		
		return LAB_temp;
	end function;
	
	--function to determine if there are any open LAB spots	
	--if an open spot exists, take it:	(return [spot to take])
	--if not, return a stall 			:	(return 5 since there is no fifth spot in LAB)
	function find_LAB_spot(	 	LAB_in	: in 	LAB_actual 		) 
		return integer is
								
		variable i 			: integer 								:= 0;	
		variable LAB_temp : LAB_actual 							:= LAB_in;
		variable IW_temp	: std_logic_vector(15 downto 0) 	:= IW;
		
	begin
		
		for i in 0 to 4 loop
			if(LAB_temp(i).valid	= '0') then
			
				return LAB_temp(i).tag;
				
			end if;
		end loop; --for i
		
		return 5; --come here if there are no spots available
	end function;
	
	--function to write new IW into LAB
	function load_IW(	 	LAB_in	: in LAB_actual;
								LAB_spot	: in integer;
								IW			: in std_logic_vector(15 downto 0)	) 
	
		return LAB_actual is
								
		variable LAB_temp 		: LAB_actual 			:= LAB_in;
		variable LAB_spot_temp	: integer				:= LAB_spot;
		variable IW_temp			: std_logic_vector	:= IW;
		
	begin
	
		LAB_temp(LAP_spot_temp).inst 	<= IW_temp;
		LAB_temp(LAP_spot_temp).valid <= '1';
		
		return LAB_temp;
	end function;
	
	--function to invalidate tag of instruction that has been completed
	function commit_IW(	 	LAB_in	: in 	LAB_actual   ) 
		return LAB_actual is
								
		variable i 			: integer 		:= 0;	
		variable LAB_temp : LAB_actual 	:= LAB_in;
		
	begin
		--TODO
		for i in 0 to 4 loop
			if tag_to_commit_reg = LAB_temp(i).tag then
				LAB_temp(i).valid = '0';
				--TODO: find way to also clear MOAB entry for tag if it exists
			end if; --if tag_to_commit_reg
		end loop; --for i

		return LAB_temp;
	end function;
	
	--function to dispatch next instruction from LAB
	function dispatch_LAB0(	 	LAB_in	: in 	LAB_actual  	) 
		return LAB_actual is
								
		variable LAB_temp : LAB_actual 	:= LAB_in;
		
	begin
		
		IW_reg <= LAB_temp(0).inst;
		
		LAB_temp(0).valid = '0';
		--if we leave the loop, we haven't found a LAB spot. return 0.
		return LAB_temp;
	end function;
	
	--function to dispatch next instruction from LAB
	function shift_LAB(	 	LAB_in	: in 	LAB_actual  	) 
		return LAB_actual is
								
		variable LAB_temp : LAB_actual 	:= LAB_in;
		variable i, j, k	: integer 		:= 0;
	begin
		for i in 0 to 3 loop
			if (LAB_temp(i).valid = '0') then
				for j in (i + 1) to 4 loop
					if (LAB_temp(j).valid = '1') then
						LAB_temp(i).inst 		<= LAB_temp(j).inst;
						--SWAP TAGS
						k							<= LAB_temp(i).tag;
						LAB_temp(i).tag 		<= LAB_temp(j).tag;
						LAB_temp(j).tag		<= k;
						--END SWAP TAGS
						LAB_temp(i).valid 	<= '1';
						LAB_temp(j).valid 	<= '0'; --invalidate so next loop can use it
						exit; --exit if next instruction
					end if;
				end loop; --for j
			end if;
		end loop; --for i

		return LAB_temp;
	end function;
	
	--function to buffer in next IW to MOAB for jumps, etc.
	function write_to_MOAB(	 	MOAB_in			: in MOAB_actual;
										last_LAB_spot	: in integer;
										IW					: in std_logic_vector(15 downto 0)	) 
		return MOAB_actual is
								
		variable MOAB_temp 				: MOAB_actual 							:= MOABB_in;
		variable last_LAB_spot_temp 	: integer 								:= last_LAB_spot;
		variable IW_temp 					: std_logic_vector(15 downto 0) 	:= IW;
	begin
		for i in 0 to 4 loop
			if (MOAB_temp(i).valid = '0') then
				MOAB_temp(i).data 	= IW_temp;
				MOAB_temp(i).tag 		= last_LAB_spot_temp;
				MOAB_temp(i).valid 	= '1';
			end if;
		end loop; --for i

		return MOAB_temp;
	end function;
	
begin

	process(reset_n, sys_clock)
		begin
		
		if(reset_n = '0') then
			LAB 			<= init_LAB(LAB);
			PC_reg 		<= '0';
			
		elsif rising_edge(sys_clock) then
		
			--first just check whether this is an auxiliary value (e.g., memory address)
			if next_IW_to_MOAB = '1' then
				MOAB <= write_to_MOAB(MOAB, last_LAB_spot);
				next_IW_to_MOAB <= '0';
			end if;
			
			--next, if pipeline isn't stalled, just get dispatch zeroth instruction
			if stall_pipeline = '0' then 
				--dispatch first (zeroth) instruction in LAB, if it exists
				if ( LAB(0).valid = '1' ) then
				
					LAB 	<= dispatch_LAB0(LAB);
					LAB 	<= shift_LAB(LAB);
					
				end if;
			end if;
		
			last_LAB_spot <= find_LAB_spot(LAB);
			
			if( last_LAB_spot < 5 ) then 
				--there is a spot in the LAB for it, go load IW into LAB
				LAB 		<= load_IW(LAB, last_LAB_spot, PM_data_reg);
				
				--increment PC to get next IW
				PC_reg 	<= PC_reg + 1;
				
				--now check for whether or not there's another IW coming after this one that needs to go into MOAB
				if (PM_data_reg(15) and PM_data_reg(1) = '1') then
					next_IW_to_MOAB <= '1';
				else
					next_IW_to_MOAB <= '0';
				end if; --PM_data_reg
			else
				--there is no spot in LAB
				LAB_full <= '1';
			
			end if; --find_LAB_spot
			
			--now try to reorganize now that the LAB has been dispatched and/or filled
			--TODO
			LAB <= data_haz_check(LAB);
			
		end if; --reset_n
	end process;
		tag_to_commit_reg <= tag_to_commit;
		PM_data_reg	<= PM_data_in;
		PC <= PC_reg;
		IW <= IW_reg;
end architecture arch;