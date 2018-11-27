-- Written by Joe Post

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
------------------------------------------------------------
entity LAB is
	generic ( LAB_MAX	: integer	:= 5 	);
	port (

		sys_clock, reset_n  	: in std_logic;
		stall_pipeline			: in std_logic; --needed when waiting for certain commands, should be formulated in top level CU module
		ID_tag			: in std_logic_vector(4 downto 0); --source registers for instruction in ID stage
		EX_tag			: in std_logic_vector(4 downto 0); --source registers for instruction in EX stage (results available)
		MEM_tag			: in std_logic_vector(4 downto 0); --source registers for instruction in MEM stage (results available)
		WB_tag			: in std_logic_vector(4 downto 0); --source registers for instruction in WB stage (results available)
		
		tag_to_commit	: in integer;	--input from WB stage, which denotes the tag of the instruction that has been written back, only valid for single clock
		
		PM_data_in		: in 	std_logic_vector(15 downto 0);
		PC					: out std_logic_vector(10 downto 0);
		IW					: out std_logic_vector(15 downto 0);
		MEM				: out std_logic_vector(15 downto 0)
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
		
	signal LAB	: LAB_actual;
	signal LAB2	: LAB_actual;
	
	signal MOAB			: MOAB_actual;
	
	--input buffer for PM (i.e., program instructions)
	signal PM_data_reg	: std_logic_vector(15 downto 0);
	signal ID_tag_reg, EX_tag_reg : std_logic_vector(4 downto 0);
	
	--Program counter (PC) register
	signal PC_reg		: std_logic_vector(10 downto 0);
	
	--signal to denote that LAB is full and we need to stall PM input clock
	signal LAB_full	: std_logic := '0';

	--signal to denote that the next IW is actually a memory or auxiliary value, and should go to MOAB
	signal next_IW_to_MOAB : std_logic := '0';
	
	--signal for last open LAB spot found
	signal last_LAB_spot 		: integer := 0;
	signal tag_to_commit_reg	: integer;
	
	--registers for various outputs (IW register, and memory address register)
	signal MEM_reg		: std_logic_vector(15 downto 0)	:= "0000000000000000";
	signal IW_reg		: std_logic_vector(15 downto 0) 	:= "0000000000000000";
	
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
								
		variable i 			: integer 		:= 0;	
		
	begin
		
		for i in 0 to 4 loop
			if(LAB_in(i).valid	= '0') then
			
				return LAB_in(i).tag;
				
			end if;
		end loop; --for i
		
		return 5; --come here if there are no spots available
	end function;
	
	--function to write new IW into LAB
	function load_IW(	 	LAB_in	: in LAB_actual;
								LAB_spot	: in integer;
								IW_in		: in std_logic_vector(15 downto 0)	) 
	
		return LAB_actual is
								
		variable LAB_temp 		: LAB_actual 			:= LAB_in;
		
	begin
	
		LAB_temp(LAB_spot).inst 	:= IW_in;
		LAB_temp(LAB_spot).valid 	:= '1';
		
		return LAB_temp;
	end function;
	
	--function to invalidate tag of instruction that has been completed
	function commit_IW(	 	LAB2_in	: in LAB_actual;
									tag_in	: in integer		) 
		return LAB_actual is
								
		variable i 				: integer 		:= 0;	
		variable LAB2_temp 	: LAB_actual 	:= LAB2_in;
		
	begin
		for i in 0 to 4 loop
			if LAB2_temp(i).tag = tag_in then
				LAB2_temp(i).valid := '0';
			end if; --if tag_to_commit_reg
		end loop; --for i

		return LAB2_temp;
	end function; --commit_IW
	
	--function to commit tag from MOAB
	function commit_addr(	 	MOAB_in	: in MOAB_actual;
										tag_in	: in integer		) 
		return MOAB_actual is
								
		variable i 				: integer 		:= 0;	
		variable MOAB_temp 	: MOAB_actual 	:= MOAB_in;
		
	begin
		for i in 0 to 4 loop
			if MOAB_temp(i).tag = tag_in then
				MOAB_temp(i).valid := '0';
			end if; --if tag_to_commit_reg
		end loop; --for i

		return MOAB_temp;
	end function; --commit_addr
	
	--function to dispatch next instruction from LAB
	function dispatch_LAB0(	 	LAB_in	: in 	LAB_actual  	) 
		return LAB_actual is
								
		variable LAB_temp : LAB_actual 	:= LAB_in;
	begin
		if LAB_temp(0).valid = '1' then
			IW_reg <= LAB_temp(0).inst;
			--now that the IW is no longer in LAB, can just invalidate it
			LAB_temp(0).valid := '0';
		end if;
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
						LAB_temp(i).inst 		:= LAB_temp(j).inst;
						--SWAP TAGS
						k							:= LAB_temp(i).tag;
						LAB_temp(i).tag 		:= LAB_temp(j).tag;
						LAB_temp(j).tag		:= k;
						--END SWAP TAGS
						LAB_temp(i).valid 	:= '1';
						LAB_temp(j).valid 	:= '0'; --invalidate so next loop can use it
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
								
		variable MOAB_temp 				: MOAB_actual 							:= MOAB_in;
		
	begin
		for i in 0 to 4 loop
			if (MOAB_temp(i).valid = '0') then
				MOAB_temp(i).data 	:= IW;
				MOAB_temp(i).tag 		:= last_LAB_spot;
				MOAB_temp(i).valid 	:= '1';
			end if;
		end loop; --for i

		return MOAB_temp;
	end function;
	
	function dispatch_MOAB0 ( 	MOAB_in	: in MOAB_actual;
										tag_in	: in integer		)
		return MOAB_actual is
		
		variable MOAB_temp	: MOAB_actual  := MOAB_in;
		variable i				: integer		:= 0;
		
		begin
			for i in 0 to 4 loop
			if (MOAB_temp(i).tag = tag_in) then
				MEM_reg <= MOAB_temp(i).data;
				MOAB_temp(i).valid 	:= '0';
			end if;
		end loop; --for i

		return MOAB_temp;
	end function;
	
	--function to check if LAB tag exists in MOAB
	function check_MOAB_for_tag ( 	MOAB_in	: in MOAB_actual;
												tag_in	: in integer		)
		return std_logic is
		
		variable MOAB_temp	: MOAB_actual := MOAB_in;
		variable tag_temp		: integer		:= tag_in;
		variable i				: integer		:= 0;
		begin
			for i in 0 to 4 loop
			if (MOAB_temp(i).tag = tag_temp and MOAB_temp(i).valid = '1') then
				return '1';
			end if;
		end loop; --for i

		--if we make it here, there is no tag in MOAB corresponding to LAB tag
		return '0';
	end function;
	
	
	function shift_MOAB ( 	MOAB_in	: in MOAB_actual 	)
		return MOAB_actual is
		
		variable MOAB_temp	: MOAB_actual  := MOAB_in;
		variable i, j, k		: integer		:= 0;
		
		begin
			for i in 0 to 3 loop
			if (MOAB_temp(i).valid = '0') then
				for j in (i + 1) to 4 loop
					if (MOAB_temp(j).valid = '1') then
						MOAB_temp(i).data 	:= MOAB_temp(j).data;
						--SWAP TAGS
						k							:= MOAB_temp(i).tag;
						MOAB_temp(i).tag 		:= MOAB_temp(j).tag;
						MOAB_temp(j).tag		:= k;
						--END SWAP TAGS
						MOAB_temp(i).valid 	:= '1';
						MOAB_temp(j).valid 	:= '0'; --invalidate so next loop can use it
						exit; --exit if next instruction
					end if;
				end loop; --for j
			end if;
		end loop; --for i

		return MOAB_temp;
	end function;
	
	--when we dispatch an instruction from the LAB, buffer that instruction into LAB2 to keep
	--track of registers in pipeline
	function queue_LAB2(	 	LAB2_in	: in LAB_actual;
									inst_in	: in std_logic_vector(15 downto 0);
									tag_in	: in integer									) 
		return LAB_actual is
								
		variable LAB2_temp 	: LAB_actual 							:= LAB2_in;

	begin
		for i in 0 to 4 loop
			if (LAB2_temp(i).valid = '0') then
				LAB2_temp(i).inst 	:= inst_in;
				LAB2_temp(i).tag 		:= tag_in;
				LAB2_temp(i).valid 	:= '1';
			end if;
		end loop; --for i

		return LAB2_temp;
	end function;
	
	--function to detect RAW, WAR, and WAW hazards
	impure function data_haz_check(	LAB_in	: in LAB_actual;
												LAB2_in	: in LAB_actual		)
		return LAB_actual is
		
		variable LAB_temp				: LAB_actual  	:= LAB_in;
		variable LAB2_temp			: LAB_actual  	:= LAB2_in;
		variable i, j, k, tag_temp	: integer		:= 0;
		variable LAB_entry_temp		: LAB_entry;
		
	begin
		--TODO: how to check for branches and jumps?
				if EX_tag_reg = LAB_temp(0).inst(11 downto 7) then

			--SWAP LAB ENTRIES
				LAB_entry_temp		:= LAB_temp(0);
				LAB_temp(0) 		:= LAB_temp(2);
				LAB_temp(2)			:= LAB_entry_temp;
				
		end if;
		
		if ID_tag_reg = LAB_temp(0).inst(11 downto 7) then
			--SWAP LAB ENTRIES
				LAB_entry_temp	:= LAB_temp(0);
				LAB_temp(0) 	:= LAB_temp(2);
				LAB_temp(2)		:= LAB_entry_temp;
				
		end if;
		
		if ID_tag_reg = LAB_temp(1).inst(11 downto 7) then
			--SWAP LAB ENTRIES
				LAB_entry_temp	:= LAB_temp(1);
				LAB_temp(1) 	:= LAB_temp(3);
				LAB_temp(3)		:= LAB_entry_temp;
				
		end if;

		for i in 0 to (LAB_MAX - 3) loop
			if 	((LAB_temp(i).inst(11) = LAB_temp(i + 1).inst(11) and 
					LAB_temp(i).inst(10) = LAB_temp(i + 1).inst(10) and
					LAB_temp(i).inst(9) = LAB_temp(i + 1).inst(9) and
					LAB_temp(i).inst(8) = LAB_temp(i + 1).inst(8) and
					LAB_temp(i).inst(7) = LAB_temp(i + 1).inst(7)) or				--WAW hazard
		
					(LAB_temp(i).inst(11) = LAB_temp(i + 1).inst(6) and 
					LAB_temp(i).inst(10) = LAB_temp(i + 1).inst(5) and 
					LAB_temp(i).inst(9) = LAB_temp(i + 1).inst(4) and 
					LAB_temp(i).inst(8) = LAB_temp(i + 1).inst(3) and 
					LAB_temp(i).inst(7) = LAB_temp(i + 1).inst(2))) and 	--RAW hazard
					
					LAB_temp(i + 1).valid = '1'	and 							--verify that i + 1 is valid, otherwise we don't care
					LAB_temp(i + 1).inst(15 downto 12) /= "1010" and 		--if it's a BNEZ, we don't care about RAW/WAW
					LAB_temp(i + 1).inst(15 downto 12) /= "1011" and 		--if it's a BNE, we don't care about RAW/WAW
					LAB_temp(i + 1).inst(15 downto 12) /= "1100" then		--if it's a JMP, we don't care about RAW/WAW				
			
				for j in (i + 2) to (LAB_MAX - 1) loop
					if LAB_temp(i + 1).inst(11 downto 8) /= LAB_temp(j).inst(11 downto 8) and
						LAB_temp(i + 1).inst(11 downto 8) /= LAB_temp(j).inst(7 downto 4)  and
						LAB_temp(j).valid = '1' 	and 													--verify that i + 1 is valid, otherwise we don't care
						LAB_temp(j).inst(15 downto 12) /= "1010" and 								--if it's a BNEZ, we don't care about RAW/WAW
						LAB_temp(j).inst(15 downto 12) /= "1011" and 								--if it's a BNE, we don't care about RAW/WAW
						LAB_temp(j).inst(15 downto 12) /= "1100" then							--if it's a JMP, we don't care about RAW/WAW				
						
						--put j into i + 1 space, and move entire LAB down, first save i + 1
						LAB_entry_temp		:= LAB_temp(i + 1);
						LAB_temp(i + 1) 	:= LAB_temp(j);
						
						--shift entire LAB down by one
						for k in 0 to (j - i - 3) loop
							LAB_temp(j - k) := LAB_temp(j - 1 - k);
						end loop; --end k loop
						
						LAB_temp(i + 2)	:= LAB_entry_temp;
						--exit j for loop, now that suitable substitute has been found and we've re-arranged the LAB. 
						exit;
						
					elsif LAB_temp(j).inst(15 downto 12) /= "1010" or 								
							LAB_temp(j).inst(15 downto 12) /= "1011" or 								
							LAB_temp(j).inst(15 downto 12) /= "1100" then				
						exit; --if the found instruction not posing a RAW/WAW hazard is a branch/jump, exit j loop. 	 
						
					else
						--if WAW or RAW are detected or j is invalid, do nothing this iteration, go to j + 1		
					end if;
				end loop; --j loop
			end if;
		end loop; --i loop
		
	return LAB_temp;
	end function;
	
begin

	process(reset_n, sys_clock)
		begin
		
		if(reset_n = '0') then
			LAB 			<= init_LAB(LAB);
			PC_reg 		<= "00000000000";
			
		elsif rising_edge(sys_clock) then
		
			--first just check whether this is an auxiliary value (e.g., memory address)
			if next_IW_to_MOAB = '1' then
				MOAB <= write_to_MOAB(MOAB, last_LAB_spot, PM_data_reg);
				next_IW_to_MOAB <= '0';
			end if;
			
			--next, if an instruction needs to be committed, do that. this frees up a LAB spot.
			if tag_to_commit_reg < 5 then
				LAB2 	<= commit_IW(LAB, tag_to_commit_reg);
				MOAB 	<= commit_addr(MOAB, tag_to_commit_reg);
				--TODO: why do I not also shift LAB2 and MOAB?
			end if; --tag_to_commit_reg
			
			--next, if pipeline isn't stalled, just get dispatch zeroth instruction
			if stall_pipeline = '0' then 
			
				--dispatch first (zeroth) instruction in LAB, if it exists
				if ( LAB(0).valid = '1' ) then
				
					--if there is a memory address included, dispatch it too.
					--the following condition is based on memory ops requiring an address:
					if LAB(0).inst = "1XXXXXXXXXXXXX1X" then
					
						--check if MOAB has corresponding memory address
						if check_MOAB_for_tag(MOAB, LAB(0).tag) = '1' then
							--dispatch memory address
							MOAB 	<= dispatch_MOAB0(MOAB, LAB(0).tag);
							MOAB 	<= shift_MOAB(MOAB);
							
							--place the soon-to-be-dispatched instruction in LAB2
							LAB2 	<= queue_LAB2(LAB2, LAB(0).inst, LAB(0).tag);
							
							--now dispatch
							LAB 	<= dispatch_LAB0(LAB);
							LAB 	<= shift_LAB(LAB);
						else
							report "Memory address not yet buffered";
						end if;
					else --its any other instruction, just dispatch anyway
						LAB2 	<= queue_LAB2(LAB2, LAB(0).inst, LAB(0).tag);
						LAB 	<= dispatch_LAB0(LAB);
						LAB 	<= shift_LAB(LAB);
					end if;
				else
					--TODO do we need to output something LAB(0) is invalid?
				end if;
			else
					--TODO do we need to output something if the pipeline is stalled?
			end if; --stall_pipeline
		
			--now, try to find available spot in LAB
			last_LAB_spot <= find_LAB_spot(LAB);
			
			--now try to buffer next instruction from PM
			if( last_LAB_spot < 5 ) then 
				--there is a spot in the LAB for it, go load IW into LAB
				LAB 		<= load_IW(LAB, last_LAB_spot, PM_data_reg);
				
				--increment PC to get next IW
				PC_reg 	<= std_logic_vector(unsigned(PC_reg) + 1);
				
				--now check for whether or not there's another IW coming after this one that needs to go into MOAB
				if (PM_data_reg = "1XXXXXXXXXXXXX1X") then --condition based on LD, ST, BNEZ, BNE, and JMP
					next_IW_to_MOAB <= '1';
				else
					next_IW_to_MOAB <= '0';
				end if; --PM_data_reg
			else
				--there is no spot in LAB, no need to modify PC_reg
				LAB_full <= '1';
			
			end if; --find_LAB_spot
			
			--now try to reorganize now that the LAB has been dispatched and/or filled
			LAB <= data_haz_check(LAB, LAB2);
			
		end if; --reset_n
	end process;
		--latch inputs
		tag_to_commit_reg <= tag_to_commit;
		PM_data_reg	<= PM_data_in;
		ID_tag_reg <= ID_tag;
		EX_tag_reg <= EX_tag;
		
		--latch outputs
		PC 	<= PC_reg;
		IW 	<= IW_reg;
		MEM 	<= MEM_reg;
end architecture arch;