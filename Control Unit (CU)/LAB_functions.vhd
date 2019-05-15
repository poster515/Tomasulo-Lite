library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all; 
use work.control_unit_types.all;
--use work.ROB_functions.all;
 
package LAB_functions is 

	--function to update "branches", which manages all currently unresolved branch instructions
	function store_shift_branch_addr(	branches				: in branch_addrs;
													results_available	: in std_logic;
													addr_valid			: in std_logic;
													addr_met				: in std_logic_vector(15 downto 0);
													PC_reg				: in std_logic_vector(10 downto 0);
													ROB_DEPTH			: in integer)
		return branch_addrs;
	
	--function which initializes LAB	tags									
	function init_LAB (	LAB_in	: in LAB_actual;
						LAB_MAX	: in integer		) 
		return LAB_actual; 
		
	function init_branches(	branches	: in branch_addrs;
									LAB_MAX	: in integer)
		return branch_addrs;
		
	function shiftLAB_and_bufferPM(	LAB_in		: in LAB_actual;
												PM_data_in	: in std_logic_vector(15 downto 0);
												issued_inst	: in integer;
												LAB_MAX		: in integer;
												shift_LAB	: in std_logic;
												ld_st_reg	: in std_logic	)
		return LAB_actual;
		
	--function to type convert std_logic to integer
	function convert_SL ( shift_LAB : in std_logic )
		return integer;
	
	--function to determine if results of branch condition are ready	
	function results_ready( bne 				: in std_logic; 
									bnez				: in std_logic; 
									RF_in_3_valid 	: in std_logic;  
									RF_in_4_valid	: in std_logic;   
									RF_in_3			: in std_logic_vector(15 downto 0);
									RF_in_4			: in std_logic_vector(15 downto 0);
									ROB_in			: in ROB;
									WB_IW_out		: in std_logic_vector(15 downto 0);
									WB_data_out		: in std_logic_vector(15 downto 0)) 
		return std_logic_vector; --std_logic_vector([[condition met]], [[results ready]])
		
end LAB_functions; 

package body LAB_functions is

	--function which initializes LAB	tags									
	function init_LAB (	LAB_in	: in 	LAB_actual;
								LAB_MAX	: in integer		) 
		return LAB_actual is
								
		variable i 				: integer 		:= 0;	
		variable LAB_temp 	: LAB_actual 	:= LAB_in;
		
	begin
		
		for i in 0 to LAB_MAX - 1 loop
			LAB_temp(i).inst				:= "0000000000000000";
			LAB_temp(i).inst_valid		:= '0';
			LAB_temp(i).addr				:= "0000000000000000";
			LAB_temp(i).addr_valid		:= '1';
		end loop; --for i
		
		return LAB_temp;
	end function;
	
	function init_branches(	branches	: in branch_addrs;
									LAB_MAX	: in integer)
		return branch_addrs is
		
	variable i 					: integer range 0 to LAB_MAX - 1;
	variable branches_temp	: branch_addrs := branches;
	
	begin
		for i in 0 to LAB_MAX - 1 loop
			branches_temp(i).addr_met		:= "0000000000000000";
			branches_temp(i).addr_unmet	:= "0000000000000000";
			branches_temp(i).addr_valid  	:= '0';
		end loop;
	
		return branches_temp;
	end function;
	
	
	--function to update "branches", which manages all currently unresolved branch instructions
	function store_shift_branch_addr(	branches				: in branch_addrs;
													results_available	: in std_logic;		--if this is '1', clear zeroth instruction because we know the result
													addr_valid			: in std_logic;
													addr_met				: in std_logic_vector(15 downto 0);
													PC_reg				: in std_logic_vector(10 downto 0);
													ROB_DEPTH			: in integer)
		return branch_addrs is
		
		variable branches_temp	: branch_addrs	:= branches;
		variable i 					: integer range 0 to 9;
		variable n_clear_zero	: integer range 0 to 1;
		variable addr_unmet		: std_logic_vector(10 downto 0) := std_logic_vector(unsigned(PC_reg) + 1);
	begin
		n_clear_zero	:= convert_SL(not(results_available));
	
		for i in 0 to ROB_DEPTH - 2 loop
			--condition covers when we get to a location in "branches" that isn't valid, i.e., we can buffer branch addresses there
			if branches_temp(i).addr_valid = '0' then
				--incoming instruction is a new, valid branch instruction and should be buffered 
				if addr_valid = '1' then
					branches_temp(i).addr_met 		:= addr_met;
					branches_temp(i).addr_unmet 	:= "00000" & addr_unmet;
					branches_temp(i).addr_valid 	:= '1';
					exit;
				else
					exit;
				end if;
				
			--condition for when we've gotten to the last valid instruction in the branch_addrs
			elsif branches_temp(i).addr_valid = '1' and branches_temp(i + 1).addr_valid = '0' then
				
				if addr_valid = '1' then
					--n_clear_zero automatically shifts "branches" entries
					branches_temp(i + n_clear_zero).addr_met		:= addr_met;
					branches_temp(i + n_clear_zero).addr_unmet	:= "00000" & addr_unmet;
					branches_temp(i + n_clear_zero).addr_valid 	:= '1';
					
					exit;
				else
					--results_available automatically shifts ROB entries
					branches_temp(i) := branches_temp(i + convert_SL(results_available));
					exit;
				end if;

			--condition for when the "branches" is full, we want to buffer incoming PM_data_in, and can clear the zeroth instruction (i.e., make room)
			elsif i = ROB_DEPTH - 2 and results_available = '1' and addr_valid = '1' then

					branches_temp(ROB_DEPTH - 1).addr_met 		:= addr_met;
					branches_temp(ROB_DEPTH - 1).addr_unmet 	:= "00000" & addr_unmet;
					branches_temp(ROB_DEPTH - 1).addr_valid 	:= '1';

			else
				--results_available automatically shifts ROB entries
				branches_temp(i) := branches_temp(i + convert_SL(results_available));
				
			end if; --ROB_temp(i).valid
		end loop;
		
		return branches_temp;
		
	end function;
	
	--function to shift LAB down and buffer Program Memory input
	--TODO: modify so we don't rearrange any branch instructions
	function shiftLAB_and_bufferPM(	LAB_in		: in LAB_actual;
												PM_data_in	: in std_logic_vector(15 downto 0);
												issued_inst	: in integer; --location of instruction that was issued, start shift here
												LAB_MAX		: in integer;
												shift_LAB	: in std_logic;
												ld_st_reg	: in std_logic	)
		return LAB_actual is
								
		variable i 			: integer 		:= issued_inst;	
		variable LAB_temp	: LAB_actual	:= LAB_in;
		variable not_SL	: integer;
		
	begin
		
		not_SL := convert_SL(not(shift_LAB));
		
		for i in 0 to LAB_MAX - 2 loop
			--need to ensure that we're above last issued instruction, and instruction isn't a jump
			if i >= issued_inst and PM_data_in(15 downto 12) /= "1001" and PM_data_in(15 downto 12) /= "1010" then
			
				if (LAB_temp(i).inst_valid = '1') and (LAB_temp(i + 1).inst_valid = '0') then
				
					report "LAB_func: At LAB spot " & integer'image(i + convert_SL(not(shift_LAB))) & " we can buffer PM_data_in";
					LAB_temp(i + not_SL).inst 			:= PM_data_in;
					LAB_temp(i + not_SL).inst_valid 	:= '1';
					LAB_temp(i + not_SL).addr			:= (others => '0');
					
					if PM_data_in(15 downto 14) = "10" and ((PM_data_in(1) nand PM_data_in(0)) = '1') then
						LAB_temp(i + not_SL).addr_valid	:= '0';
					else
						LAB_temp(i + not_SL).addr_valid	:= '1';
					end if;
					exit;
					
				elsif i = LAB_MAX - 2 and LAB_temp(i).inst_valid = '1' and LAB_temp(i + 1).inst_valid = '1' then
				
					report "LAB_func: at end of LAB, buffer PM_data_in at last LAB spot.";
					LAB_temp(i + not_SL).inst 			:= PM_data_in;
					LAB_temp(i + not_SL).inst_valid 	:= '1';
					LAB_temp(i + not_SL).addr			:= (others => '0');
						
					if PM_data_in(15 downto 14) = "10" and ((PM_data_in(1) nand PM_data_in(0)) = '1') then
						LAB_temp(i + not_SL).addr_valid	:= '0';
					else
						LAB_temp(i + not_SL).addr_valid	:= '1';
					end if;
					exit;
				
				else
					report "LAB_func: at " & Integer'image(i) & " shift entry from " & Integer'image(i + convert_SL(shift_LAB));
					LAB_temp(i) := LAB_temp(i + convert_SL(shift_LAB));
					
				end if;
			
			elsif ld_st_reg = '1' and ((LAB_temp(i).inst_valid = '1' and LAB_temp(i + 1).inst_valid = '0') or i = LAB_MAX - 1) then
				report "LAB_func: At spot " & integer'image(i + convert_SL(not(shift_LAB))) & " buffer mem address";
				LAB_temp(i).inst 			:= LAB_temp(i + convert_SL(shift_LAB)).inst;
				LAB_temp(i).inst_valid 	:= LAB_temp(i + convert_SL(shift_LAB)).inst_valid;
				LAB_temp(i).addr 			:= PM_data_in;
				LAB_temp(i).addr_valid 	:= '1';
				exit;
			--need to handle case where we don't want to buffer PM_data_in (i.e., jumps and branches) but still want to shift LAB down and issue LAB(0)
			else
				report "LAB_func: at " & Integer'image(i + not_SL) & " shift entry from " & Integer'image(i + 1);
				LAB_temp(i + not_SL)	:= LAB_temp(i + 1);
			end if; --i >= issued_inst
		end loop; --for i
		
		return LAB_temp; --come here if there are no spots available
	end function;
	
	--function to type convert std_logic to integer
	function convert_SL ( shift_LAB : in std_logic )
	
		return integer is

	begin
	
		if shift_LAB = '1' then
			return 1;
		else
			return 0;
		end if;
		
	end;
	
	--function to determine if results of branch condition are ready	
	function results_ready( bne 				: in std_logic; 
									bnez				: in std_logic; 
									RF_in_3_valid 	: in std_logic;  --valid marker from RF for Reg1 field of branch IW
									RF_in_4_valid	: in std_logic;  --valid marker from RF for Reg2 field of branch IW
									RF_in_3			: in std_logic_vector(15 downto 0);
									RF_in_4			: in std_logic_vector(15 downto 0);
									ROB_in			: in ROB;
									WB_IW_out		: in std_logic_vector(15 downto 0);
									WB_data_out		: in std_logic_vector(15 downto 0)) 
									
		return std_logic_vector is --std_logic_vector([[results ready]], [[condition met]])
								
		variable i, j	 					: integer 	:= 0;	
		variable reg1_slot, reg2_slot	: integer 	:= 10;	
		variable reg1_resolved			: std_logic := '0';
		variable reg2_resolved			: std_logic := '0';
		variable condition_met			: std_logic := '0';
		variable WB_IW_resolves_br		: std_logic	:= '1';	--starts high and only goes low if an incomplete instruction in ROB matches MEM_WB_IW
		
	begin

	for i in 0 to 9 loop
	
		if ROB_in(i).inst(15 downto 12) = "1010" and ROB_in(i).valid = '1' then	--we have the first branch instruction in ROB
			
			for j in 9 downto 0 loop	--now loop from the top down to determine the first instruction right before the
												--branch that matches the branch operand(s)
												
				if ROB_in(j).inst(11 downto 7) = ROB_in(i).inst(11 downto 7) and ROB_in(j).valid = '1' and ROB_in(j).complete = '1' and bnez = '1' and i > j then	--
					--its a BNEZ, the instruction dest_reg matches the branch register, the instruction results are "complete", and was issued just prior to the branch
					report "LAB_func: bnez. condition resolved.";
					reg1_resolved 		:= '1';
					if ROB_in(j).result /= "0000000000000000" then
						condition_met	:= '1';
					else
						condition_met	:= '0';
					end if;
					exit;
					
				elsif WB_IW_out(11 downto 7) = ROB_in(i).inst(11 downto 7) and i > j then	--
					
					report "LAB_func: bnez. WB_IW_out matches branch.";
					reg1_resolved 			:= reg1_resolved and '1';
					WB_IW_resolves_br 	:= WB_IW_resolves_br and '1';
					
					if WB_data_out /= "0000000000000000" then
						condition_met		:= '1';
					else
						condition_met		:= '0';
					end if;
					
				elsif WB_IW_out(11 downto 7) = ROB_in(i).inst(6 downto 2) and bne = '1' and i > j then	--
					
					report "LAB_func: bne. WB_IW_out matches branch.";
					reg2_resolved 			:= reg2_resolved and '1';
					WB_IW_resolves_br 	:= WB_IW_resolves_br and '1';
					
					if WB_data_out /= "0000000000000000" then
						condition_met		:= '1';
					else
						condition_met		:= '0';
					end if;	
					
				elsif WB_IW_out(11 downto 7) = ROB_in(i).inst(11 downto 7) and i > j and WB_IW_resolves_br = '0' then	--
					
					condition_met			:= '0';
					reg1_resolved 			:= '0';
					WB_IW_resolves_br 	:= '0'; --this ensures that additional instructions in ROB also matching WB_IW_out and that write back to register needed by branch can't resolve condition
				
				elsif WB_IW_out(11 downto 7) = ROB_in(i).inst(6 downto 2) and bne = '1' and i > j and WB_IW_resolves_br = '0' then	--
					
					condition_met			:= '0';
					reg2_resolved 			:= '0';
					WB_IW_resolves_br 	:= '0'; 
					
				elsif ROB_in(j).inst(11 downto 7) = ROB_in(i).inst(11 downto 7) and ROB_in(j).valid = '1' and ROB_in(j).complete = '0' and i > j then	--
						
					report "LAB_func: bnez. not resolved.";
					reg1_resolved 		:= '0';
					reg2_resolved 		:= '0';
					condition_met		:= '0';
					exit;
					
				elsif ROB_in(j).inst(11 downto 7) = ROB_in(i).inst(11 downto 7) and ROB_in(j).valid = '1' and ROB_in(j).complete = '1' and bne = '1' and i > j then	--
					reg1_resolved 		:= '1';
					reg1_slot			:= j;
					
				elsif ROB_in(j).inst(11 downto 7) = ROB_in(i).inst(6 downto 2) and ROB_in(j).valid = '1' and ROB_in(j).complete = '1' and bne = '1' and i > j then	--
					reg2_resolved 		:= '1';
					reg2_slot			:= j;
					
				elsif j = 0 and reg1_resolved = '0' and reg2_resolved = '1' then
					
					--check if reg1 valid in register file, at last checkable location in ROB for this data
					if RF_in_3_valid = '1' then	--
						--if its a BNE, the instruction dest_reg matches the branch register, the instruction results are "complete", and was issued just prior to the branch
						reg1_resolved 		:= '1';
						
						if reg2_slot < 10 and ROB_in(reg2_slot).result /= RF_in_3 then
							--write PM_data_in, which will now just be a memory address to jump to, to PC_reg somehow
							condition_met	:= '1';
							
						elsif reg2_slot = 10 and WB_data_out /= RF_in_3 and WB_IW_resolves_br = '1' then
							condition_met	:= '1';
							
						else
							--write PC_reg + 1 to PC_reg, branch condition not met
							condition_met	:= '0';
						end if;
					else
						reg1_resolved 		:= '0';
						condition_met		:= '0';
					end if;
					exit;
					
				elsif j = 0 and reg2_resolved = '0' and reg1_resolved = '1' and bne = '1' then
					--check if reg2 valid in register file, at last checkable location in ROB for this data
					if RF_in_4_valid = '1' then	--
						--if its a BNE, the instruction dest_reg matches the branch register, the instruction results are "complete", and was issued just prior to the branch
						reg2_resolved 		:= '1';
						
						if reg1_slot < 10 and ROB_in(reg1_slot).result /= RF_in_4 then
							--write PM_data_in, which will now just be a memory address to jump to, to PC_reg somehow
							condition_met	:= '1';
						
						elsif reg1_slot = 10 and WB_data_out /= RF_in_4 and WB_IW_resolves_br = '1' then
							condition_met	:= '1'; 
							
						else
							--write PC_reg + 1 to PC_reg, branch condition not met
							condition_met	:= '0';
						end if;
					else
						reg2_resolved 		:= '0';
						condition_met		:= '0';
					end if;
					exit;
					
				elsif j = 0 and RF_in_3_valid = '1' and bnez = '1' then
					report "LAB_func: (bnez) no dep inst in LAB and RF result is valid.";
					reg1_resolved 		:= '1';
					condition_met		:= '1';
					exit;
				
				elsif j = 0 and RF_in_3_valid = '1' and RF_in_4_valid = '1' and bne = '1' then
					--clearly there aren't any incomplete instructions for either reg1 or reg2 in ROB, or none exist, and RF 
					report "LAB_func: (bne) no dep insts in LAB and RF results are valid.";
					reg1_resolved 		:= '1';
					reg2_resolved 		:= '1';
					condition_met		:= '1';
					exit;
				
				else
					reg1_resolved 		:= '1';
					reg2_resolved 		:= '1';
					condition_met		:= '1';
				end if;	--ROB_in(j).inst(11 downto 7) = ROB_in(i).inst(11 downto 7) and ROB_in(j).valid = '1' and ROB_in(j).complete = '1' and bnez = '1' and i > j
			end loop; --j
			exit; --exit the outer "i" loop since we've found the corresponding branch instruction
		end if; --ROB_in(15 downto 12) = "1010"
	end loop; --for i
	
	--simple combinational logic for values to return
	return ((bne and reg1_resolved and reg2_resolved) or (bnez and reg1_resolved)) & condition_met;
	
	end function;


end package body LAB_functions;
