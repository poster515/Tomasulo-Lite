-- Written by Joe Post

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.LAB_functions.all;
------------------------------------------------------------
entity LAB is
		generic ( 	LAB_MAX	: integer	:= 5	);
	port (

		reset_n, sys_clock  	: in std_logic;
		stall_pipeline			: in std_logic; --needed when waiting for certain commands, should be formulated in top level CU module
		ID_dest_reg				: in std_logic_vector(4 downto 0); --source registers for instruction in ID stage (results available)
		EX_dest_reg				: in std_logic_vector(4 downto 0); --source registers for instruction in EX stage (results available)
		MEM_dest_reg			: in std_logic_vector(4 downto 0); --source registers for instruction in MEM stage (results available)
		ID_reset, EX_reset, MEM_reset	: in std_logic;
		PM_data_in				: in std_logic_vector(15 downto 0);
		RF_out_3, RF_out_4		: in std_logic_vector(15 downto 0);
		ROB_in					: in ROB;
		ALU_SR_in				: in std_logic_vector(3 downto 0);
		
		PC						: out std_logic_vector(10 downto 0);
		IW						: out std_logic_vector(15 downto 0);
		MEM						: out std_logic_vector(15 downto 0); --MEM is the IW representing the next IW as part of LD, ST, JMP, BNE(Z) operations
		LAB_reset_out			: out std_logic; --reset signal for ID stage
		LAB_stall				: out std_logic;
		condition_met			: out std_logic;	--signal to WB for ROB. as soon as "results_available" goes high, need to evaluate all instructions after first branch
		results_available		: out std_logic		--signal to WB for ROB. as soon as it goes high, need to evaluate all instructions after first branch
	);
end entity LAB;

--need to finalize branch instruction capability
--thinking that the LAB will need to tell WB stage ROB that subsequent instructions are being executed speculatively, if they are.
--this can be a new flag in the ROB, and only commit results to RF if the results are no longer speculative

--for LAB, need to mark all subsequent instructions fetched from PM as speculative (to WB stage)
--if PM_data_hazard is '0' though, should be able to retrieve them immediately and adjust program counter as needed
--this may involve including a third output mux from the RF directly to the LAB stage.

--otherwise, branch instruction will sit in LAB, eventually get issued, and get executed
--when the ALU_SR input to LAB is read, the program counter can be updated accordingly, and instructions in WB can
--be de-marked as 'speculative'
--this appears to be the least-invasive solution. 

--as part of construction, can also evaluate two remaining instructions: branch if not less than (BNLT) and branch if not greater than (BNGT)
--these instructions would involve subtraction (which means re-evaluation of control signal construction) and looking simply at the ALU_SR. 

------------------------------------------------------------
--since "1111" is an unused OpCode, use the instruction word "1111111111111111" as an EOP signal
architecture arch of LAB is
	--initialize addr_valid as '1' for all instructions except load/stores, branches, etc., so that when the
	--subsequent IW is issued on PM_data_in, we search for the only non-'1' addr_valid slot and establish the 
	--memory address there
	signal LAB	: LAB_actual := (others => ((others => '0'), '0', (others => '0'), '1'));	

	--array with addresses for all branch instructions
	signal branches	: branch_addrs := (others => ((others => '0'), (others => '0'), '0'));
	
	--Program counter (PC) register
	signal PC_reg		: std_logic_vector(10 downto 0);
	
	--signal to denote that LAB is full and we need to stall PM input clock
	signal LAB_full	: std_logic := '0';

	--signal to denote that the next IW is actually a memory or auxiliary value, and should go to MOAB
	signal next_IW_to_MOAB : std_logic := '0';
	
	--registers for various outputs (IW register, and memory address register)
	signal MEM_reg		: std_logic_vector(15 downto 0)	:= "0000000000000000";
	signal IW_reg		: std_logic_vector(15 downto 0) 	:= "0000000000000000";
	
	--std_logic_vector tracking if there are any data hazards in any LAB instruction and below
	signal datahaz_status 	: std_logic_vector(LAB_MAX - 1 downto 0) := (others => '0');
	
	--std_logic tracking if there are any data hazards between PM_data_in and pipeline and LAB instructions
	signal PM_datahaz_status : std_logic;
	
	--unclocked and clocked signals which tells if the incoming instruction is a jump instruction
	signal jump				: std_logic := '0';
	signal jump_reg			: std_logic := '0';
	
	--unclocked and clocked signal which tells if the incoming instruction is a load or store instruction
	signal ld_st			: std_logic := '0';
	signal ld_st_reg		: std_logic := '0';
	
	--unclocked and clocked signal which tells if the incoming instruction is a branch instruction
	signal branch			: std_logic := '0';
	signal branch_reg		: std_logic := '0'; --this will be '1' so long as there is a branch instruction in ROB
	
	--signals to represent the applicable branch selection, whether the condition was met or not, and whether the result of a branch is available
	signal bne, bnez		: std_logic;
	
	--signals for intra-ROB branch status determination, set in "ROB_branch" process
	signal branch_exists, is_unresolved, bne_from_ROB, bnez_from_ROB	: std_logic;
	
	--TODO: figure out what to do with I2C_error signal from MEM block, which goes high when there are three mistries to 
		--read/write from I2C slave
		
begin

	main	: process(reset_n, sys_clock, LAB, stall_pipeline)
		variable i	: integer range 0 to LAB_MAX - 1;
		begin
		
		if(reset_n = '0') then
			
			next_IW_to_MOAB 	<= '0';
			LAB 				<= init_LAB(LAB, LAB_MAX);
			branches			<= init_branches(branches, LAB_MAX);
			IW_reg 				<= "1111111111111111";
			LAB_reset_out 		<= '0';
			
		elsif rising_edge(sys_clock) then
		
			--jumps are easily handled with "program_counter" process below 
			--branches are constantly being evaluated with the state machine "branch_state" below
			--ALU instructions are managed and re-ordered strictly between branches in ROB

			--continually check for branch condition on PM_data_in
			if branch = '1' then
				--do initial check to see if results are available
				results_available 	<= results_ready(bne, bnez, RF_in_3_valid, RF_in_4_valid, ROB_in)(0); --'0' = not available, '1' = available
				condition_met 		<= results_ready(bne, bnez, RF_in_3_valid, RF_in_4_valid, ROB_in)(1); --'0' = not met, '1' = met

			--this "elsif" handles other branches that currently exist in the ROB that have not been resolved yet. should continually monitor those, as determined by "ROB_branch" process below. 
			--need this additional if case because the data sent to "results_result" differ from the above if case. 
			elsif branch_exists = '1' and is_unresolved = '1' then	

				results_available 	<= results_ready(bne_from_ROB, bnez_from_ROB, RF_in_3_valid, RF_in_4_valid, ROB_in)(0); --'0' = not available, '1' = available
				condition_met 		<= results_ready(bne_from_ROB, bnez_from_ROB, RF_in_3_valid, RF_in_4_valid, ROB_in)(1); --'0' = not met, '1' = met

			end if;
			
			--if statements to record branch addresses (only if branch condition is unresolved still)
			if branch_reg = '1' and results_available = '0' then
				--this function will store the current PM_data_in, being the branch address, and shift the array down if a previous branch condition is resolved
				branches <= store_shift_branch_addr(branches, results_available, '1', PM_data_in, PC_reg); --'1' is a bit stating that the next two bytes are valid data (PM_data_in)
			else
				--this function will just shift "branches" appropriately if a previous branch condition is resolved or the incoming branch is resolved
				branches <= store_shift_branch_addr(branches, results_available, '0', "0000000000000000", "00000000000");
			end if;

			--if pipeline isn't stalled, just dispatch instruction
			if stall_pipeline = '0' then 
			
				--this first "if" handles the processor startup until we have a data hazard with incoming PM_data_in
				if LAB(0).inst_valid = '0' then
				
--				if PM_data_in matches any pipeline stage instruction (and the associated reset_n is high), then issue next
--				valid, non-conflicting instruction or if none available, just buffer PM_data_in in LAB and issue a no-op command
--				(i.e., "1111111111111111")
	
					--if there's a conflict and its not a jump and its not a memory address
					if PM_datahaz_status = '1' then 
						
						--have data conflict with ID, EX, or MEM stage 
						--buffer into LAB(0)
						LAB(0).inst 		<= PM_data_in;
						LAB(0).inst_valid 	<= '1';
						LAB(0).addr_valid 	<= not(branch or ld_st);
						IW_reg 				<= "1111111111111111"; --issue no-op
					
					else
						--just issue PM_data_in
						IW_reg <= PM_data_in;
					end if;
				
				else
					--have at least one valid instruction waiting in LAB
					--use loop to check for hazards against stages of the pipeline
					for i in 0 to LAB_MAX - 1 loop
						
						if (((ID_dest_reg /= LAB(i).inst(11 downto 7)) and (ID_dest_reg /= LAB(i).inst(6 downto 2))) and ID_reset = '1') and 
							(((EX_dest_reg /= LAB(i).inst(11 downto 7)) and (EX_dest_reg /= LAB(i).inst(6 downto 2))) and EX_reset = '1') and
							(((MEM_dest_reg /= LAB(i).inst(11 downto 7)) and (MEM_dest_reg /= LAB(i).inst(6 downto 2))) and MEM_reset = '1') and
							(LAB(i).inst_valid = '1') then --we don't have any conflict in pipeline and LAB instruction is valid
							
							--check if there are any hazards within the LAB for the ith entry (for memory instructions)
							if datahaz_status(i) = '0' and LAB(i).inst(15 downto 12) = "1000" and LAB(i).addr_valid = '1' then
							
								report "Issuing memory instruction.";
								--if so, we can issue the ith instruction
								IW_reg 		<= LAB(i).inst;
								MEM_reg 	<= LAB(i).addr;
								
								--shift LAB down and buffer PM_data_in
								LAB 		<= shiftLAB_and_bufferPM(LAB, PM_data_in, i, LAB_MAX, '1');
								
								--exit, we're done here
								exit;
							
							--check if there are any hazards within the LAB now for the ith entry (for non-memory instructions)
							elsif datahaz_status(i) = '0' and LAB(i).inst(15 downto 12) /= "1000" then
								
								report "Issuing non-memory instruction.";
								--if not, we can issue the ith instruction
								IW_reg 	<= LAB(i).inst;
								
								--shift LAB down and buffer PM_data_in
								LAB 	<= shiftLAB_and_bufferPM(LAB, PM_data_in, i, LAB_MAX, '1');
								
								--exit here, we're done
								exit;
								
							else
								--can't do anything if there's a data hazard for this LAB instruction, keep moving on, buffer PM but DON'T SHIFT LAB
								--just issue no-op by default
								LAB 		<= shiftLAB_and_bufferPM(LAB, PM_data_in, i, LAB_MAX, '0');
								IW_reg 		<= "1111111111111111";
								MEM_reg 	<= "0000000000000000";
							end if; --datahaz_status
							
						elsif i = LAB_MAX - 1 and datahaz_status(i) = '1' then --LAB is full and the last instruction has a conflict
						
							if PM_datahaz_status = '0' then
								IW_reg 		<= PM_data_in;
								LAB_full 	<= '0';
							else --can't do anything, keep PC where it is
								LAB_full 	<= '1';
								IW_reg 		<= "1111111111111111";
								MEM_reg 	<= "0000000000000000";
							end if;
						else
							--default to just issuing a no-op
							IW_reg 		<= "1111111111111111";
							MEM_reg 	<= "0000000000000000";

						end if; --various tags
					end loop; --for i
				
				end if; --LAB(0).valid = '0' 
				
			else
				--if stalled, just issue noop
				IW_reg <= "1111111111111111";
				
			end if; --stall_pipeline
					
		end if; --reset_n
	end process;
	
	--this process controls the program counter only
	program_counter	: process(reset_n, LAB_full, sys_clock, LAB_stall)
	begin
	
		if reset_n = '0' then
		
			PC_reg 	<= "00000000000";
			
		elsif LAB_full = '1' or stall_pipeline = '1' then --we have a stall condition and need to keep PC where it is
			PC_reg <= PC_reg;
			
		else
			if rising_edge(sys_clock) then
				
				if LAB_stall = '1' then
					--if we're stalled, keep PC where its at
					PC_reg 	<= PC_reg;
					
				elsif jump_reg = '1' then
					--for jumps, grab immediate value and update PC_reg
					PC_reg 	<= std_logic_vector(unsigned(PM_data_in(11 downto 1)));
					
				elsif branch_reg = '1' and results_available = '0' then
					--speculatively execute the next instruction. the "main" process will handle the rest. 
					PC_reg 	<= std_logic_vector(unsigned(PC_reg) + 1);
					
				elsif branch_reg = '1' and results_available = '1' and condition_met = '1' then
					--results are available and we can non-speculatively execute the branched instructions. the "main" process will handle the rest. 
					PC_reg 	<= std_logic_vector(unsigned(PM_data_in(11 downto 1)));
					
				elsif branch_reg = '1' and results_available = '1' and condition_met = '0' then
					--results are available and we can non-speculatively execute the next instructions. the "main" process will handle the rest. 
					PC_reg 	<= std_logic_vector(unsigned(PC_reg) + 1);
					
				elsif branch_reg = '0' and results_available = '1' and condition_met = '1' then
					--results are available and we can non-speculatively execute the branched instructions. the "main" process will handle the rest. 
					PC_reg 	<= branches(0).addr_met(10 downto 0);
					
				elsif branch_reg = '0' and results_available = '1' and condition_met = '0' then
					--results are available and we can non-speculatively execute the next instructions. the "main" process will handle the rest. 
					PC_reg 	<= std_logic_vector(unsigned(branches(0).addr_unmet(10 downto 0)) + 1);
					
				else 
					--otherwise increment PC to get next IW
					PC_reg 	<= std_logic_vector(unsigned(PC_reg) + 1);
					
				end if;
			end if; --sys_clock
		end if; --reset_n
	end process; --program_counter
	
	--process to determine whether an unresolved branch instruction exists in the ROB, this is used to then confirm if the results are ready
	ROB_branch	: process (reset_n, ROB_in) 
	begin
		if reset_n = '0' then
			branch_exists 	<= '0';
			is_unresolved 	<= '0';
			bne_from_ROB 	<= '0';
			bnez_from_ROB 	<= '0';
		else
			for i in 0 to 9 loop
				--find the first unresolved branch in the ROB, grab some info, and then exit 
				if ROB_in(i).inst = "1010" and ROB_in(i).specul = '0' then
				
					branch_exists 	<= '1';
					is_unresolved 	<= '0';
					-- bne_from_ROB 	<= not(ROB_in(i).inst(1)) and ROB_in(i).inst(0);
					-- bnez_from_ROB 	<= not(ROB_in(i).inst(1)) and not(ROB_in(i).inst(0));
					exit;
				elsif ROB_in(i).inst = "1010" and ROB_in(i).specul = '1' then
				
					branch_exists 	<= '1';
					is_unresolved 	<= '1';
					bne_from_ROB 	<= not(ROB_in(i).inst(1)) and ROB_in(i).inst(0);
					bnez_from_ROB 	<= not(ROB_in(i).inst(1)) and not(ROB_in(i).inst(0));
					exit;
				else 
					branch_exists 	<= '0';
					is_unresolved 	<= '0';
					bne_from_ROB 	<= '0';
					bnez_from_ROB 	<= '0';
				end if; 
				
			end loop; --i 
		end if; --reset_n
	end process;
	
	--process to generate combinational logic for input instructions
	process(reset_n, PM_data_in, jump_reg) 
	begin
		--sets branch_ld_st if the new PM_data_in is a jump or branch instruction
		if reset_n = '0' then
			ld_st 		<= '0';
			branch 		<= '0';
			jump		<= '0';
		elsif reset_n = '1' then
			if (PM_data_in(15 downto 12) = "1001") and jump_reg = '0' then
				jump	<= '1';
			elsif (PM_data_in(15 downto 12) = "1010") and branch_reg = '0' then
				--TODO: can we just look at the ROB contents every clock to constantly try and resolve any speculative branches in the ROB? not just when PM_data_in is a branch?
				branch 	<= '1';
				
				RF_out_3_mux 	<= PM_data_in(11 downto 7);
				RF_out_4_mux 	<= PM_data_in(6 downto 2);
				RF_out_3_en		<= '1';
				RF_out_4_en		<= '1';
				bne				<= not(PM_data_in(1)) and not(PM_data_in(0));
				bnez			<= not(PM_data_in(1)) and PM_data_in(0);
				
			elsif (PM_data_in(15 downto 12) = "1000") and ld_st_reg = '0' then
				ld_st 	<= '1'; --have a memory operation

			else
				branch	<= '0';
				ld_st 	<= '0';
				jump	<= '0';
			end if;
		end if; --reset_n
						
	end process;
	
	--process to generate clocked registers for input instructions
	process(reset_n, sys_clock, PM_data_in) 
	begin
		--sets branch_ld_st if the new PM_data_in is a jump or branch instruction
		if reset_n = '0' then
			ld_st_reg 		<= '0';
			branch_reg 		<= '0';
			jump_reg		<= '0';
		elsif rising_edge(sys_clock) then
			if jump = '1' and jump_reg = '0' then
				jump_reg	<= '1';
				
			elsif branch = '1' and branch_reg = '0' then
				branch_reg 	<= '1';
				
			elsif ld_st = '1' and ld_st_reg = '0' then
				ld_st_reg 	<= '1'; --
				
			else
				ld_st_reg 		<= '0';
				branch_reg 		<= '0';
				jump_reg		<= '0';
			end if;
		end if; --reset_n
						
	end process;
	
	
	--this process determines whether the PM_data_in poses a data hazard from any instruction below it or in pipeline
	PM_data_hazard_status	: process(reset_n, PM_data_in, ID_dest_reg, EX_dest_reg, MEM_dest_reg, LAB)
		variable dh_ptr_outer 	: integer range 0 to LAB_MAX - 1;
		--variable last_dh			: integer range 0 to LAB_MAX - 1 + 3; --adding three to account for pipeline instructions
	begin	
		if reset_n = '0' then
		
			PM_datahaz_status <= '0';
			--last_dh <= 0;
		else
	
			if ((ID_dest_reg /= PM_data_in(11 downto 7)) and (ID_dest_reg /= PM_data_in(6 downto 2))) and 
				((EX_dest_reg /= PM_data_in(11 downto 7)) and (EX_dest_reg /= PM_data_in(6 downto 2))) and
				((MEM_dest_reg /= PM_data_in(11 downto 7)) and (MEM_dest_reg /= PM_data_in(6 downto 2))) then
				
				PM_datahaz_status <= '0';
				
			else
				PM_datahaz_status <= '1';
				
			end if;	
			
			--start this loop at 0 because we want to check PM_data_in against entire LAB
			for dh_ptr_outer in 0 to LAB_MAX - 1 loop
			
				if ((LAB(dh_ptr_outer).inst(11 downto 7) = PM_data_in(11 downto 7)) and LAB(dh_ptr_outer).inst_valid  = '1') or 
					((LAB(dh_ptr_outer).inst(11 downto 7) = PM_data_in(6 downto 2)) and LAB(dh_ptr_outer).inst_valid  = '1') then
					
					--just say that we have a hazard and exit for now
					--TODO: can this be optimized to only search the LAB based on the proximity to a known hazard in the pipeline?
					PM_datahaz_status <= '1';
					exit;
					
				end if;
				
			end loop; --dh_ptr_outer 
			
		end if; --reset_n
	end process;
	
	--this process updates the dh_ptr_outer std_logic_vector to represent whether the ith instruction 
	--poses a data hazard from any instruction below it
	data_hazard_status_update	: process(reset_n, LAB)
		variable dh_ptr_outer, dh_ptr_inner : integer range 0 to LAB_MAX - 1;
	begin	
		if reset_n = '0' then
		
			datahaz_status <= (others => '0');
			
		else 
		
			for dh_ptr_outer in 1 to LAB_MAX - 1 loop
			
				for dh_ptr_inner in 0 to dh_ptr_outer - 1 loop
			
					if (LAB(dh_ptr_inner).inst(11 downto 7) /= LAB(dh_ptr_outer).inst(11 downto 7)) and 
						(LAB(dh_ptr_inner).inst(11 downto 7) /= LAB(dh_ptr_outer).inst(6 downto 2)) then
						
						datahaz_status(dh_ptr_outer) <= '0';
						
					else
					
						datahaz_status(dh_ptr_outer) <= '1';
						
					end if;
				end loop; --dh_ptr_inner 
			end loop; --dh_ptr_outer 
			
		end if; --reset_n
		
	end process;

		--latch outputs
		PC 	<= PC_reg;
		IW 	<= IW_reg;
		MEM 	<= MEM_reg;
		LAB_stall <= LAB_full;
		
end architecture arch;