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
	
	function compare_values(value1 : in std_logic_vector(15 downto 0);	
									value2 : in std_logic_vector(15 downto 0))
		return std_logic;
	
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
		
	function purge_insts(	LAB					: in LAB_actual;
									ROB_in				: in ROB;
									frst_branch_idx	: in integer	)
		return LAB_actual;
		
	function check_ROB_for_wrongly_fetched_insts(ROB_in	: in ROB;
																LAB_IW	: in std_logic_vector(15 downto 0);
																ID_IW		: in std_logic_vector(15 downto 0);
																EX_IW		: in std_logic_vector(15 downto 0);
																MEM_IW	: in std_logic_vector(15 downto 0))
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
		variable address_updated : std_logic := '0';
		
	begin
		
		not_SL := convert_SL(not(shift_LAB));
		
		for i in 0 to LAB_MAX - 2 loop
			--need to ensure that we're above last issued instruction, and instruction isn't a jump, and isn't a memory address for a load/store instruction
			if i >= issued_inst and PM_data_in(15 downto 12) /= "1001" and PM_data_in(15 downto 12) /= "1010" and ld_st_reg = '0' then
				
				if LAB_temp(i).inst_valid = '1' and LAB_temp(i + 1).inst_valid = '0' then
				
					if address_updated = '0' then
					
						report "LAB_func: At LAB spot " & integer'image(i + convert_SL(not(shift_LAB))) & " we can buffer PM_data_in";
						LAB_temp(i + not_SL).inst 			:= PM_data_in;
						LAB_temp(i + not_SL).inst_valid 	:= '1';
						LAB_temp(i + not_SL).addr			:= (others => '0');
						
						if PM_data_in(15 downto 12) = "1000" then
							LAB_temp(i + not_SL).addr_valid	:= '0';
						else
							LAB_temp(i + not_SL).addr_valid	:= '1';
						end if;
						exit;
					else
						report "LAB_func: 6. at " & Integer'image(i) & " shift entry from " & Integer'image(i + convert_SL(shift_LAB));
						LAB_temp(i) := LAB_temp(i + convert_SL(shift_LAB));
						exit;
						
					end if;
					
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
					
					if shift_LAB = '1' then
						--we're at the last spot in the LAB and need to provide zeros for last entry
						LAB_temp(i).inst				:= "0000000000000000";
						LAB_temp(i).inst_valid		:= '0';
						LAB_temp(i).addr				:= "0000000000000000";
						LAB_temp(i).addr_valid		:= '1';
						exit;
					end if;
					
					exit;
				
				else
					report "LAB_func: 4. at " & Integer'image(i) & " shift entry from " & Integer'image(i + convert_SL(shift_LAB));
					LAB_temp(i) := LAB_temp(i + convert_SL(shift_LAB));
				end if;
			------------------------EXPERIMENTAL-----------------------------	
			elsif ld_st_reg = '1' then
		
				if LAB_temp(i).inst(15 downto 12) = "1000" and LAB_temp(i).addr_valid = '0' and LAB_temp(i).inst_valid = '1' and address_updated = '0' then 
					--((LAB_temp(i).inst_valid = '1' and LAB_temp(i + 1).inst_valid = '0') or i = LAB_MAX - 1) then
					report "LAB_func: 78. At spot " & integer'image(i) & " buffer mem address";
					LAB_temp(i).inst 			:= LAB_temp(i).inst;
					LAB_temp(i).inst_valid 	:= LAB_temp(i).inst_valid;
					LAB_temp(i).addr 			:= PM_data_in;
					LAB_temp(i).addr_valid 	:= '1';
					address_updated			:= '1';

				elsif LAB_temp(i + 1).inst(15 downto 12) = "1000" and LAB_temp(i + 1).addr_valid = '0' and LAB_temp(i + 1).inst_valid = '1' and address_updated = '0' then
					--if ld_st_reg = '1', we know PM_data_in is the address of the first load/store encountered with an invalid address field
					report "LAB_func: 76. encountered load/store. shifting instruction";
					LAB_temp(i + not_SL).inst 			:= LAB_temp(i + 1).inst;
					LAB_temp(i + not_SL).inst_valid 	:= LAB_temp(i + 1).inst_valid;
					LAB_temp(i + not_SL).addr			:= PM_data_in;
					LAB_temp(i + not_SL).addr_valid 	:= '1';
					address_updated						:= '1';
					
					if i + 1 = LAB_MAX - 1 and shift_LAB = '1' then
						--we're at the last spot in the LAB and need to provide zeros for last entry
						report "LAB_func: 234. at end of LAB, writing in 0s.";
						
						LAB_temp(i + 1).inst				:= "0000000000000000";
						LAB_temp(i + 1).inst_valid		:= '0';
						LAB_temp(i + 1).addr				:= "0000000000000000";
						LAB_temp(i + 1).addr_valid		:= '1';
						exit;
					end if;
				
				else
					if i + 1 = LAB_MAX - 1 and shift_LAB = '1' then
						--we're at the last spot in the LAB and need to provide zeros for last entry
						report "LAB_func: 264. at end of LAB, writing in 0s.";
						LAB_temp(i + 1).inst				:= "0000000000000000";
						LAB_temp(i + 1).inst_valid		:= '0';
						LAB_temp(i + 1).addr				:= "0000000000000000";
						LAB_temp(i + 1).addr_valid		:= '1';
						exit;
					else
						--report "LAB_func: 69. at " & Integer'image(i) & " shift entry from " & Integer'image(i + convert_SL(shift_LAB));
						LAB_temp(i) := LAB_temp(i + convert_SL(shift_LAB));
					end if;
				end if;
			------------------------END EXPERIMENTAL-----------------------------	

			--need to handle case where we don't want to buffer PM_data_in (i.e., jumps and branches) but still want to shift LAB down and issue LAB(0)
			else
				if i >= issued_inst then
					--report "LAB_func: 2. at " & Integer'image(i + not_SL) & " shift entry from " & Integer'image(i + 1);
					LAB_temp(i + not_SL)	:= LAB_temp(i + 1);
					
					if i + 1 = LAB_MAX - 1 and shift_LAB = '1' then
						--we're at the last spot in the LAB and need to provide zeros for last entry
						LAB_temp(i).inst				:= "0000000000000000";
						LAB_temp(i).inst_valid		:= '0';
						LAB_temp(i).addr				:= "0000000000000000";
						LAB_temp(i).addr_valid		:= '1';
						exit;
					end if;
				else
					--report "LAB_func: 3. at " & Integer'image(i + not_SL) & " shift entry from " & Integer'image(i + 1);
					LAB_temp(i)	:= LAB_temp(i);
					
					if i + 1 = LAB_MAX - 1 and shift_LAB = '1' then
						--we're at the last spot in the LAB and need to provide zeros for last entry
						LAB_temp(i).inst				:= "0000000000000000";
						LAB_temp(i).inst_valid		:= '0';
						LAB_temp(i).addr				:= "0000000000000000";
						LAB_temp(i).addr_valid		:= '1';
						exit;
					end if;
					
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
	
	--function to purge LAB of all instructions that were incorrectly fetched as part of speculative branch execution
	function purge_insts(	LAB					: in LAB_actual;
									ROB_in				: in ROB;
									frst_branch_idx	: in integer)
		return LAB_actual is
		
		variable i, clear_remaining		: integer 		:= 5;	
		variable LAB_temp						: LAB_actual 	:= LAB;
		
	begin
		
		for i in 0 to 4 loop
			if ROB_in(frst_branch_idx + 1).inst = LAB_temp(i).inst and LAB_temp(i).inst_valid = '1' then
			--clear all subsequent instructions from LAB
				LAB_temp(i).inst				:= "0000000000000000";
				LAB_temp(i).inst_valid		:= '0';
				LAB_temp(i).addr				:= "0000000000000000";
				LAB_temp(i).addr_valid		:= '1';
				
				clear_remaining := i;
				
			elsif clear_remaining > i then
				LAB_temp(i).inst				:= "0000000000000000";
				LAB_temp(i).inst_valid		:= '0';
				LAB_temp(i).addr				:= "0000000000000000";
				LAB_temp(i).addr_valid		:= '1';
				
			else 
				LAB_temp(i) := LAB_temp(i);
			end if;
		end loop;	--i
		
		return LAB_temp;
	
	end;
	
	--function to determine if incorrectly, speculatively fetched instructions are in pipeline 
	--returns std_logic_vector(3 downto 0) = | LAB_IW | ID_IW | EX_IW | MEM_IW |
	
	function check_ROB_for_wrongly_fetched_insts(ROB_in	: in ROB;
																LAB_IW	: in std_logic_vector(15 downto 0);
																ID_IW		: in std_logic_vector(15 downto 0);
																EX_IW		: in std_logic_vector(15 downto 0);
																MEM_IW	: in std_logic_vector(15 downto 0))
		return std_logic_vector is
		
		variable i		: integer 	:= 0;	
		variable temp 	: std_logic_vector(0 to 2) := "000";
		
	begin 
	
		for i in 0 to 9 loop

			if ROB_in(i).inst = ID_IW then
				temp := temp or "100";
				--report "LAB_func: LAB_IW_out matches " & integer'image(i) & "th ROB inst";
			elsif ROB_in(i).inst = EX_IW then
				temp := temp or "010";
				--report "LAB_func: ID_IW_out matches " & integer'image(i) & "th ROB inst";
			elsif ROB_in(i).inst = MEM_IW then
				temp := temp or "001";
				
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
					report "LAB_func: revalidating reg " & integer'image(to_integer(unsigned(LAB_IW(11 downto 7))));
				elsif ROB_in(i).inst = ID_IW then
					temp_I := shift_left(one, to_integer(unsigned(ID_IW(11 downto 7))));
					report "LAB_func: revalidating reg " & integer'image(to_integer(unsigned(ID_IW(11 downto 7))));
				elsif ROB_in(i).inst = EX_IW then
					temp_E := shift_left(one, to_integer(unsigned(EX_IW(11 downto 7))));
					report "LAB_func: revalidating reg " & integer'image(to_integer(unsigned(EX_IW(11 downto 7))));
				elsif ROB_in(i).inst = MEM_IW then
					temp_M := shift_left(one, to_integer(unsigned(MEM_IW(11 downto 7))));
					report "LAB_func: revalidating reg " & integer'image(to_integer(unsigned(MEM_IW(11 downto 7))));
				elsif ROB_in(i).inst = WB_IW_in then
					temp_W := shift_left(one, to_integer(unsigned(WB_IW_in(11 downto 7))));
					report "LAB_func: revalidating reg " & integer'image(to_integer(unsigned(WB_IW_in(11 downto 7))));
				elsif i > frst_branch_idx and ROB_in(i).valid = '1' then --need to revalidate complete, speculative registers in ROB
					temp_R := temp_R or shift_left(one, to_integer(unsigned(ROB_in(i).inst(11 downto 7))));
					report "LAB_func: revalidating reg " & integer'image(to_integer(unsigned(ROB_in(i).inst(11 downto 7))));
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
					report "LAB_func: reg1 results not ready - exiting. j = " & integer'image(j);
					exit; --exit here since the operand dependency closest to branch isn't complete - therefore we can't know outcome of evaluation
					
				elsif ROB_in(frst_branch_idx).inst(6 downto 2) = ROB_in(j).inst(11 downto 7) and ROB_in(j).valid = '1' and ROB_in(j).complete = '0' and frst_branch_idx > j and bne = '1' then
					reg2_resolved		:= '0';
					condition_met		:= '0';
					report "LAB_func: reg2 results not ready - exiting. j = " & integer'image(j);
					exit; --exit here since the operand dependency closest to branch isn't complete - therefore we can't know outcome of evaluation
				
				elsif ROB_in(frst_branch_idx).inst(11 downto 7) = ROB_in(j).inst(11 downto 7) and ROB_in(j).valid = '1' and ROB_in(j).complete = '1' and frst_branch_idx > j then	--
					--its a BNEZ, the instruction dest_reg matches the branch register, the instruction results are "complete", and was issued just prior to the branch
					report "LAB_func: reg1 condition resolved, j = " & integer'image(j);
					reg1_resolved 		:= reg1_resolved and '1';
					
					if reg1_encountered = '0' then
						report "LAB_func: reg1 located at slot " & integer'image(j);
						reg1_slot			:= j;
						reg1_encountered	:= '1';
					else
						reg1_slot			:= reg1_slot;
					end if;
					
				elsif ROB_in(frst_branch_idx).inst(6 downto 2) = ROB_in(j).inst(11 downto 7) and ROB_in(j).valid = '1' and ROB_in(j).complete = '1' and frst_branch_idx > j and bne = '1' then	--
					--its a BNEZ, the instruction dest_reg matches the branch register, the instruction results are "complete", and was issued just prior to the branch
					report "LAB_func: reg1 condition resolved, j = " & integer'image(j);
					reg2_resolved 		:= reg1_resolved and '1';
					
					if reg2_encountered = '0' then
						report "LAB_func: reg2 located at slot " & integer'image(j);
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
							elsif WB_data_out /= ROB_in(reg2_slot).result and bne = '1' then
								condition_met 		:= '1';
								report "LAB_func: WB_data_out is not equal to reg2.";
							else
								condition_met		:= '0';
								report "LAB_func: WB_data_out is ???.";
							end if;
							
							exit;
							
						elsif WB_IW_out(11 downto 7) = ROB_in(frst_branch_idx).inst(6 downto 2) and bne = '1' then	--
						--WB is writing back to reg2 - evaluate now for condition
							--report "LAB_func: WB IW matches ROB bne branch.";
							if WB_data_out /= ROB_in(reg1_slot).result then
								condition_met 		:= '1';
								report "LAB_func: WB_data_out is NOT equal to reg2.";
							else
								condition_met		:= '0';
								report "LAB_func: WB_data_out is ??";
							end if;
							
							exit;
						
						end if;
						
					elsif reg1_resolved = '0' then
						--shouldn't be able to get here, but just exit.
						report "LAB_func: reg2 results not ready - exiting. j = " & integer'image(j);
						exit; --exit here since the operand dependency closest to branch isn't complete - therefore we can't know outcome of evaluation
						
					elsif reg2_resolved = '0' and bne = '1' then
						--shouldn't be able to get here, but just exit.
						report "LAB_func: reg2 results not ready - exiting. j = " & integer'image(j);
						exit; --exit here since the operand dependency closest to branch isn't complete - therefore we can't know outcome of evaluation
					
					end if;
				else
					--report "LAB_func: Can't match a single LAB instruction to ROB?";
				
				end if;
			end loop;
		else
			--report "LAB_func: Can't find first branch?";
		end if;
	else
	--there is no branch in ROB yet, just look at WB_data_out and RF.
		--since reg1_resolved and reg2_resolved have, thus far, only represented ROB entries, now we need to check WB_IW_out and RF entries
		if reg1_resolved = '1' and reg2_resolved = '1' then
			if WB_IW_out(11 downto 7) = PM_data_in(11 downto 7) and RF_in_3_valid = '1' then	--
			--WB is writing back to reg1 - evaluate now for condition given reg2 content from RF
				report "LAB_func: reg1 and reg2 results ready";
				if WB_data_out /= "0000000000000000" and bnez = '1' then
					condition_met		:= '1';

				elsif WB_data_out /= RF_in_4 and bne = '1' then
					condition_met 		:= '1';

				else
					condition_met		:= '0';

				end if;

			elsif WB_IW_out(11 downto 7) = PM_data_in(6 downto 2) and bne = '1' and RF_in_3_valid = '1' and RF_in_4_valid = '1' then	--
			--WB is writing back to reg2 - evaluate now for condition given reg1 content from RF
				report "LAB_func: reg1 and reg2 results ready";
				if WB_data_out /= RF_in_3 then
					condition_met 		:= '1';
				else
					condition_met		:= '0';
				end if;
				
			else
				report "LAB_func: unsure. marking as not ready.";
				reg1_resolved 	:= '0';
				reg2_resolved 	:= '0';
				condition_met	:= '0';
				
			end if;

		else
			report "LAB_func: unsure. marking as not ready.";
			reg1_resolved 	:= '0';
			reg2_resolved 	:= '0';
			condition_met	:= '0';
			
		end if;
	end if;

	--simple combinational logic for values to return
	return ((bne and reg1_resolved and reg2_resolved) or (bnez and reg1_resolved)) & condition_met;
	
	end function;
	
end package body LAB_functions;
