-- Written by Joe Post

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
------------------------------------------------------------
entity LAB is
	generic ( 	LAB_MAX	: integer	:= 5;	
					LAB2_MAX : integer 	:= 5 	);
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
	
	--Program counter (PC) register
	signal PC_reg, PC_reg_prev		: std_logic_vector(10 downto 0);
	
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
		
		for i in 0 to LAB_MAX - 1 loop
			LAB_temp(i).inst		:= "0000000000000000";
			LAB_temp(i).tag 		:= i;
			LAB_temp(i).valid		:= '0';
		end loop; --for i
		
		return LAB_temp;
	end function;
	
		--function which initializes MOAB tags									
	function init_MOAB (	MOAB_in	: in 	MOAB_actual ) 
		return MOAB_actual is
								
		variable i 			: integer 		:= 0;	
		variable MOAB_temp : MOAB_actual 	:= MOAB_in;
		
	begin
		
		for i in 0 to LAB_MAX - 1 loop
			MOAB_temp(i).data		:= "0000000000000000";
			MOAB_temp(i).tag 		:= i;
			MOAB_temp(i).valid	:= '0';
		end loop; --for i
		
		return MOAB_temp;
	end function;
	
	--function to determine if there are any open LAB spots	
	--if an open spot exists, take it:	(return [spot to take])
	--if not, return a stall 			:	(return 5 since there is no fifth spot in LAB)
	impure function find_LAB_spot(	 	LAB_in	: in 	LAB_actual 		) 
		return integer is
								
		variable i 			: integer 		:= 0;	
		
	begin
		
		for i in 0 to LAB_MAX - 2 loop
			if(LAB_in(i).valid = '0') then
				return i; 
			elsif LAB_in(i).valid = '1' and LAB_in(i + 1).valid = '0' and stall_pipeline = '0' then
				return i;
			elsif LAB_in(i).valid = '1' and LAB_in(i + 1).valid = '0' and stall_pipeline = '1' then
				--during a stall condition, provide the next LAB spot during a stall condition
				return i + 1;
			end if;
		end loop; --for i
		
		--this function is needed to ensure LAB can continue to saturate LAB after a stall condition clears
		if LAB_in(LAB_MAX - 1).valid = '1' and stall_pipeline = '0' then
			return LAB_MAX - 1;
		end if;
		
		return LAB_MAX; --come here if there are no spots available
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
		for i in 0 to LAB_MAX - 1 loop
			if LAB2_temp(i).tag = tag_in then
				report "Found tag in LAB2, tag = " & Integer'image(tag_in) & ". Loop index i = " & Integer'image(i) & ".";
				LAB2_temp(i).valid := '0';
				LAB2_temp(i).inst := "0000000000000000";
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
		for i in 0 to LAB_MAX - 1 loop
			if MOAB_temp(i).tag = tag_in then
				MOAB_temp(i).valid := '0';
			end if; --if tag_to_commit_reg
		end loop; --for i

		return MOAB_temp;
	end function; --commit_addr
	
	--function to shift entire LAB down after an instruction dispatch
	--assumes that zeroth instruction has indeed been dispatched
	--NOT TO BE USED IF ZEROTH INSTRUCTION HAS NOT BEEN DISPATCHED
	function shift_LAB(	 	LAB_in	: in 	LAB_actual  	) 
		return LAB_actual is
								
		variable LAB_temp : LAB_actual 	:= LAB_in;
		variable i, j, k	: integer 		:= 0;
	begin
		--recycle the dispatched instruction's tag
		j := LAB_temp(0).tag;
		
		for i in 0 to LAB_MAX - 2 loop
			LAB_temp(i)	:= LAB_temp(i + 1);
		end loop; --for i
		
		--place previous tag back into LAB
		LAB_temp(LAB_MAX - 1).tag := j;
		
		return LAB_temp;
	end function;
	
	--function to check if LAB tag exists in MOAB
	function check_MOAB_for_tag ( 	MOAB_in	: in MOAB_actual;
												tag_in	: in integer		)
		return std_logic is
		
		variable i				: integer		:= 0;
		begin
			for i in 0 to LAB_MAX - 1 loop
			if (MOAB_in(i).tag = tag_in and MOAB_in(i).valid = '1') then
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
			for i in 0 to LAB_MAX - 2 loop
			if (MOAB_temp(i).valid = '0') then
				for j in (i + 1) to LAB_MAX - 1 loop
					--if (MOAB_temp(j).valid = '1') then
						MOAB_temp(i).data 	:= MOAB_temp(j).data;
						--SWAP TAGS
						k							:= MOAB_temp(i).tag;
						MOAB_temp(i).tag 		:= MOAB_temp(j).tag;
						MOAB_temp(j).tag		:= k;
						--END SWAP TAGS
						MOAB_temp(i).valid 	:= '1';
						MOAB_temp(j).valid 	:= '0'; --invalidate so next loop can use it
						exit; --exit if next instruction
					--end if; --not sure why I'd make this dependent on whether next entry was valid or not. 
				end loop; --for j
			end if;
		end loop; --for i

		return MOAB_temp;
	end function;
	
	--when we dispatch an instruction from the LAB, buffer that instruction into LAB2 to keep
	--track of registers in pipeline
	function load_LAB2(	 	LAB2_in	: in LAB_actual;
									inst_in	: in std_logic_vector(15 downto 0);
									tag_in	: in integer									) 
		return LAB_actual is
								
		variable LAB2_temp 	: LAB_actual 	:= LAB2_in;

	begin
		for i in LAB_MAX - 1 downto 0 loop
			if (LAB2_temp(i).valid = '0') then
				LAB2_temp(i).inst 	:= inst_in;
				LAB2_temp(i).tag 		:= tag_in;
				LAB2_temp(i).valid 	:= '1';
				exit;
			end if;
		end loop; --for i

		return LAB2_temp;
	end function;
	
	--function to detect RAW, WAR, and WAW hazards
	impure function data_haz_check(	LAB_in	: in LAB_actual	)
		return LAB_actual is
		
		variable LAB_temp				: LAB_actual  	:= LAB_in;
		variable i, j, k, tag_temp	: integer		:= 0;
		variable LAB_entry_temp		: LAB_entry;
		variable RAW_WAW				: std_logic		:= '0';
		
	begin
		--TODO: how to check for branches and jumps?
--		if EX_tag = LAB_temp(0).inst(11 downto 7) then
--
--			--SWAP LAB ENTRIES
--			LAB_entry_temp		:= LAB_temp(0);
--			LAB_temp(0) 		:= LAB_temp(2);
--			LAB_temp(2)			:= LAB_entry_temp;
--				
--		end if;
--		
--		if ID_tag = LAB_temp(0).inst(11 downto 7) then
--			--SWAP LAB ENTRIES
--			LAB_entry_temp	:= LAB_temp(0);
--			LAB_temp(0) 	:= LAB_temp(2);
--			LAB_temp(2)		:= LAB_entry_temp;
--				
--		end if;
--		
--		if ID_tag = LAB_temp(1).inst(11 downto 7) then
--			--SWAP LAB ENTRIES
--			LAB_entry_temp	:= LAB_temp(1);
--			LAB_temp(1) 	:= LAB_temp(3);
--			LAB_temp(3)		:= LAB_entry_temp;
--				
--		end if;

		for i in 1 to (LAB_MAX - 2) loop
			if (LAB_temp(0).inst(11 downto 7) 	= LAB_temp(i).inst(11 downto 7) or	--WAW
				LAB_temp(0).inst(11 downto 7) 	= LAB_temp(i).inst(6 downto 2)) and	--RAW
				LAB_temp(i).valid = '1' 	and 						--verify that i + 1 is valid, otherwise we don't care
				LAB_temp(i).inst(15 downto 12) 	/= "1010" and 	--if it's a BNEZ, we don't care about RAW/WAW
				LAB_temp(i).inst(15 downto 12) 	/= "1011" and 	--if it's a BNE, we don't care about RAW/WAW
				LAB_temp(i).inst(15 downto 12) 	/= "1100" then	--if it's a JMP, we don't care about RAW/WAW				
			
				RAW_WAW := '1';
				
			elsif RAW_WAW = '1' then 
			
				tag_temp := i;
				
				--FIRST: starting at first LAB spot, if ith inst source OR destination DO match ith inst destination, we don't care, exit.
				--lower limit is 1 because we already know the instruction at i doesn't match 0th inst destination
				for j in 1 to i - 1 loop
					if LAB_temp(i).inst(11 downto 7) = LAB_temp(j).inst(11 downto 7) or 
						LAB_temp(i).inst(11 downto 7) = LAB_temp(j).inst(6 downto 2) then
						exit;
					else 
						tag_temp := 1;
					end if;
				end loop;
				
				--SECOND: if we can swap ith inst with 1st slot, then do it
				--place i at tag_temp and shift entire LAB up at this point
				if tag_temp = 1 then
				
					LAB_entry_temp := LAB_temp(i);
					
					for j in i downto 2 loop
						LAB_temp(i) := LAB_temp(i - 1);
					end loop;
					
					LAB_temp(1) := LAB_entry_temp;
					
				end if;
			else
				--if WAW or RAW are detected or j is invalid, do nothing this iteration, go to j + 1		
			end if;
		end loop; --i loop
		
	return LAB_temp;
	end function;
	
begin
	--added stall_pipeline to sensitivity list, may cause unintended consequences
	process(reset_n, sys_clock, stall_pipeline)
		variable i	: integer := 0;
		begin
		
		if(reset_n = '0') then
			LAB 			<= init_LAB(LAB);
			LAB2			<= init_LAB(LAB2);
			MOAB 			<= init_MOAB(MOAB);
			PC_reg 		<= "00000000000";
			PC_reg_prev <= "11111111111";
			
		elsif rising_edge(sys_clock) then
		
			--first just check whether this is an auxiliary value (e.g., memory address)
			if next_IW_to_MOAB = '1' then
			
				for i in 0 to LAB_MAX - 1 loop
					--since there can only be LAB_MAX instructions in LAB, there can only be LAB_MAX spots in MOAB.
					--just find a spot that's empty and give it the tag of the associated LAB instruction.
					if MOAB(i).valid = '0' then
						MOAB(i).data 	<= PM_data_in;
						if stall_pipeline = '1' then
							MOAB(i).tag <= LAB(last_LAB_spot - 1).tag;
						else
							MOAB(i).tag <= LAB(last_LAB_spot).tag;
						end if;
						MOAB(i).valid	<= '1';
						exit; --don't need to fill up any more MOAB spots now
					end if;
				end loop;
				
				next_IW_to_MOAB <= '0';
				--increment PC to get next IW
				PC_reg 		<= std_logic_vector(unsigned(PC_reg) + 1);
			end if; --next_IW_to_MOAB
			
			--next, if an instruction needs to be committed, do that. this frees up a LAB2 spot.
			if tag_to_commit_reg < 5 AND tag_to_commit_reg >= 0 then
				report "Committing value from LAB2, tag = " & Integer'image(tag_to_commit_reg);
				LAB2 	<= commit_IW(LAB2, tag_to_commit_reg);
				MOAB 	<= commit_addr(MOAB, tag_to_commit_reg);
				--TODO: why doesn't this modification work in simulation? 
			end if; --tag_to_commit_reg
			
			--next, if pipeline isn't stalled, just dispatch zeroth instruction
			if stall_pipeline = '0' then 
			
				--dispatch first (zeroth) instruction in LAB, if it exists
				if ( LAB(0).valid = '1' ) then
				
					--if there is a memory address included, dispatch it too.
					--the following condition is based on memory ops requiring an address:
					if LAB(0).inst(15) = '1' and LAB(0).inst(1) = '1' then
					
						--check if MOAB has corresponding memory address
						if check_MOAB_for_tag(MOAB, LAB(0).tag) = '1' then
							--dispatch memory address and shift 
							MEM_reg <= MOAB(0).data;	
							MOAB(0).valid 	<= '0';
							--shift entire MOAB down now
							MOAB 	<= shift_MOAB(MOAB);
							
							--place the soon-to-be-dispatched instruction in LAB2
							LAB2 	<= load_LAB2(LAB2, LAB(0).inst, LAB(0).tag);
							
							--now dispatch
							report "Dispatching instruction, memory related instruction.";
							IW_reg <= LAB(0).inst;
							LAB 	<= shift_LAB(LAB);

						else
							report "Memory address not yet buffered";
						end if;
					else --its any other instruction, just dispatch anyway
						LAB2 	<= load_LAB2(LAB2, LAB(0).inst, LAB(0).tag);
						
						--dispatch first instruction
						report "Dispatching instruction, non-memory related instruction.";
						IW_reg <= LAB(0).inst;
						LAB 	<= shift_LAB(LAB);
					end if;
				else
					--TODO do we need to output something LAB(0) is invalid?
				end if;
			else
					--TODO do we need to output something if the pipeline is stalled?
			end if; --stall_pipeline
			
			PC_reg_prev <= PC_reg;
			
			--now try to buffer next instruction from PM
			if( last_LAB_spot < LAB_MAX ) then 
				--there is a spot in the LAB for it, go load IW into LAB
				
				if next_IW_to_MOAB = '0' then
					LAB(last_LAB_spot).inst 	<= PM_data_in;
					LAB(last_LAB_spot).valid 	<= '1';
					
					--now try to reorganize now that the LAB has been dispatched and/or filled
					--TODO: test this function 
					LAB <= data_haz_check(LAB);
				else
					
				end if;
				--increment PC to get next IW
				PC_reg 		<= std_logic_vector(unsigned(PC_reg) + 1);

				--now check for whether or not there's another IW coming after this one that needs to go into MOAB
				if (next_IW_to_MOAB = '0' and PM_data_in(15) = '1' and PM_data_in(1) = '1') then --condition based on LD, ST, BNEZ, BNE, and JMP
					next_IW_to_MOAB <= '1';
				end if; --PM_data_in
				
				--since we're here, reset the LAB_full signal
				LAB_full <= '0';
			else
				--there is no spot in LAB, no need to modify PC_reg
				LAB_full <= '1';
			
			end if; --find_LAB_spot
		end if; --reset_n
	end process;
	
	process (LAB, stall_pipeline)
	begin

		last_LAB_spot <= find_LAB_spot(LAB);

	end process;
	
		--latch inputs
		tag_to_commit_reg <= tag_to_commit;

		--latch outputs
		PC 	<= PC_reg;
		IW 	<= IW_reg;
		MEM 	<= MEM_reg;
end architecture arch;