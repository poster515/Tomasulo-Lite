-- Written by Joe Post

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.LAB_functions.all;
use work.control_unit_types.all;

------------------------------------------------------------
entity IFetch is
	generic ( 	LAB_MAX		: integer	:= 5;
					ROB_DEPTH 	: integer	:= 10	);
	port (
		reset_n, sys_clock  	: in std_logic;
		stall_pipeline			: in std_logic; --needed when waiting for certain commands, should be formulated in top level CU module
		ID_IW						: in std_logic_vector(15 downto 0); --source registers for instruction in ID stage (results available)
		EX_IW						: in std_logic_vector(15 downto 0); --source registers for instruction in EX stage (results available)
		MEM_IW					: in std_logic_vector(15 downto 0); --source registers for instruction in MEM stage (results available)
		WB_IW_in					: in std_logic_vector(15 downto 0); --source registers for instruction in MEM stage (results available)
		ID_reset, EX_reset, MEM_reset	: in std_logic;
		PM_data_in				: in std_logic_vector(15 downto 0);
		RF_in_3, RF_in_4		: in std_logic_vector(15 downto 0);
		WB_IW_out				: in std_logic_vector(15 downto 0);
		WB_data_out				: in std_logic_vector(15 downto 0);
		RF_in_3_valid			: in std_logic;
		RF_in_4_valid			: in std_logic;
		ROB_in					: in ROB;
		ALU_SR_in				: in std_logic_vector(3 downto 0);
		frst_branch_idx		: in integer;
		
		PC							: out std_logic_vector(10 downto 0);
		IW							: out std_logic_vector(15 downto 0);
		IW_out_specul			: out std_logic;	--denotes that the outgoing IW is speculative
		MEM						: out std_logic_vector(15 downto 0); --MEM is the IW representing the next IW as part of LD, ST, JMP, BNE(Z) operations
		LAB_reset_out			: out std_logic; --reset signal for ID stage
		LAB_stall				: out std_logic;
		RF_out_3_mux			: out std_logic_vector(4 downto 0);
		RF_out_4_mux			: out std_logic_vector(4 downto 0);
		RF_out_3_en				: out std_logic;
		RF_out_4_en				: out std_logic;
		condition_met			: inout std_logic;	--signal to WB for ROB. as soon as "results_available" goes high, need to evaluate all instructions after first branch
		results_available		: inout std_logic;	--signal to WB for ROB. as soon as it goes high, need to evaluate all instructions after first branch
		ALU_fwd_reg_1 			: out std_logic;		--output to ID stage to tell EX stage to forward MEM_out data in to ALU_in_1
		ALU_fwd_reg_2 			: out std_logic;		--output to ID stage to tell EX stage to forward MEM_out data in to ALU_in_2
		RF_revalidate			: out std_logic_vector(31 downto 0);
		clear_ID_IW_out		: out std_logic;
		clear_EX_IW_out		: out std_logic;
		clear_MEM_IW_out		: out std_logic
	);
end entity IFetch;

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
architecture arch of IFetch is
	--initialize addr_valid as '1' for all instructions except load/stores, branches, etc., so that when the
	--subsequent IW is issued on PM_data_in, we search for the only non-'1' addr_valid slot and establish the 
	--memory address there
	signal LAB	: LAB_actual := (others => ((others => '0'), '0', (others => '0'), '1'));	

	--array with addresses for all branch instructions
	--signal branches	: branch_addrs := (others => ((others => '0'), (others => '0'), '0'));
	signal branches	: branch_addrs;
	
	--Program counter (PC) register and target PC register 
	signal PC_reg		: std_logic_vector(10 downto 0);
	signal target_PC_reg	: std_logic_vector(10 downto 0);
	
	--signal to denote that LAB is full and we need to stall PM input clock
	signal LAB_full	: std_logic := '0';
	
	--registers for various outputs (IW register, and memory address register)
	signal MEM_reg		: std_logic_vector(15 downto 0)	:= "0000000000000000";
	signal IW_reg		: std_logic_vector(15 downto 0) 	:= "0000000000000000";
	
	--std_logic_vector tracking if there are any data hazards in any LAB instruction and below
	signal datahaz_status 	: std_logic_vector(LAB_MAX - 1 downto 0) := (others => '0');
	
	--std_logic tracking if there are any data hazards between PM_data_in and pipeline and LAB instructions
	signal PM_datahaz_status : std_logic;
	
	--unclocked signals which tells if the incoming instruction is a jump instruction
	signal jump				: std_logic := '0';
	
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
	
	--signal which goes to '1' when PM_data_in is an instruction requiring use of an actual Reg2, vice an immediate value
	signal reg2_used		: std_logic;
	
	--signal to store bits that indicate that various pipeline stages should be cleared due to an incorrectly taken branch
	signal clear_IW_outs : std_logic_vector(0 to 2);
	
	--signal that we've updated the PC_reg during a LAB stall event - prevents the PC from being decremented twice
	signal PC_adjusted : std_logic;
	
	--signal to help determine when the LAB isn't full anymore so we can adjust PC_reg accordingly
	signal previous_LAB_full : std_logic;
	
	--signals storing information that the PM_data_in, if issued, will require data forwarded from MEM_out stage
--	signal ALU_fwd_reg_1_reg, ALU_fwd_reg_2_reg	: std_logic;
	
	--TODO: figure out what to do with I2C_error signal from MEM block, which goes high when there are three mistries to 
		--read/write from I2C slave
		
begin
	process(reset_n, sys_clock, results_available, condition_met)
	begin
		if reset_n = '0' then
			clear_IW_outs	<= "000";
			RF_revalidate	<= "00000000000000000000000000000000";
			
		elsif rising_edge(sys_clock) then
			if results_available = '1' and condition_met = '1' then
				--clear the speculatively fetched instructions issued into pipeline - only clears these and not non-speculative instructions
				clear_IW_outs	<= check_ROB_for_wrongly_fetched_insts(ROB_in, IW_reg, ID_IW, EX_IW, MEM_IW);
				report "LAB: branch incorrectly taken - purging all irrelevant data.";
				
				--make function that logically ORs a RF revalidation vector for the RF for registers in pipeline that were incorrectly fetched and executed
				RF_revalidate <= revalidate_RF_regs(ROB_in, frst_branch_idx, IW_reg, ID_IW, EX_IW, MEM_IW, WB_IW_in);
				report "LAB: RF_revalidate = " & integer'image(to_integer(unsigned(revalidate_RF_regs(ROB_in, frst_branch_idx, IW_reg, ID_IW, EX_IW, MEM_IW, WB_IW_in))));
				
			else
				clear_IW_outs	<= "000";
				RF_revalidate	<= "00000000000000000000000000000000";
			end if;
		end if;
	end process;

	main	: process(reset_n, sys_clock)
		variable i	: integer range 0 to LAB_MAX - 1;
		begin
		
		if(reset_n = '0') then
			
			LAB 					<= init_LAB(LAB, LAB_MAX);
			branches				<= init_branches(branches, ROB_DEPTH);
			IW_reg 				<= "1111111111111111";
			LAB_reset_out 		<= '0';
			results_available <= '0';
			condition_met 		<= '0';
			LAB_full 			<= '0';
			ALU_fwd_reg_1 		<= '0';
			ALU_fwd_reg_2		<= '0';
			--RF_revalidate		<= "00000000000000000000000000000000";
			--should clear_IW_outs be "111" instead to initialize everything to a no-op?
			--clear_IW_outs 		<= "000";

		elsif rising_edge(sys_clock) then
			LAB_reset_out		<= '1';
			LAB <= LAB;
			--branches <= branches;
			--jumps are easily handled with "program_counter" process below 
			--ALU instructions are managed and re-ordered strictly between branches in ROB

			--continually check for branch condition on PM_data_in
			if branch = '1' then
				--do initial check to see if results are available
				--report "LAB: detected branch in PM_data_in.";
				
				results_available 	<= results_ready(bne_from_ROB, bnez_from_ROB, RF_in_3_valid, RF_in_4_valid, RF_in_3, RF_in_4, ROB_in, WB_IW_out, WB_data_out, PM_data_in, frst_branch_idx)(0); --'0' = not available, '1' = available
				condition_met 			<= results_ready(bne_from_ROB, bnez_from_ROB, RF_in_3_valid, RF_in_4_valid, RF_in_3, RF_in_4, ROB_in, WB_IW_out, WB_data_out, PM_data_in, frst_branch_idx)(1); --'0' = not met, '1' = met

			--this "elsif" handles other branches that currently exist in the ROB that have not been resolved yet. should continually monitor those, as determined by "ROB_branch" process below. 
			--need this additional if case because the data sent to "results_result" differ from the above if case. 
			
			elsif results_available = '1' then
				results_available <= '0';
				condition_met		<= '0';
				
			elsif branch_exists = '1' and is_unresolved = '1' then	
				--report "LAB: branch exists in ROB.";
				results_available 	<= results_ready(bne_from_ROB, bnez_from_ROB, RF_in_3_valid, RF_in_4_valid, RF_in_3, RF_in_4, ROB_in, WB_IW_out, WB_data_out, PM_data_in, frst_branch_idx)(0); --'0' = not available, '1' = available
				condition_met 			<= results_ready(bne_from_ROB, bnez_from_ROB, RF_in_3_valid, RF_in_4_valid, RF_in_3, RF_in_4, ROB_in, WB_IW_out, WB_data_out, PM_data_in, frst_branch_idx)(1); --'0' = not met, '1' = met

			else
			
				results_available 	<= '0';
				condition_met 			<= '0';
			end if;
			
			--if statements to record branch addresses (only if branch condition is unresolved still)
			if branch_reg = '1' and results_available = '0' then
				--this function will store the current PM_data_in, being the branch address, and shift the array down if a previous branch condition is resolved
				branches <= store_shift_branch_addr(branches, results_available, '1', PM_data_in, PC_reg, ROB_DEPTH); --'1' is a bit stating that the next two bytes are valid data (PM_data_in)
			
			elsif results_available = '1' and condition_met = '1' then
				--clear branches since all subsequent branches will be invalidly fetched instructions
				branches <= init_branches(branches, ROB_DEPTH);
			else
				--this function will just shift "branches" appropriately if a previous branch condition is resolved or the incoming branch is resolved
				branches <= store_shift_branch_addr(branches, results_available, '0', "0000000000000000", "00000000000", ROB_DEPTH);
			end if;

			--if pipeline isn't stalled, just dispatch instruction
			if stall_pipeline = '0' then 

					if results_available = '1' and condition_met = '1' then
						--purge speculative instructions in ROB since some (or all) were erroneously fetched from PM
						--additionally, don't want to buffer PM_data_in
						
						--clear all speculatively fetched instructions from LAB
						LAB <= purge_insts(LAB, ROB_in, frst_branch_idx);
						
						--issue no-op. this may incur a one clock penalty but reduces the complexity of determining any other valid instructions in LAB
						IW_reg 				<= "1111111111111111";

					else

						for i in 0 to LAB_MAX - 1 loop
							
							if	(((ID_IW(11 downto 7) /= LAB(i).inst(11 downto 7) and ID_IW(11 downto 7) /= LAB(i).inst(6 downto 2)) or 
								--accounts for data hazards due to no-ops
								 ((ID_IW(11 downto 7) = LAB(i).inst(11 downto 7) or ID_IW(11 downto 7) = LAB(i).inst(6 downto 2)) and ID_IW(15 downto 12) = "1111") or
								--allows a GPIO/W to be issued, immediately followed by a GPIO/R to the same register
								 (ID_IW(11 downto 7) = LAB(i).inst(11 downto 7) and ID_IW(15 downto 12) = "1011" and ID_IW(1 downto 0) = "01" and LAB(i).inst(15 downto 12) = "1011" and LAB(i).inst(1 downto 0) = "00")) and
								 
								 ((ID_IW(6 downto 2) = LAB(i).inst(6 downto 2) and LAB(i).inst(15 downto 12) = "1000" and ID_IW(15 downto 12) = "1111") or
								
								not(ID_IW(6 downto 2) = LAB(i).inst(6 downto 2) and ID_IW(15 downto 12) = "1000" and ID_IW(1 downto 0) = "10" and LAB(i).inst(15 downto 12) = "1000" and LAB(i).inst(1 downto 0) = "00"))	
								
								and ID_reset = '1') and
								
								(((EX_IW(11 downto 7) /= LAB(i).inst(11 downto 7) and EX_IW(11 downto 7) /= LAB(i).inst(6 downto 2)) or 
								 ((EX_IW(11 downto 7) = LAB(i).inst(11 downto 7) or EX_IW(11 downto 7) = LAB(i).inst(6 downto 2)) and EX_IW(15 downto 12) = "1111") or
								 --allows a GPIO/W to be issued, followed by a GPIO/R to the same register
								 ((EX_IW(11 downto 7) = LAB(i).inst(11 downto 7) and EX_IW(15 downto 12) = "1011" and EX_IW(1 downto 0) = "01" and LAB(i).inst(15 downto 12) = "1011" and LAB(i).inst(1 downto 0) = "00")) or
								 (EX_IW(6 downto 2) = LAB(i).inst(6 downto 2) and EX_IW(15 downto 12) = "1000" and EX_IW(1 downto 0) = "10" and LAB(i).inst(15 downto 12) = "1000" and LAB(i).inst(1 downto 0) = "00")) 
								 
								 and EX_reset = '1') and
								 
								(((MEM_IW(11 downto 7) /= LAB(i).inst(11 downto 7) and MEM_IW(11 downto 7) /= LAB(i).inst(6 downto 2)) or 
								 ((MEM_IW(11 downto 7) = LAB(i).inst(11 downto 7) or MEM_IW(11 downto 7) = LAB(i).inst(6 downto 2)) and MEM_IW(15 downto 12) = "1111") or
								 (MEM_IW(11 downto 7) = LAB(i).inst(11 downto 7) and MEM_IW(15 downto 12) = "1011" and MEM_IW(1 downto 0) = "01" and LAB(i).inst(15 downto 12) = "1011" and LAB(i).inst(1 downto 0) = "00") or
								 (MEM_IW(6 downto 2) = LAB(i).inst(6 downto 2) and MEM_IW(15 downto 12) = "1000" and MEM_IW(1 downto 0) = "10" and LAB(i).inst(15 downto 12) = "1000" and LAB(i).inst(1 downto 0) = "00")) 
								 
								 and MEM_reset = '1') and datahaz_status(i) = '0' and 
									
								LAB(i).inst_valid = '1' then --we don't have any conflict in pipeline and LAB instruction is valid
								
								--check if there are any hazards within the LAB for the ith entry (for memory instructions)
								if LAB(i).inst(15 downto 12) = "1000" and LAB(i).addr_valid = '1' then
								
									report "LAB: Issuing memory instruction and buffering PM_data_in, i = " & integer'image(i);
									--if so, we can issue the ith instruction
									IW_reg 		<= LAB(i).inst;
									MEM_reg 		<= LAB(i).addr;
									LAB_full <= '0';
									--shift LAB down and buffer PM_data_in
									LAB 			<= shiftLAB_and_bufferPM(LAB, PM_data_in, i, LAB_MAX, '1', ld_st_reg or branch_reg);
									
									--exit, we're done here
									exit;
								
								--check if there are any hazards within the LAB now for the ith entry (for non-memory instructions)
								elsif LAB(i).inst(15 downto 12) /= "1000" then
									
									report "LAB: Issuing non-memory instruction and buffering PM_data_in, i = " & integer'image(i);
									--if not, we can issue the ith instruction
									IW_reg 	<= LAB(i).inst;
									LAB_full <= '0';
									--shift LAB down and buffer PM_data_in
									LAB 		<= shiftLAB_and_bufferPM(LAB, PM_data_in, i, LAB_MAX, '1', ld_st_reg or branch_reg);
									
									--exit here, we're done
									exit;
									
								else
	--								--can't do anything if there's a data hazard for this LAB instruction, keep moving on, buffer PM but DON'T SHIFT LAB
	--								--just issue no-op by default
									report "LAB: 28. Can't issue LAB instruction at slot: " & Integer'image(i);
								end if; --datahaz_status
								
							elsif LAB(i).inst_valid = '0' and PM_datahaz_status = '1' and PM_data_in(15 downto 12) /= "1001" and PM_data_in(15 downto 12) /= "1010" and branch_reg = '0' and ld_st_reg = '0' then
								--now we're at the first spot we can buffer PM_data_in, since there's no valid instruction here and the PM_data_in has a hazard
								--just buffer PM_data_in
								report "LAB: Can't issue any valid LAB inst or PM_data, buffer PM_data";
								IW_reg 				<= "1111111111111111";
								LAB 					<= shiftLAB_and_bufferPM(LAB, PM_data_in, LAB_MAX, LAB_MAX, '0', ld_st_reg or branch_reg);
								exit;
								
							elsif i = LAB_MAX - 1 then 
								--no other LAB instruction could be issued - check if we can issue PM_data_in
								--check for branches and jumps first
								if PM_data_in(15 downto 12) /= "1001" and PM_data_in(15 downto 12) /= "1010" and branch_reg = '0' and ld_st_reg = '0' and PM_datahaz_status = '0' then
									--report "issuing PM_data_in to pipeline instead of buffering to LAB.";
									IW_reg 			<= PM_data_in;
									LAB_full 		<= '0';
									
									--next check for data forwarding opportunity
									if (((ID_IW(11 downto 7) = PM_data_in(11 downto 7)) or (ID_IW(11 downto 7) = PM_data_in(6 downto 2) and reg2_used = '1')) and ID_reset = '1' and ID_IW(15 downto 12) /= "1111") or
										(((MEM_IW(11 downto 7) = PM_data_in(11 downto 7)) or (MEM_IW(11 downto 7) = PM_data_in(6 downto 2) and reg2_used = '1')) and MEM_reset = '1' and MEM_IW(15 downto 12) /= "1111")  then
										
										--report "LAB: can't forward ALU data.";
										ALU_fwd_reg_1 		<= '0';
										ALU_fwd_reg_2		<= '0';
								
									elsif (EX_IW(11 downto 7) = PM_data_in(11 downto 7) and EX_reset = '1' and EX_IW(15 downto 12) /= "1111" and PM_datahaz_status = '0') then
										--we have a conflict but can forward data from the MEM_out data going into ALU_top, into ALU_in_1
										ALU_fwd_reg_1 		<= '1';
										
										if (EX_IW(11 downto 7) = PM_data_in(6 downto 2) and reg2_used = '1' and EX_reset = '1' and EX_IW(15 downto 12) /= "1111" and PM_datahaz_status = '0') then 
											--we have a conflict but can forward data from the MEM_out data going into ALU_top, into ALU_in_2
											ALU_fwd_reg_2 	<= '1';
											report "LAB: PM_data_in reg1 and reg2 match ID stage output IW, setting ALU_fwd_reg_1_reg and ALU_fwd_reg_2_reg.";
										else
											ALU_fwd_reg_2 	<= '0';
											report "LAB: PM_data_in reg1 matches ID stage output IW, setting ALU_fwd_reg_1_reg.";
										end if;
										
									elsif (EX_IW(11 downto 7) = PM_data_in(6 downto 2) and reg2_used = '1' and EX_reset = '1' and EX_IW(15 downto 12) /= "1111" and PM_datahaz_status = '0') then 
										--we have a conflict but can forward data from the MEM_out data going into ALU_top, into ALU_in_2
										ALU_fwd_reg_2 	<= '1';
										ALU_fwd_reg_1 	<= '0';
										
										report "LAB: PM_data_in reg2 matches ID stage output IW, setting ALU_fwd_reg_2_reg.";

									else
										report "LAB: Can't forward ALU data.";
										ALU_fwd_reg_1 	<= '0';
										ALU_fwd_reg_2	<= '0';
									end if;	

									exit;
								
								else
									--can't issue any instruction in LAB and can't issue PM_data_in
									report "LAB: 26. can't issue any LAB inst/PM_data, so buffer PM_data.";
									LAB 					<= shiftLAB_and_bufferPM(LAB, PM_data_in, LAB_MAX, LAB_MAX, '0', ld_st_reg or branch_reg);
									IW_reg 				<= "1111111111111111";
									LAB_full 			<= LAB(LAB_MAX - 1).inst_valid and not(ld_st_reg); --AND with ld_st_reg here since we can still buffer the memory address even if the LAB is full
									ALU_fwd_reg_1 		<= '0';
									ALU_fwd_reg_2		<= '0';
									exit;
								end if;
							else
								--we're somewhere in the middle of the LAB and have a hazard with the current LAB instruction
								report "LAB: 27. At LAB slot " & Integer'image(i) & " and can't issue this instruction.";

							end if; --various tags
						end loop; --for i

					end if; --LAB(0).valid = '0' 
			else
				--if stalled, just issue noop
				--IW_reg 				<= "1111111111111111";
				--RF_revalidate		<= "00000000000000000000000000000000";
			end if; --stall_pipeline
					
		end if; --reset_n
	end process;
	
	--this process controls the program counter only
	program_counter	: process(reset_n, LAB_full, sys_clock, stall_pipeline)
	begin

		if reset_n = '0' then
			PC_reg 				<= "00000000000";
			previous_LAB_full <= '0';
			PC_adjusted 		<= '0';
			
		elsif stall_pipeline = '1' then --we have a stall condition and need to keep PC where it is
			PC_reg <= PC_reg;
		
		elsif previous_LAB_full = '1' and LAB_full = '0' then
			PC_reg <= std_logic_vector(unsigned(PC_reg) + 1);
			PC_adjusted <= '0';
			
		elsif LAB_full = '1' then
			if PC_adjusted = '0' then
				PC_reg <= std_logic_vector(unsigned(PC_reg) - 1);
				PC_adjusted <= '1';
			else
				PC_reg <= PC_reg;
			end if;
		else
			if rising_edge(sys_clock) then
			
				previous_LAB_full <= LAB_full;
				
				if stall_pipeline = '1' then
					--if we're stalled, keep PC where its at
					PC_reg 	<= PC_reg;
					
				elsif branch_reg = '1' and results_available = '0' then
					--speculatively execute the next instruction. the "main" process will handle the rest. 
					PC_reg 	<= std_logic_vector(unsigned(PC_reg) + 1);
					
				elsif branch_reg = '1' and results_available = '1' and condition_met = '1' then
					--results are available and we can non-speculatively execute the branched instructions. the "main" process will handle the rest. 
					PC_reg 	<= std_logic_vector(unsigned(PM_data_in(11 downto 1)));
					
				elsif branch_reg = '1' and results_available = '1' and condition_met = '0' then
					--results are available and we can non-speculatively execute the next instructions. the "main" process will handle the rest. 
					PC_reg 	<= std_logic_vector(unsigned(PC_reg) + 1);
					
				elsif branch_reg = '0' and results_available = '1' and condition_met = '1' and branch_exists = '1' then
					--results are available and we can non-speculatively execute the branched instructions. the "main" process will handle the rest. 
					PC_reg 	<= branches(0).addr_met(10 downto 0);
					
				elsif branch_reg = '0' and results_available = '1' and condition_met = '0' and branch_exists = '1' then
					--results are available and we can non-speculatively execute the next instructions. the "main" process will handle the rest. 
					if jump = '1' then
						PC_reg 	<= std_logic_vector(unsigned(PM_data_in(11 downto 1)));
					else
						PC_reg 	<= std_logic_vector(unsigned(PC_reg) + 1);
					end if;
					
				elsif jump = '1' then
					--for jumps, grab immediate value and update PC_reg
					PC_reg 	<= std_logic_vector(unsigned(PM_data_in(11 downto 1)));
					
				else 
					--otherwise increment PC to get next IW
					PC_reg	<= target_PC_reg;
					--PC_reg 	<= std_logic_vector(unsigned(PC_reg) + 1);
					
				end if;
			end if; --sys_clock
		end if; --reset_n
	end process; --program_counter
	
	--process to determine whether an unresolved branch instruction exists in the ROB, this is used to then confirm if the results are ready
	ROB_branch	: process (reset_n, ROB_in, PM_data_in) 
	begin
		if reset_n = '0' then
			branch_exists 	<= '0';
			is_unresolved 	<= '0';
			bne_from_ROB 	<= '0';
			bnez_from_ROB 	<= '0';
			RF_out_3_mux 	<= "00000";
			RF_out_4_mux 	<= "00000";
			RF_out_3_en		<= '0';
			RF_out_4_en		<= '0';
		else
			bne_from_ROB 	<= '0';
			bnez_from_ROB 	<= '0';
		
			for i in 0 to 9 loop
				--find the first unresolved branch in the ROB, grab some info, and then exit 
				if ROB_in(i).inst(15 downto 12) = "1010" and ROB_in(i).specul = '0' then
				
					branch_exists 	<= '1';
					is_unresolved 	<= '0';
					RF_out_3_mux 	<= PM_data_in(11 downto 7);
					RF_out_4_mux 	<= PM_data_in(6 downto 2);
					RF_out_3_en		<= PM_data_in(15) and not(PM_data_in(14)) and PM_data_in(13) and not(PM_data_in(12)) and not(branch_reg);
					RF_out_4_en		<= PM_data_in(15) and not(PM_data_in(14)) and PM_data_in(13) and not(PM_data_in(12)) and not(branch_reg);
					exit;
				elsif ROB_in(i).inst(15 downto 12) = "1010" and ROB_in(i).specul = '1' then
				
					branch_exists 	<= '1';
					is_unresolved 	<= '1';
					bne_from_ROB 	<= not(ROB_in(i).inst(1)) and ROB_in(i).inst(0);
					bnez_from_ROB 	<= not(ROB_in(i).inst(1)) and not(ROB_in(i).inst(0));
					RF_out_3_mux 	<= ROB_in(i).inst(11 downto 7);
					RF_out_4_mux 	<= ROB_in(i).inst(6 downto 2);
					RF_out_3_en		<= ROB_in(i).inst(15) and not(ROB_in(i).inst(14)) and ROB_in(i).inst(13) and not(ROB_in(i).inst(12));
					RF_out_4_en		<= ROB_in(i).inst(15) and not(ROB_in(i).inst(14)) and ROB_in(i).inst(13) and not(ROB_in(i).inst(12));
					exit;
					
				elsif i = 9 then
					RF_out_3_mux 	<= PM_data_in(11 downto 7);
					RF_out_4_mux 	<= PM_data_in(6 downto 2);
					RF_out_3_en		<= PM_data_in(15) and not(PM_data_in(14)) and PM_data_in(13) and not(PM_data_in(12)) and not(branch_reg);
					RF_out_4_en		<= PM_data_in(15) and not(PM_data_in(14)) and PM_data_in(13) and not(PM_data_in(12)) and not(branch_reg);
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
	
	--set load/store indicator ("1000")
	ld_st <= PM_data_in(15) and not(PM_data_in(14)) and not(PM_data_in(13)) and not(PM_data_in(12));
	
	--set jump indicator ("1001")
	jump <= PM_data_in(15) and not(PM_data_in(14)) and not(PM_data_in(13)) and PM_data_in(12);
	
	--set branch indicator ("1010") and associated control signals 
	branch <= PM_data_in(15) and not(PM_data_in(14)) and PM_data_in(13) and not(PM_data_in(12)) and not(branch_reg);
	
	
	--establish the applicable branch type when the branch instruction is received
	bnez				<= not(PM_data_in(1)) and not(PM_data_in(0)) and PM_data_in(15) and not(PM_data_in(14)) and PM_data_in(13) and not(PM_data_in(12)) and not(branch_reg);
	bne				<= not(PM_data_in(1)) and PM_data_in(0) and PM_data_in(15) and not(PM_data_in(14)) and PM_data_in(13) and not(PM_data_in(12)) and not(branch_reg);
	
	reg2_used 		<= (not(PM_data_in(15)) and not(PM_data_in(1)) and not(PM_data_in(0))) or 
							(not(PM_data_in(15)) and PM_data_in(14)) or
							(PM_data_in(15) and not(PM_data_in(14)) and not(PM_data_in(13)) and not(PM_data_in(12)) and not(PM_data_in(0))) or 
							--account for CP command which needs the reg2 to be up-to-date
							(PM_data_in(15) and PM_data_in(14) and not(PM_data_in(13)) and PM_data_in(12));
	
	--process to generate clocked registers for branch and data memory instructions
	process(reset_n, sys_clock) 
	begin
		if reset_n = '0' then
			ld_st_reg 		<= '0';
			branch_reg 		<= '0';
		elsif rising_edge(sys_clock) then
			if branch = '1' and branch_reg = '0' then
				branch_reg 	<= '1';
				
			elsif ld_st = '1' and ld_st_reg = '0' then
				ld_st_reg 	<= '1'; --
				
			else
				ld_st_reg 		<= '0';
				branch_reg 		<= '0';
				
			end if;
		end if; --reset_n
						
	end process;
	
	--this process determines whether the PM_data_in poses a data hazard to any instruction in LAB or in pipeline
	--PM_data_hazard_status	: process(reset_n, PM_data_in, ID_IW, EX_IW, MEM_IW, ID_reset, EX_reset, MEM_reset, reg2_used, LAB, branch_reg, ld_st_reg)
	PM_data_hazard_status	: process(reset_n, PM_data_in, LAB, ld_st, reg2_used)
		variable dh_ptr_outer 	: integer range 0 to LAB_MAX - 1;
		--variable last_dh			: integer range 0 to LAB_MAX - 1 + 3; --adding three to account for pipeline instructions
	begin	
		if reset_n = '0' then
		
			PM_datahaz_status <= '0';
			
		elsif branch_reg = '0' and ld_st_reg = '0' then  
	
			--start this loop at 0 because we want to check PM_data_in against entire LAB
			for dh_ptr_outer in 0 to LAB_MAX - 1 loop
			
				if (LAB(dh_ptr_outer).inst(11 downto 7) = PM_data_in(11 downto 7) and LAB(dh_ptr_outer).inst_valid  = '1') or 
					(LAB(dh_ptr_outer).inst(11 downto 7) = PM_data_in(6 downto 2) and reg2_used = '1' and LAB(dh_ptr_outer).inst_valid  = '1') then
					
					--just say that we have a hazard and exit for now
					--TODO: can this be optimized to only search the LAB based on the proximity to a known hazard in the pipeline?
					--report "setting PM_data_hazard because of LAB hazards on loop i = " & integer'image(dh_ptr_outer);
					PM_datahaz_status 	<= '1';
					exit;
				else
					if dh_ptr_outer = LAB_MAX - 1 then 
						if (((ID_IW(11 downto 7) = PM_data_in(11 downto 7)) or (ID_IW(11 downto 7) = PM_data_in(6 downto 2) and reg2_used = '1')) and ID_reset = '1' and ID_IW(15 downto 12) /= "1111") or
							(((MEM_IW(11 downto 7) = PM_data_in(11 downto 7)) or (MEM_IW(11 downto 7) = PM_data_in(6 downto 2) and reg2_used = '1')) and MEM_reset = '1' and MEM_IW(15 downto 12) /= "1111") then
							
							--report "setting PM_data_hazard because of pipeline hazards.";
							PM_datahaz_status 	<= '1';
							exit;
						else
							PM_datahaz_status 	<= '0';
							exit;
						end if;	
					else
						PM_datahaz_status 	<= '0';
					end if;
				end if;
				
			end loop; --dh_ptr_outer 
		elsif ld_st = '1' then
			--if ld_st = '1', then we have a load or store instruction on PM_data_in at this clock edge. need to set PM_datahaz_status so we can then fetch address
			PM_datahaz_status <= '1';
		else
			PM_datahaz_status <= '0';
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
			
				for dh_ptr_inner in 0 to LAB_MAX - 2 loop
			
					if (
							(LAB(dh_ptr_inner).inst(11 downto 7) 	= LAB(dh_ptr_outer).inst(11 downto 7) and 
							 LAB(dh_ptr_outer).inst_valid 			= '1') or 
							 
							(LAB(dh_ptr_inner).inst(11 downto 7) 	= LAB(dh_ptr_outer).inst(6 downto 2) and 
							 LAB(dh_ptr_outer).inst_valid 			= '1') or 
							
							(LAB(dh_ptr_inner).inst(6 downto 2) = LAB(dh_ptr_outer).inst(6 downto 2) and 
							 LAB(dh_ptr_inner).inst(15 downto 12) 	= "1000" and 
							 LAB(dh_ptr_outer).inst(15 downto 12) 	= "1000") or
							 
							(LAB(dh_ptr_inner).inst(6 downto 2) = LAB(dh_ptr_outer).inst(11 downto 7) and 
							 LAB(dh_ptr_inner).inst(15 downto 12) 	= "1000")
							 
						) and dh_ptr_inner < dh_ptr_outer then
						
						datahaz_status(dh_ptr_outer) <= '1';
						exit; --exit inner loop, there's a hazard at this dh_ptr_outer location
					else
						datahaz_status(dh_ptr_outer) <= '0';
						--datahaz_status(dh_ptr_outer) <= '0';
						--don't exit here, need to evaluate all dh_ptr_inner locations
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

		clear_ID_IW_out	<= clear_IW_outs(0);
		clear_EX_IW_out	<= clear_IW_outs(1);
		clear_MEM_IW_out	<= clear_IW_outs(2);
		
end architecture arch;