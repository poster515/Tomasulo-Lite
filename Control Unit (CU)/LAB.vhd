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
		ALU_SR_in				: in std_logic_vector(3 downto 0);
		
		PC							: out std_logic_vector(10 downto 0);
		IW							: out std_logic_vector(15 downto 0);
		MEM						: out std_logic_vector(15 downto 0); --MEM is the IW representing the next IW as part of LD, ST, JMP, BNE(Z) operations
		LAB_reset_out			: out std_logic; --reset signal for ID stage
		LAB_stall				: out std_logic
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

	--Program counter (PC) register
	signal PC_reg		: std_logic_vector(10 downto 0);
	
	--signal to denote that LAB is full and we need to stall PM input clock
	signal LAB_full	: std_logic := '0';

	--signal to denote that the next IW is actually a memory or auxiliary value, and should go to MOAB
	signal next_IW_to_MOAB : std_logic := '0';
	
	--signal for last open LAB spot found
	signal tag_to_commit_reg	: integer;
	
	--registers for various outputs (IW register, and memory address register)
	signal MEM_reg		: std_logic_vector(15 downto 0)	:= "0000000000000000";
	signal IW_reg		: std_logic_vector(15 downto 0) 	:= "0000000000000000";
	
	--signal that load_hazcheck uses to determine if the LAB needs to be shifted due to an IW being dispatched
	signal IW_dispatched : std_logic := '0';
	
	--std_logic_vector tracking if there are any data hazards in any LAB instruction and below
	signal datahaz_status 	: std_logic_vector(LAB_MAX - 1 downto 0) := (others => '0');
	
	--std_logic tracking if there are any data hazards between PM_data_in and pipeline and LAB instructions
	signal PM_datahaz_status : std_logic;
	
	--unclocked and clocked signals which tells if the incoming instruction is a jump or branch instruction
	signal jump				: std_logic := '0';
	signal jump_reg		: std_logic := '0';
	
	--unclocked signal which tells if the incoming instruction is a load or store instruction
	signal ld_st			: std_logic := '0';
	
	--unclocked signal which tells if the incoming instruction is a jump or branch instruction
	signal branch			: std_logic := '0';
	
	--signal tracking whether subsequent instructions are speculative or not
	signal spec_op	: std_logic;
	
	--TODO: figure out what to do with I2C_error signal from MEM block, which goes high when there are three mistries to 
		--read/write from I2C slave

begin

	process(reset_n, sys_clock, LAB, stall_pipeline)
		variable i	: integer range 0 to LAB_MAX - 1;
		begin
		
		if(reset_n = '0') then
			
			next_IW_to_MOAB <= '0';
			LAB <= init_LAB(LAB, LAB_MAX);
			IW_reg <= "1111111111111111";
			LAB_reset_out <= '0';
			
		elsif rising_edge(sys_clock) then
		
			if jump = '1' then
				jump_reg = '1';
			else
				jump_reg = '0';
			end if;
		
			LAB_reset_out <= '1';
			
			--first just check whether this is an auxiliary value (e.g., memory address)
			if next_IW_to_MOAB = '1' then
	
				for i in 0 to LAB_MAX - 1 loop

					if LAB(i).inst_valid = '1' and LAB(i).addr_valid <= '0' then
					
						LAB(i).addr 		<= PM_data_in;
						LAB(i).addr_valid	<= '1';
						exit; --
						
					end if;
				end loop;
				
				next_IW_to_MOAB <= '0';

			end if; --next_IW_to_MOAB

			--next, if pipeline isn't stalled, just dispatch instruction
			if stall_pipeline = '0' then 
			
				--first check for whether or not there's another IW coming after this one that needs to go into MOAB
				--condition based on LD, ST, BNEZ, BNE, and JMP
				if (next_IW_to_MOAB = '0' and branch_ld_st = '1') then 
					next_IW_to_MOAB <= '1';
				else
					next_IW_to_MOAB <= '0';
				end if; --
			
				--this first "if" handles the processor startup until we have a data hazard with incoming PM_data_in
				if LAB(0).inst_valid = '0' then
				
	--				if PM_data_in matches any pipeline stage instruction (and the associated reset_n is high), then issue next
	--				valid, non-conflicting instruction or if none available, just buffer PM_data_in in LAB and issue a no-op command
	--				(i.e., "1111111111111111")
	
					--if there's a conflict and its not a jump and its not a memory address
					if (PM_datahaz_status = '1') and (jump = '0') and (next_IW_to_MOAB = '0') then 
						
						--have data conflict with ID, EX, or MEM stage 
						--buffer into LAB(0)
						LAB(0).inst 			<= PM_data_in;
						LAB(0).inst_valid 	<= '1';
						LAB(0).addr_valid 	<= not(branch or ld_st);
						IW_reg 					<= "1111111111111111"; --issue no-op
					
					else
						--no data hazards, just issue PM_data_in, if it's not a memory instruction
						if (branch = '1') then
							IW_reg 	<= "1111111111111111"; --issue no-op
							spec_op	<= '1';		--denote that all following instructions are speculative
						else
							--this will speculatively execute contiguous instructions in PM
							IW_reg <= PM_data_in;
						end if;
					end if;
				
				else
					--have at least one valid instruction waiting in LAB
					--use loop to check for hazards against stages of the pipeline
					for i in 0 to LAB_MAX - 1 loop
						
						if (((ID_dest_reg /= LAB(i).inst(11 downto 7)) and (ID_dest_reg /= LAB(i).inst(6 downto 2))) and ID_reset = '1') and 
							(((EX_dest_reg /= LAB(i).inst(11 downto 7)) and (EX_dest_reg /= LAB(i).inst(6 downto 2))) and EX_reset = '1') and
							(((MEM_dest_reg /= LAB(i).inst(11 downto 7)) and (MEM_dest_reg /= LAB(i).inst(6 downto 2))) and MEM_reset = '1') and
							(LAB(i).inst_valid = '1') then --we don't have any conflict in pipeline
							
							--check if there are any hazards within the LAB for the ith entry (for memory instructions)
							if datahaz_status(i) = '0' and 
								(LAB(i).inst(15 downto 12) = "1000" or LAB(i).inst(15 downto 12) = "1001" or LAB(i).inst(15 downto 12) = "1010") and
								LAB(i).addr_valid = '1' then
							
								report "Issuing memory instruction.";
								--if so, we can issue the ith instruction
								IW_reg 	<= LAB(i).inst;
								MEM_reg 	<= LAB(i).addr;
								
								--shift LAB down and buffer PM_data_in
								LAB 		<= shiftLAB_and_bufferPM(LAB, PM_data_in, i, LAB_MAX);
								
								--exit, we're done here
								exit;
							
							--check if there are any hazards within the LAB now for the ith entry (for non-memory instructions)
							elsif datahaz_status(i) = '0' and LAB(i).inst(15 downto 12) /= "1000" and 
									LAB(i).inst(15 downto 12) /= "1001" and LAB(i).inst(15 downto 12) /= "1010" then
								
								report "Issuing non-memory instruction.";
								--if not, we can issue the ith instruction
								IW_reg <= LAB(i).inst;
								
								--shift LAB down and buffer PM_data_in
								LAB <= shiftLAB_and_bufferPM(LAB, PM_data_in, i, LAB_MAX);
								
								--exit here, we're done
								exit;
								
							else
								--can't do anything if there's a data hazard for this LAB instruction, keep moving on
								--just issue no-op by default
								IW_reg 	<= "1111111111111111";
								MEM_reg 	<= "0000000000000000";
							end if; --datahaz_status
							
						elsif i = LAB_MAX - 1 and datahaz_status(i) = '1' then --LAB is full and the last instruction has a conflict
						
							if PM_datahaz_status = '0' then
								IW_reg 	<= PM_data_in;
								LAB_full <= '0';
							else --can't do anything, keep PC where it is
								LAB_full <= '1';
								IW_reg 	<= "1111111111111111";
								MEM_reg 	<= "0000000000000000";
							end if;
						else
							--default to just issuing a no-op
							IW_reg 	<= "1111111111111111";
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
	
	process(reset_n, PM_data_in, jump_reg) 
	begin
		--sets branch_ld_st if the new PM_data_in is a jump or branch instruction
		if reset_n = '0' then
			ld_st 		<= '0';
			branch 		<= '0';
			jump			<= '0';
		elsif reset_n = '1' then
			if (PM_data_in(15 downto 12) = "1001") and jump_reg = '0' then
				jump		<= '1';
			elsif (PM_data_in(15 downto 12) = "1010") then
				branch 	<= '1';
			elsif (PM_data_in(15 downto 12) = "1000") then
				ld_st 	<= '1'; --have a memory operation
			else
				branch	<= '0';
				ld_st 	<= '0';
				jump		<= '0';
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
				--last_dh				<= 0;
			else
			
--				if ((ID_dest_reg = PM_data_in(11 downto 7)) and (ID_dest_reg = PM_data_in(6 downto 2))) then
--					last_dh	<= 0;
--					
--				elsif ((EX_dest_reg = PM_data_in(11 downto 7)) and (EX_dest_reg = PM_data_in(6 downto 2))) then
--					last_dh	<= 1;
--					
--				elsif ((MEM_dest_reg = PM_data_in(11 downto 7)) and (MEM_dest_reg = PM_data_in(6 downto 2))) then
--					last_dh	<= 2;
--					
--				end if;
				
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
	
	--this process controls the program counter only
	program_counter	: process(reset_n, LAB_full, sys_clock)
	begin
	
		if reset_n = '0' then
		
			PC_reg 	<= "00000000000";
			
		elsif LAB_full = '1' then --we have a stall condition and need to keep PC where it is
			PC_reg <= PC_reg;
			
		else
			if rising_edge(sys_clock) then
		
				--for jumps, grab immediate value and update PC_reg
				if jump_reg = '1' then
					PC_reg 		<= std_logic_vector(unsigned(PM_data_in(11 downto 1)));
				
				--if we're stalled, keep PC where its at
				elsif LAB_full = '0' then
					PC_reg <= PC_reg;

				--otherwise increment PC to get next IW
				else 
					PC_reg 		<= std_logic_vector(unsigned(PC_reg) + 1);
					
				end if;
			end if; --sys_clock
		end if; --reset_n
	end process; --program_counter

		--latch outputs
		PC 	<= PC_reg;
		IW 	<= IW_reg;
		MEM 	<= MEM_reg;
		LAB_stall <= LAB_full;
		
end architecture arch;