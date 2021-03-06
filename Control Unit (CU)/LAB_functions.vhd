library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all; 
use work.control_unit_types.all;
use work.RF_top_functions.all;
 
package LAB_functions is 

	--function to update "branches", which manages all currently unresolved branch instructions
	function store_shift_branch_addr(	branches				: in branch_addrs;
													results_available	: in std_logic;
													addr_valid			: in std_logic;
													addr_met				: in std_logic_vector(15 downto 0);
													PC_reg				: in std_logic_vector(10 downto 0);
													ROB_DEPTH			: in integer)
		return branch_addrs;
	
	function compare_values(value1 : in std_logic_vector(15 downto 0);	
									value2 : in std_logic_vector(15 downto 0))
		return std_logic;
	
	--function which initializes LAB	tags									
	function init_LAB (	LAB_in	: in LAB_actual;
								LAB_MAX	: in integer		) 
		return LAB_actual; 
		
	function gtoet_issued_inst(	i				: in integer;
											issued_inst : in integer)
	return integer;
		
	function init_branches(	branches	: in branch_addrs;
									LAB_MAX	: in integer)
		return branch_addrs;
		
	function shiftLAB_and_bufferPM(	LAB_in		: in LAB_actual;
												PM_data_in	: in std_logic_vector(15 downto 0);
												issued_inst	: in integer;
												LAB_MAX		: in integer;
												shift_LAB	: in std_logic;
												br_ld_st_reg	: in std_logic	)
		return LAB_actual;
		
	--function to type convert std_logic to integer
	function convert_SL ( shift_LAB : in std_logic )
		return integer;
		
	function purge_insts(	LAB					: in LAB_actual;
									ROB_in				: in ROB;
									frst_branch_idx	: in integer	)
		return LAB_actual;
		
	function check_ROB_for_wrongly_fetched_insts(ROB_in				: in ROB;
																frst_branch_idx	: in integer;
																LAB_IW				: in std_logic_vector(15 downto 0);
																ID_IW					: in std_logic_vector(15 downto 0);
																EX_IW					: in std_logic_vector(15 downto 0);
																MEM_IW				: in std_logic_vector(15 downto 0))
		return std_logic_vector;
		
	function revalidate_RF_regs(	ROB_in				: in ROB;
											frst_branch_idx	: in integer;
											LAB_IW				: in std_logic_vector(15 downto 0);
											ID_IW					: in std_logic_vector(15 downto 0);
											EX_IW					: in std_logic_vector(15 downto 0);
											MEM_IW				: in std_logic_vector(15 downto 0);
											WB_IW_in				: in std_logic_vector(15 downto 0))
		return std_logic_vector;
	
	--function to determine if results of branch condition are ready	
	function results_ready( bne 				: in std_logic; 
									bnez				: in std_logic; 
									RF_in_3_valid 	: in std_logic;  
									RF_in_4_valid	: in std_logic;   
									RF_in_3			: in std_logic_vector(15 downto 0);
									RF_in_4			: in std_logic_vector(15 downto 0);
									ROB_in			: in ROB;
									WB_IW_out		: in std_logic_vector(15 downto 0);
									WB_data_out		: in std_logic_vector(15 downto 0);
									PM_data_in		: in std_logic_vector(15 downto 0);
									frst_branch_idx: in integer	) 
		return std_logic_vector; --std_logic_vector([[condition met]], [[results ready]])
		
	--function to determine whether the given LAB instruction is 1) a GPIO or I2C write and 2) speculative, so it doesn't get issued to pipeline
	function specul_write_haz(	ROB_in				: in ROB;
										LAB_i_inst 			: in std_logic_vector(15 downto 0);
										frst_branch_idx	: in integer)
		return std_logic;
		
	--function to determine whether the given LAB instruction requires result of any I2C read instruction
	function ION_read_hazard( 	ROB_in				: in ROB;
										LAB_i_inst 			: in std_logic_vector(15 downto 0)	)
		return std_logic;
		
	--function to determine whether a LAB instruction conflicts with instructions below it
	function LAB_datahaz(	LAB	: in LAB_actual;
									index	: in integer;
									LAB_MAX	: in integer	)
		return std_logic;
	
	--function to determine whether a LAB instruction conflicts with instructions in pipeline
	function PL_datahaz(	LAB_inst		: in std_logic_vector(15 downto 0);
								ID_IW			: in std_logic_vector(15 downto 0);
								EX_IW 		: in std_logic_vector(15 downto 0);
								MEM_IW 		: in std_logic_vector(15 downto 0);
								ID_reset		: in std_logic;
								EX_reset 	: in std_logic;
								MEM_reset 	: in std_logic;
								reg2_used 	: in std_logic;
								ROB_in		: in ROB;
								frst_branch_idx : in integer;
								LAB_MAX		: in integer)
		return std_logic;
	
--called whenever we're evaluating the particular LAB isntruction	
	function is_reg2_used(LAB_i_in		: in std_logic_vector(15 downto 0))
	
		return std_logic;
	
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
	
	function compare_values(value1 : in std_logic_vector(15 downto 0);	
									value2 : in std_logic_vector(15 downto 0))
		return std_logic is 
	
	begin
		if value1 /= value2 then
			return '1';
		else
			return '0';
		end if;
		
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
	function shiftLAB_and_bufferPM(	LAB_in			: in LAB_actual;
												PM_data_in		: in std_logic_vector(15 downto 0);
												issued_inst		: in integer; --location of instruction that was issued, start shift here
												LAB_MAX			: in integer;
												shift_LAB		: in std_logic;
												br_ld_st_reg	: in std_logic	)
		return LAB_actual is
								
		variable i 			: integer 		:= issued_inst;	
		variable LAB_temp	: LAB_actual	:= LAB_in;
		variable address_updated 			: std_logic := '0';
		variable target	: integer 		:= 0;
		
	begin
		
		for i in 0 to LAB_MAX - 1 loop

			target := i + gtoet_issued_inst(i, issued_inst);
			--report "LAB_func: target = " & integer'image(target) & ", i = " & integer'image(i);
			
			if target < 5 then
				if br_ld_st_reg = '1' and LAB_temp(target).addr_valid = '0' and address_updated = '0' then
					--report "LAB_func: 1. i = " & integer'image(i) & ", target = " & integer'image(target);
					address_updated			:= '1';
					LAB_temp(i).addr 			:= PM_data_in;
					LAB_temp(i).addr_valid 	:= '1';
					LAB_temp(i).inst 			:= LAB_temp(target).inst;
					LAB_temp(i).inst_valid 	:= LAB_temp(target).inst_valid;
					
				elsif address_updated = '0' then
					
					if LAB_temp(target).inst_valid = '0' and PM_data_in(15 downto 12) /= "1010" and PM_data_in(15 downto 12) /= "1001" and br_ld_st_reg = '0'then
						--report "LAB_func: 2. i = " & integer'image(i) & ", target = " & integer'image(target);
						LAB_temp(i).inst 			:= PM_data_in;
						LAB_temp(i).inst_valid 	:= '1';
						LAB_temp(i).addr 			:= (others => '0');
						LAB_temp(i).addr_valid 	:= not(PM_data_in(15) and not(PM_data_in(14)) and not(PM_data_in(13)) and not(PM_data_in(12)));
						address_updated			:= '1';
					else
						--report "LAB_func: 3. i = " & integer'image(i) & ", target = " & integer'image(target);
						LAB_temp(i)					:= LAB_temp(target);
					end if;
				
				else
					--report "LAB_func: 4. i = " & integer'image(i) & ", target = " & integer'image(target);
					LAB_temp(i)						:= LAB_temp(target);
					
				end if;
			elsif target = 5 then
				if address_updated = '0' and PM_data_in(15 downto 12) /= "1010" and PM_data_in(15 downto 12) /= "1001" and br_ld_st_reg = '0' then
					--report "LAB_func: 5. i = " & integer'image(i) & ", target = " & integer'image(target);
					LAB_temp(4).inst 			:= PM_data_in;
					LAB_temp(4).inst_valid 	:= '1';
					LAB_temp(4).addr 			:= (others => '0');
					LAB_temp(4).addr_valid 	:= not(PM_data_in(15) and not(PM_data_in(14)) and not(PM_data_in(13)) and not(PM_data_in(12)));
					address_updated 			:= '1' ;
				elsif shift_LAB = '1' then
					--report "LAB_func: 7. i = " & integer'image(i) & ", target = " & integer'image(target);
					LAB_temp(4)					:= ((others => '0'), '0', (others => '0'), '1');
				else
					--report "LAB_func: 6. i = " & integer'image(i) & ", target = " & integer'image(target);
					LAB_temp(4)					:= LAB_temp(4);
				end if;
			end if;
		end loop; --for i
		
		return LAB_temp; --come here if there are no spots available
	end function;
	
	function gtoet_issued_inst(	i				: in integer;
											issued_inst : in integer)
		return integer is
		
	begin
	
		if i >= issued_inst then
			return 1;
		else
			return 0;
		end if;
		
	end;

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
	
	--function to purge LAB of all instructions that were incorrectly fetched as part of speculative branch execution
	function purge_insts(	LAB					: in LAB_actual;
									ROB_in				: in ROB;
									frst_branch_idx	: in integer)
		return LAB_actual is
		
		variable i, j							: integer 		:= 0;	
		variable LAB_temp						: LAB_actual 	:= LAB;
		
	begin
		
		for j in 0 to 8 loop
			for i in 0 to 4 loop
				if frst_branch_idx + j < 10 then
					if ROB_in(frst_branch_idx + j).inst = LAB_temp(i).inst and LAB_temp(i).inst_valid = '1' and ROB_in(frst_branch_idx + j).valid = '1' then
					--clear all subsequent instructions from LAB
						LAB_temp(i).inst				:= "0000000000000000";
						LAB_temp(i).inst_valid		:= '0';
						LAB_temp(i).addr				:= "0000000000000000";
						LAB_temp(i).addr_valid		:= '1';
						
					else 
						LAB_temp(i) := LAB_temp(i);
						
					end if;
				end if;
			end loop; --i
		end loop;	--j
		
		return LAB_temp;
	
	end;
	
	--function to determine if incorrectly, speculatively fetched instructions are in pipeline 
	--returns std_logic_vector(3 downto 0) = | LAB_IW | ID_IW | EX_IW | MEM_IW |
	
	function check_ROB_for_wrongly_fetched_insts(ROB_in				: in ROB;
																frst_branch_idx	: in integer;
																LAB_IW				: in std_logic_vector(15 downto 0);
																ID_IW					: in std_logic_vector(15 downto 0);
																EX_IW					: in std_logic_vector(15 downto 0);
																MEM_IW				: in std_logic_vector(15 downto 0))
		return std_logic_vector is
		
		variable i		: integer 	:= 0;	
		variable temp 	: std_logic_vector(0 to 2) := "000";
		
	begin 
	
		for i in 0 to 9 loop
			if i >= frst_branch_idx then
				if ROB_in(i).inst = ID_IW then
					temp := temp or "100";
					--report "LAB_func: LAB_IW_out matches " & integer'image(i) & "th ROB inst";
				elsif ROB_in(i).inst = EX_IW then
					temp := temp or "010";
					--report "LAB_func: ID_IW_out matches " & integer'image(i) & "th ROB inst";
				elsif ROB_in(i).inst = MEM_IW then
					temp := temp or "001";
					
				end if;
			end if;
		end loop;
		
		return temp;
	end;
	
	--this function will generate a 32-bit revalidation vector for the RF based on registers in the pipeline that were wrongly fetched and executed
	function revalidate_RF_regs(	ROB_in				: in ROB;
											frst_branch_idx	: in integer;
											LAB_IW	: in std_logic_vector(15 downto 0);
											ID_IW		: in std_logic_vector(15 downto 0);
											EX_IW		: in std_logic_vector(15 downto 0);
											MEM_IW	: in std_logic_vector(15 downto 0);
											WB_IW_in : in std_logic_vector(15 downto 0))
		return std_logic_vector is
		
		variable i			: integer					:= 0;
		variable temp_L	: unsigned(31 downto 0) := "00000000000000000000000000000000";
		variable temp_I	: unsigned(31 downto 0) := "00000000000000000000000000000000";
		variable temp_E	: unsigned(31 downto 0) := "00000000000000000000000000000000";
		variable temp_M	: unsigned(31 downto 0) := "00000000000000000000000000000000";
		variable temp_W	: unsigned(31 downto 0) := "00000000000000000000000000000000";
		variable temp_R	: unsigned(31 downto 0) := "00000000000000000000000000000000"; --represents speculative instructions in ROB that have already been completed before branch cond determined
		
		variable one		: unsigned(31 downto 0) := "00000000000000000000000000000001";
	begin
	
		for i in 0 to 9 loop
			if i > frst_branch_idx then
				if ROB_in(i).inst = LAB_IW then
					temp_L := shift_left(one, to_integer(unsigned(LAB_IW(11 downto 7))));
					--report "LAB_func: revalidating reg " & integer'image(to_integer(unsigned(LAB_IW(11 downto 7))));
				elsif ROB_in(i).inst = ID_IW then
					temp_I := shift_left(one, to_integer(unsigned(ID_IW(11 downto 7))));
					--report "LAB_func: revalidating reg " & integer'image(to_integer(unsigned(ID_IW(11 downto 7))));
				elsif ROB_in(i).inst = EX_IW then
					temp_E := shift_left(one, to_integer(unsigned(EX_IW(11 downto 7))));
					--report "LAB_func: revalidating reg " & integer'image(to_integer(unsigned(EX_IW(11 downto 7))));
				elsif ROB_in(i).inst = MEM_IW then
					temp_M := shift_left(one, to_integer(unsigned(MEM_IW(11 downto 7))));
					--report "LAB_func: revalidating reg " & integer'image(to_integer(unsigned(MEM_IW(11 downto 7))));
				elsif ROB_in(i).inst = WB_IW_in then
					temp_W := shift_left(one, to_integer(unsigned(WB_IW_in(11 downto 7))));
					--report "LAB_func: revalidating reg " & integer'image(to_integer(unsigned(WB_IW_in(11 downto 7))));
				elsif i > frst_branch_idx and ROB_in(i).valid = '1' then --need to revalidate complete, speculative registers in ROB
					temp_R := temp_R or shift_left(one, to_integer(unsigned(ROB_in(i).inst(11 downto 7))));
					--report "LAB_func: revalidating reg " & integer'image(to_integer(unsigned(ROB_in(i).inst(11 downto 7))));
				end if;
			end if;
		end loop;	--i
	
		return std_logic_vector(temp_L or temp_I or temp_E or temp_M or temp_W or temp_R);
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
									WB_data_out		: in std_logic_vector(15 downto 0);
									PM_data_in		: in std_logic_vector(15 downto 0);
									frst_branch_idx: in integer	) 
									
		return std_logic_vector is --std_logic_vector([[results ready]], [[condition met]])
								
		variable j		 					: integer 	:= 0;	
		variable reg1_slot, reg2_slot	: integer 	:= 9;	
		variable reg1_resolved			: std_logic := '1';
		variable reg2_resolved			: std_logic := '1';
		variable condition_met			: std_logic := '1';
		variable reg1_encountered		: std_logic := '0'; 	--signifies that an instruction containing reg1 associated with
																				--branch have been encountered - will be set upon first encounter
		variable reg2_encountered		: std_logic := '0'; 	--signifies that an instruction containing reg2 associated with
																				--branch have been encountered - will be set upon first encounter
		variable WB_IW_resolves_br		: std_logic	:= '1';	--starts high and only goes low if an incomplete instruction in ROB matches MEM_WB_IW
		
	begin

	if frst_branch_idx < 10 then
		--report "LAB_func: should have branch in ROB...";
		
		if ROB_in(frst_branch_idx).inst(15 downto 12) = "1010" and ROB_in(frst_branch_idx).valid = '1' then	--we have the first branch instruction in ROB
			--report "LAB_func: found branch in ROB!";
			--report "LAB_func: frst_branch_idx = " & integer'image(frst_branch_idx);
			for j in 9 downto 0 loop
				
				if ROB_in(frst_branch_idx).inst(11 downto 7) = ROB_in(j).inst(11 downto 7) and ROB_in(j).valid = '1' and ROB_in(j).complete = '0' and frst_branch_idx > j then
					reg1_resolved		:= '0';
					condition_met		:= '0';
					--report "LAB_func: reg1 results not ready - exiting. j = " & integer'image(j);
					exit; --exit here since the operand dependency closest to branch isn't complete - therefore we can't know outcome of evaluation
					
				elsif ROB_in(frst_branch_idx).inst(6 downto 2) = ROB_in(j).inst(11 downto 7) and ROB_in(j).valid = '1' and ROB_in(j).complete = '0' and frst_branch_idx > j and bne = '1' then
					reg2_resolved		:= '0';
					condition_met		:= '0';
					--report "LAB_func: reg2 results not ready - exiting. j = " & integer'image(j);
					exit; --exit here since the operand dependency closest to branch isn't complete - therefore we can't know outcome of evaluation
				
				elsif ROB_in(frst_branch_idx).inst(11 downto 7) = ROB_in(j).inst(11 downto 7) and ROB_in(j).valid = '1' and ROB_in(j).complete = '1' and frst_branch_idx > j then	--
					--the instruction dest_reg matches the branch register, the instruction results are "complete", and was issued just prior to the branch
					--report "LAB_func: reg1 condition resolved, j = " & integer'image(j);
					
					if reg1_encountered = '0' then
						--report "LAB_func: reg1 located at slot " & integer'image(j);
						reg1_slot			:= j;
						reg1_encountered	:= '1';
					else
						reg1_slot			:= reg1_slot;
					end if;
					
					--in the rare case that the instruction in the ROB is a BNE using the same register...
					if ROB_in(frst_branch_idx).inst(6 downto 2) = ROB_in(j).inst(11 downto 7) and bne = '1'then	--
						--its a BNEZ, the instruction dest_reg matches the branch register, the instruction results are "complete", and was issued just prior to the branch
						--report "LAB_func: reg2 condition also resolved, j = " & integer'image(j);
						
						if reg2_encountered = '0' then
							--report "LAB_func: reg2 located at slot " & integer'image(j);
							reg2_slot			:= j;
							reg2_encountered	:= '1';
						else
							reg2_slot			:= reg2_slot;
						end if;
					end if;
					
				elsif ROB_in(frst_branch_idx).inst(6 downto 2) = ROB_in(j).inst(11 downto 7) and ROB_in(j).valid = '1' and ROB_in(j).complete = '1' and frst_branch_idx > j and bne = '1' then	--
					--its a BNEZ, the instruction dest_reg matches the branch register, the instruction results are "complete", and was issued just prior to the branch
					--report "LAB_func: reg1 condition resolved, j = " & integer'image(j);
					--probably don't need the redundant, below line
					--reg2_resolved 		:= reg1_resolved and '1';
					
					if reg2_encountered = '0' then
						--report "LAB_func: reg2 located at slot " & integer'image(j);
						reg2_slot			:= j;
						reg2_encountered	:= '1';
					else
						reg2_slot			:= reg2_slot;
					end if;
					
				elsif j = 0 then
				
					--since reg1_resolved and reg2_resolved have, thus far, only represented ROB entries, now we need to check WB_IW_out and RF entries
					if reg1_resolved = '1' and reg2_resolved = '1' then
						--then we have all necessary info in ROB - need to check ROB output though since it can be writing back a branch condition register this cycle
						--report "LAB_func: reg1 and reg2 resolved.";
						
						if WB_IW_out(11 downto 7) = ROB_in(frst_branch_idx).inst(11 downto 7) then	--
						--WB is writing back to reg1 - evaluate now for condition
							report "LAB_func: WB IW matches ROB bnez branch.";
							
							if WB_data_out /= "0000000000000000" and bnez = '1' then
								condition_met		:= '1';
								report "LAB_func: WB_data_out is not zero.";
							elsif WB_IW_out(11 downto 7) = ROB_in(frst_branch_idx).inst(6 downto 2) and bne = '1' then
								condition_met 		:= '0';
								report "LAB_func: WB_data_out dest_reg used for both BNE registers.";
							elsif WB_data_out /= ROB_in(reg2_slot).result and bne = '1' and reg2_encountered = '1' then
								condition_met 		:= '1';
								report "LAB_func: WB_data_out is not equal to reg2 (in ROB).";
							elsif WB_data_out /= RF_in_4 and bne = '1' and reg2_encountered = '0' and RF_in_4_valid = '1' then
								condition_met 		:= '1';
								report "LAB_func: WB_data_out is not equal to reg2 (in RF).";
							else
								condition_met		:= '0';
								report "LAB_func: WB_data_out dest_reg may be used for both BNE registers.";
							end if;
							
							exit;
							
						elsif WB_IW_out(11 downto 7) = ROB_in(frst_branch_idx).inst(6 downto 2) and bne = '1' then	--
						--WB is writing back to reg2 - evaluate now for condition
							--report "LAB_func: WB IW matches ROB bne branch.";
							if WB_data_out /= ROB_in(reg1_slot).result and reg1_encountered = '1' then
								condition_met 		:= '1';
								report "LAB_func: WB_data_out is NOT equal to reg2.";
							elsif WB_data_out /= RF_in_3 and reg1_encountered = '0' and RF_in_3_valid = '1' then
								condition_met 		:= '1';
								report "LAB_func: WB_data_out is not equal to reg2 (in RF).";
							else
								condition_met		:= '0';
								report "LAB_func: WB_data_out is ??";
							end if;
							
							exit;
							
						else
							--if we're here, we've got both registers valid in the register file
							if RF_in_3 /= RF_in_4 and reg1_encountered = '0' and reg2_encountered = '0' and RF_in_3_valid = '1' and RF_in_4_valid = '1' and bne = '1' then
								condition_met 		:= '1';
								report "LAB_func: RF_in_3 is not equal to RF_in_4 (in RF).";
							elsif RF_in_3 /= "0000000000000000" and reg1_encountered = '0' and RF_in_3_valid = '1' and bnez = '1' then
								condition_met 		:= '1';
								report "LAB_func: RF_in_3 is not equal to 0 (in RF).";
							else
								condition_met		:= '0';
								report "LAB_func: WB_data_out is ??";
							end if;
							
							exit;
							
						end if;
						
					elsif reg1_resolved = '0' then
						--shouldn't be able to get here, but just exit.
						--report "LAB_func: reg2 results not ready - exiting. j = " & integer'image(j);
						exit; --exit here since the operand dependency closest to branch isn't complete - therefore we can't know outcome of evaluation
						
					elsif reg2_resolved = '0' and bne = '1' then
						--shouldn't be able to get here, but just exit.
						--report "LAB_func: reg2 results not ready - exiting. j = " & integer'image(j);
						exit; --exit here since the operand dependency closest to branch isn't complete - therefore we can't know outcome of evaluation
					
					end if;
				else
					--report "LAB_func: Can't match a single LAB instruction to ROB? j = " & integer'image(j);
				
				end if;
			end loop;
		else
			--report "LAB_func: Can't find first branch?";
		end if;
	else

	end if;

	--simple combinational logic for values to return
	return ((bne and reg1_resolved and reg2_resolved) or (bnez and reg1_resolved)) & condition_met;
	
	end function;
	
	--function to determine whether the given LAB instruction is 1) a GPIO or I2C write and 2) speculative, so it doesn't get issued to pipeline
	function specul_write_haz( ROB_in				: in ROB;
										LAB_i_inst 			: in std_logic_vector(15 downto 0);
										frst_branch_idx	: in integer)
		return std_logic is
		
		variable i	: integer	:= 0;
	begin
		for i in 0 to 9 loop
			if (ROB_in(i).inst = LAB_i_inst and ((LAB_i_inst(15 downto 12) = "1011" and LAB_i_inst(0) = '1') or (LAB_i_inst(15 downto 12) = "1000" and LAB_i_inst(1) = '1'))) then
				if i > frst_branch_idx then
					--if we're above the branch location (i.e., speculative area), and that's where this LAB instruction is, and it's a GPIO or I2C write, then we can't issue it
					return '1';
				else
					return '0';
				end if;
			end if;
		end loop;
		
		return '0';
		
	end function;
	
	--function to determine whether the given LAB instruction requires result of any I2C read instruction
	function ION_read_hazard( 	ROB_in				: in ROB;
										LAB_i_inst 			: in std_logic_vector(15 downto 0)	)
		return std_logic is
		
		variable i	: integer	:= 0;
	begin
		for i in 0 to 9 loop
			if ROB_in(i).inst(15 downto 12) = "1011" and ROB_in(i).inst(1 downto 0) = "10" and 
				(ROB_in(i).inst(11 downto 7) = LAB_i_inst(11 downto 7) or ROB_in(i).inst(11 downto 7) = LAB_i_inst(6 downto 2)) then
				
				return '1';
			else
				return '0';
			end if;
		end loop;
		
		return '0';
		
	end function;
	
	--function to determine whether a LAB instruction conflicts with instructions below it
	function LAB_datahaz(	LAB		: in LAB_actual;
									index		: in integer;
									LAB_MAX	: in integer)
		return std_logic is
		
		variable dh_ptr_outer, dh_ptr_inner	: integer := 0;
		
	begin
	
		dh_ptr_outer := index; 
		if index = 0 then
			return '0';
		else
			for dh_ptr_inner in 0 to LAB_MAX - 2 loop
		
				if (
						(LAB(dh_ptr_inner).inst(11 downto 7) 	= LAB(dh_ptr_outer).inst(11 downto 7)) or 
						 
						(LAB(dh_ptr_inner).inst(11 downto 7) 	= LAB(dh_ptr_outer).inst(6 downto 2)) or 
						
						(LAB(dh_ptr_inner).inst(6 downto 2) = LAB(dh_ptr_outer).inst(6 downto 2) and 
						 LAB(dh_ptr_inner).inst(15 downto 12) 	= "1000" and 
						 LAB(dh_ptr_outer).inst(15 downto 12) 	= "1000") or
						 
						(LAB(dh_ptr_inner).inst(6 downto 2) = LAB(dh_ptr_outer).inst(11 downto 7) and 
						 LAB(dh_ptr_inner).inst(15 downto 12) 	= "1000")
						 
					) and dh_ptr_inner < dh_ptr_outer and LAB(dh_ptr_outer).inst_valid = '1' and LAB(dh_ptr_inner).inst_valid = '1' then
					
					return '1';
				end if;
			end loop; --dh_ptr_inner 
		end if;
	
		return '0';
	end function;
	
	--function to determine whether a LAB instruction conflicts with instructions in pipeline
	function PL_datahaz(	LAB_inst		: in std_logic_vector(15 downto 0);
								ID_IW			: in std_logic_vector(15 downto 0);
								EX_IW 		: in std_logic_vector(15 downto 0);
								MEM_IW 		: in std_logic_vector(15 downto 0);
								ID_reset		: in std_logic;
								EX_reset 	: in std_logic;
								MEM_reset 	: in std_logic;
								reg2_used 	: in std_logic;
								ROB_in		: in ROB;
								frst_branch_idx : in integer;
								LAB_MAX		: in integer)
		return std_logic is
		
		variable I2C_hazard, ID_hazard, EX_hazard, MEM_hazard : std_logic	:= '0';
	begin
--		report "LAB_func: ID_IW = " & integer'image(convert_SL(ID_IW(15))) & integer'image(convert_SL(ID_IW(14))) & integer'image(convert_SL(ID_IW(13))) & integer'image(convert_SL(ID_IW(12))) &
--					", EX_IW = " & integer'image(convert_SL(EX_IW(15))) & integer'image(convert_SL(EX_IW(14))) & integer'image(convert_SL(EX_IW(13))) & integer'image(convert_SL(EX_IW(12))) & 
--					", MEM_IW = " & integer'image(convert_SL(MEM_IW(15))) & integer'image(convert_SL(MEM_IW(14))) & integer'image(convert_SL(MEM_IW(13))) & integer'image(convert_SL(MEM_IW(12)));
		
		if (  ((ID_IW(11 downto 7) = LAB_inst(11 downto 7) or (ID_IW(11 downto 7) = LAB_inst(6 downto 2) and reg2_used = '1')) and ID_IW(15 downto 12) /= "1111" and not(ID_IW(15 downto 12) = "1000" and ID_IW(1) = '1')) or
				--if reg1 = reg1 or reg1 = reg2 and it's a valid IW and it's not a store											
				(ID_IW(6 downto 2) = LAB_inst(6 downto 2) and ID_IW(15 downto 12) = "1000" and ID_IW(1 downto 0) = "10" and LAB_inst(15 downto 12) = "1000" and LAB_inst(1 downto 0) = "00")) 
				--if reg2 = reg2 and its a store followed by a load
--			
--			(
--				(ID_IW(11 downto 7) = LAB_inst(11 downto 7)) or 
--				 
--				(ID_IW(11 downto 7) = LAB_inst(6 downto 2)) or 
--				
--				(ID_IW(6 downto 2) = LAB_inst(6 downto 2) and ID_IW(15 downto 12) = "1000" and LAB_inst(15 downto 12) = "1000" and ID_IW(1 downto 0) = "10" and LAB_inst(1 downto 0) = "00") or
--				 
--				(ID_IW(6 downto 2) = LAB_inst(11 downto 7) and ID_IW(15 downto 12) = "1000")
--				 
--			)
			
			and ID_reset = '1' then	
			
			ID_hazard		:= '1';
		else
			ID_hazard		:= '0';
		end if;
		
		--don't enable GPIO or I2C reads to be data forwarded because that functionality isn't available
		if (EX_IW(11 downto 7) = LAB_inst(11 downto 7) or (EX_IW(11 downto 7) = LAB_inst(6 downto 2) and reg2_used = '1')) and 
			EX_IW(15 downto 12) = "1011" and EX_IW(0) = '0' and EX_reset = '1' then	
			
			EX_hazard		:= '1';
		else
			EX_hazard		:= '0';
		end if;
		
		--if either registers match, as appropriate, raise MEM_hazard
		if (MEM_IW(11 downto 7) = LAB_inst(11 downto 7) or (MEM_IW(11 downto 7) = LAB_inst(6 downto 2) and reg2_used = '1')) and 
			MEM_IW(15 downto 12) /= "1111" and MEM_reset = '1' then
			
			MEM_hazard := '1';
		else
			MEM_hazard := '0';
		end if;
		
		--section below handles I2C hazards. if there is an issued I2C read, or there is currently an I2C op running 
		if ((ID_IW(11 downto 7) = LAB_inst(11 downto 7) or (ID_IW(11 downto 7) = LAB_inst(6 downto 2) and reg2_used = '1')) and ID_IW(15 downto 12) = "1011" and ID_IW(1 downto 0) = "10" and ID_reset = '1') or
			((EX_IW(11 downto 7) = LAB_inst(11 downto 7) or (EX_IW(11 downto 7) = LAB_inst(6 downto 2) and reg2_used = '1')) and EX_IW(15 downto 12) = "1011" and EX_IW(1 downto 0) = "10" and EX_reset = '1') or
			((MEM_IW(11 downto 7) = LAB_inst(11 downto 7) or (MEM_IW(11 downto 7) = LAB_inst(6 downto 2) and reg2_used = '1')) and MEM_IW(15 downto 12) = "1011" and MEM_IW(1 downto 0) = "10" and MEM_reset = '1') then
			
			--can't issue an I2C instruction if there is another I2C operation currently in pipeline
			I2C_hazard := '1';
		else
			--since IW may not be in pipeline (running in ION), need to determine if this LAB instruction is a speculative I2C read
			I2C_hazard := ION_read_hazard(ROB_in, LAB_inst);
		end if;
--			report "LAB_func: I2C_h = " & integer'image(convert_SL(I2C_hazard)) & ", ID_h = " & integer'image(convert_SL(ID_hazard)) & ", EX_h = " & integer'image(convert_SL(EX_hazard))
--						 & ", MEM_h = " & integer'image(convert_SL(MEM_hazard)) & ", GPIO_h = " & integer'image(convert_SL(ION_write_specul(ROB_in, LAB_inst, frst_branch_idx))); 
					 
		return (I2C_hazard or ID_hazard or EX_hazard or MEM_hazard or specul_write_haz(ROB_in, LAB_inst, frst_branch_idx));

	end function;
	
	function is_reg2_used(LAB_i_in		: in std_logic_vector(15 downto 0))
	
		return std_logic is
	
	begin
	
		if ((not(LAB_i_in(15)) and not(LAB_i_in(1)) and not(LAB_i_in(0))) or 
			(not(LAB_i_in(15)) and LAB_i_in(14) and not(LAB_i_in(1))) or
			(LAB_i_in(15) and not(LAB_i_in(14)) and not(LAB_i_in(13)) and not(LAB_i_in(12)) and not(LAB_i_in(0))) or 
			(LAB_i_in(15) and LAB_i_in(14) and not(LAB_i_in(13)) and LAB_i_in(12))) = '1' then
			
			return '1';
			
		else
			return '0';
			
		end if;
	
	end function;
end package body LAB_functions;
