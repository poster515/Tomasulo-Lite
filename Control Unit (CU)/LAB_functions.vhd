library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all; 
use work.control_unit_types.all;
use work.ROB_functions.all;
 
package LAB_functions is 

	--function to update "branches", which manages all currently unresolved branch instructions
	function store_shift_branch_addr(	branches				: in branch_addrs;
													results_available	: in std_logic;
													addr_valid			: in std_logic;
													addr_met				: in std_logic_vector(15 downto 0);
													addr_unmet			: in std_logic_vector(10 downto 0);
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
												shift_LAB	: in std_logic			)
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
									ROB_in			: in ROB) 
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
		
	variable i 					: integer range 0 to 9;
	variable branches_temp	: branch_addrs := branches;
	
	begin
		for i in 0 to 9 loop
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
													addr_unmet			: in std_logic_vector(10 downto 0);
													ROB_DEPTH			: in integer)
		return branch_addrs is
		
		variable branches_temp	: branch_addrs;
		variable i 					: integer range 0 to 9;
		variable n_clear_zero	: integer range 0 to 1;
	begin
		n_clear_zero	:= convert_CZ(not(results_available));
	
		for i in 0 to ROB_DEPTH - 2 loop
			--condition covers when we get to a location in "branches" that isn't valid, i.e., we can buffer branch addresses there
			if branches_temp(i).addr_valid = '0' then
				--incoming instruction is a new, valid branch instruction and should be buffered 
				if addr_valid = '1' then
					branches_temp(i).addr_met 		:= addr_met;
					branches_temp(i).addr_unmet 	:= addr_unmet;
					branches_temp(i).addr_valid 	:= '1';
					exit;
				end if;
				
			--condition for when we've gotten to the last valid instruction in the branch_addrs
			elsif branches_temp(i).addr_valid = '1' and branches_temp(i + 1).addr_valid = '0' then
				
				if addr_valid = '1' then
					--n_clear_zero automatically shifts "branches" entries
					branches_temp(i + n_clear_zero).addr_met		:= addr_met;
					branches_temp(i + n_clear_zero).addr_unmet	:= addr_unmet;
					branches_temp(i + n_clear_zero).addr_valid 	:= '1';
					
					exit;
				end if;

			--condition for when the "branches" is full, we want to buffer incoming PM_data_in, and can clear the zeroth instruction (i.e., make room)
			elsif i = ROB_DEPTH - 2 and results_available = '1' and addr_valid = '1' then
				
				if addr_valid = '1' then
					
					branches_temp(ROB_DEPTH - 1).addr_met 		:= addr_met;
					branches_temp(ROB_DEPTH - 1).addr_unmet 	:= "00000" & addr_unmet;
					branches_temp(ROB_DEPTH - 1).addr_valid 	:= '1';
					
				end if;
			
			else
				--clear_zero automatically shifts ROB entries
				branches_temp(i) := branches_temp(i + convert_CZ(results_available));
				
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
												shift_LAB	: in std_logic	)
		return LAB_actual is
								
		variable i 			: integer 		:= issued_inst;	
		variable LAB_temp	: LAB_actual	:= LAB_in;
		
	begin
		
		for i in 0 to LAB_MAX - 2 loop
			if i >= issued_inst then
				if (LAB_temp(i).inst_valid = '1') and (LAB_temp(i + 1).inst_valid = '0') then
				
					LAB_temp(i).inst 							:= PM_data_in;
					LAB_temp(i + convert_SL(shift_LAB)).addr	:= (others => '0');
					
					if PM_data_in(15 downto 14) = "10" and ((PM_data_in(1) nand PM_data_in(0)) = '1') then
						LAB_temp(i + convert_SL(shift_LAB)).addr_valid	:= '0';
					else
						LAB_temp(i + convert_SL(shift_LAB)).addr_valid	:= '1';
					end if;
					
				elsif i = LAB_MAX - 2 and LAB_temp(i).inst_valid = '1' and LAB_temp(i + 1).inst_valid = '1' then
				
					LAB_temp(i + convert_SL(shift_LAB)).inst 		:= PM_data_in;
					LAB_temp(i + convert_SL(shift_LAB)).addr		:= (others => '0');
						
					if PM_data_in(15 downto 14) = "10" and ((PM_data_in(1) nand PM_data_in(0)) = '1') then
						LAB_temp(i + convert_SL(shift_LAB)).addr_valid	:= '0';
					else
						LAB_temp(i + convert_SL(shift_LAB)).addr_valid	:= '1';
					end if;
					
				else
					LAB_temp(i) := LAB_temp(i + convert_SL(shift_LAB));
				end if;
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
									ROB_in			: in ROB) 
		return std_logic_vector is --std_logic_vector([[condition met]], [[results ready]])
								
		variable i, j 				: integer 	:= 0;	
		variable reg1_resolved	: std_logic := '0';
		variable reg2_resolved	: std_logic := '0';
		variable condition_met	: std_logic := '0';
		variable ROB_DEPTH 		: integer 	:= 10;
	begin
		if RF_in_3_valid = '1' and bnez = '1' then
		
			reg1_resolved := '1'; 
			
			--have a BNEZ, need Reg1, which is in the RF 
			if RF_in_3 /= "0000000000000000" then
				--write PM_data_in, which will now just be a memory address to jump to, to PC_reg somehow
				condition_met	:= '1';
			else
				--write PC_reg + 1 to PC_reg, branch condition not met
				condition_met	:= '1';
			end if;
			
		elsif RF_in_3_valid = '1' and RF_in_4_valid = '1' and bne = '1' then
		
			reg1_resolved := '1'; 
			reg2_resolved := '1'; 
			
			--have a BNE, need both operands, which are both in the RF 
			if RF_in_3 /= RF_in_4 then
				--write PM_data_in, which will now just be a memory address to jump to, to PC_reg somehow
				condition_met	:= '1';
			else
				--write PC_reg + 1 to PC_reg, branch condition not met
				condition_met	:= '0';
			end if;
		else 			--don't have one or both results issued to RF yet. check ROB if results are buffered as "complete" there 
			for i in 0 to 9 loop
				if ROB_in(i).inst(15 downto 12) = "1010" and ROB_in(i).valid = '1' then	--we have the first branch instruction in ROB
					
					for j in 9 downto 0 loop	--now loop from the top down to determine the first instruction right before the
														--branch that matches the branch operand(s)
						if ROB_in(j).inst(11 downto 7) = ROB_in(i).inst(11 downto 7) and ROB_in(j).valid = '1' and ROB_in(j).complete = '1' and bnez = '1' and i > j then	--
							--its a BNEZ, the instruction dest_reg matches the branch register, the instruction results are "complete", and was issued just prior to the branch
							reg1_resolved 		:= '1';
							
							if ROB_in(j).result /= "0000000000000000" then
								condition_met	:= '1';
							else
								condition_met	:= '0';
							end if;
							
						else	--the above "if" handles all BNEZ instructions, this "else" handles all BNE instructions
							if RF_in_3_valid = '1' and RF_in_4_valid = '0' and bne = '1' then 
								--we know that the first register condition is resolved
								reg1_resolved 		:= '1';
								
								--we only need to find Reg2 value in ROB
								if ROB_in(j).inst(11 downto 7) = ROB_in(i).inst(6 downto 2) and ROB_in(j).valid = '1' and ROB_in(j).complete = '1' and bne = '1' and i > j then	--
									--if its a BNE, the instruction dest_reg matches the branch register, the instruction results are "complete", and was issued just prior to the branch
									reg2_resolved 		:= '1';
									
									if RF_in_3 /= ROB_in(j).result then
										--write PM_data_in, which will now just be a memory address to jump to, to PC_reg somehow
										condition_met	:= '1';
									else
										--write PC_reg + 1 to PC_reg, branch condition not met
										condition_met	:= '0';
									end if;
								end if;
								
							elsif RF_in_3_valid = '0' and RF_in_4_valid = '1' and bne = '1' then --we need to find RF_in_3 value in ROB
								--we only need to find Reg1 value in ROB
								reg2_resolved 		:= '1';
								
								if ROB_in(j).inst(11 downto 7) = ROB_in(i).inst(11 downto 7) and ROB_in(j).valid = '1' and ROB_in(j).complete = '1' and bne = '1' and i > j then	--
									--if its a BNE, the instruction dest_reg matches the branch register, the instruction results are "complete", and was issued just prior to the branch
									reg1_resolved 		:= '1';
									
									if RF_in_4 /= ROB_in(j).result then
										--write PM_data_in, which will now just be a memory address to jump to, to PC_reg somehow
										condition_met	:= '1';
									else
										--write PC_reg + 1 to PC_reg, branch condition not met
										condition_met	:= '0';
									end if;
								end if;
								
							elsif RF_in_3_valid = '0' and RF_in_4_valid = '0' and bne = '1' then --we need to find RF_in_3 value and RF_in_4 value in ROB
								
								if ROB_in(j).inst(11 downto 7) = ROB_in(i).inst(11 downto 7) and ROB_in(j).valid = '1' and ROB_in(j).complete = '1' and i > j then
									reg1_resolved := '1';

								elsif ROB_in(j).inst(11 downto 7) = ROB_in(i).inst(6 downto 2) and ROB_in(j).valid = '1' and ROB_in(j).complete = '1' and i > j then	
									reg2_resolved := '1';

								end if;
							end if;	--RF_in_3_valid = '1' and RF_in_4_valid = '0' and bne = '1'
						end if;	--ROB_in(j).inst(11 downto 7) = ROB_in(i).inst(11 downto 7) and ROB_in(j).valid = '1' and ROB_in(j).complete = '1' and bnez = '1' and i > j
					end loop; --j
				end if; --ROB_in(15 downto 12) = "1010"
			end loop; --for i
		end if; --RF_in_3_valid
		
		--simple combinational logic for values to return
		return ((bne and reg1_resolved and reg2_resolved) or (bnez and reg1_resolved)) & condition_met;
		
	end function;


end package body LAB_functions;
