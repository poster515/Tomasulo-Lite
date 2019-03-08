library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all; 
 
package LAB_functions is 

	--LAB declarations
	type LAB_entry is
		record
			inst		: std_logic_vector(15 downto 0);	--buffers instruction
			inst_valid  : std_logic; 							--0 = not valid/not used, 1 = valid and in pipeline or waiting for commit 	
			addr		: std_logic_vector(15 downto 0);	--buffers memory address, if applicable
			addr_valid  : std_logic; 							--0 = not valid/not used, 1 = valid and in pipeline or waiting for commit 	
		end record;
	
	--type declaration for actual LAB, which has 5 entries, one for each pipeline stage
	type LAB_actual is array(4 downto 0) of LAB_entry;
	
	type ROB_entry is
		record
		  inst			: std_logic_vector(15 downto 0);	--buffers instruction
		  complete  	: std_logic; 							-- 0 = no result yet, 1 = valid result buffered
		  valid			: std_logic;							--tracks if valid instruction buffered
		  result		: std_logic_vector(15 downto 0); --buffers result. 
		  specul		: std_logic;							--'0' = not speculative, '1' = speculative
		end record;
	
	type ROB is array(9 downto 0) of ROB_entry;
	
	type branch_addr is
		record
			addr_met	: std_logic_vector(15 downto 0);	--buffers branch address
			addr_unmet	: std_logic_vector(15 downto 0);	--buffers PC_reg + 1, at time that branch is fetched from PM
			addr_valid  : std_logic; 						--0 = not valid/not used, 1 = valid and in pipeline or waiting for commit 
		end record;
		
	type branch_addrs is array (9 downto 0) of branch_addr;
	
	--function to update "branches", which manages all currently unresolved branch instructions
	function store_shift_branch_addr(	branches			: in branch_addr;
										results_available	: in std_logic;
										addr_valid			: in std_logic;
										addr_met			: in std_logic_vector(15 downto 0)
										addr_unmet			: in std_logic_vector(10 downto 0))
		return branch_addr;
	
	--function which initializes LAB	tags									
	function init_LAB (	LAB_in	: in LAB_actual;
						LAB_MAX	: in integer		) 
		return LAB_actual; 
		
	function shiftLAB_and_bufferPM(	LAB_in		: in LAB_actual;
									PM_data_in	: in std_logic_vector(15 downto 0);
									issued_inst	: in integer;
									LAB_MAX		: in integer 		)
		return LAB_actual;
		
	--function to type convert std_logic to integer
	function convert_SL ( shift_LAB : in std_logic )
		return integer;
	
	--function to determine if results of branch condition are ready	
	function results_ready( bne 			: in std_logic; 
							bnez			: in std_logic; 
							RF_in_3_valid 	: in std_logic;  
							RF_in_4_valid	: in std_logic;   
							RF_in_3			: in std_logic_vector(15 downto 0);
							RF_in_4			: in std_logic_vector(15 downto 0);
							ROB_in			: in ROB) 
		return std_logic_vector(1 downto 0); --std_logic_vector([[condition met]], [[results ready]])
		
end LAB_functions; 

package body LAB_functions is

	--function which initializes LAB	tags									
	function init_LAB (	LAB_in	: in 	LAB_actual;
								LAB_MAX	: in integer		) 
		return LAB_actual is
								
		variable i 			: integer 		:= 0;	
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
	
	--function to update "branches", which manages all currently unresolved branch instructions
	--TODO: finish this function. 
	function store_shift_branch_addr(	branches			: in branch_addrs;
										results_available	: in std_logic;
										addr_valid			: in std_logic;
										addr_met			: in std_logic_vector(15 downto 0)
										addr_unmet			: in std_logic_vector(10 downto 0))
		return branch_addr is
		variable branches_temp	: branch_addrs;
		variable i 				: integer range 0 to 9;
	begin
		for i in 0 to 9 loop
			--condition covers when we get to a location in the branches that isn't valid, i.e., we can buffer branch addresses there
			if branches_temp(i).addr_valid = '0' then
			
				if addr_valid = '1' then
					branches_temp(i).addr_met 		:= addr_met;
					branches_temp(i).addr_unmet 	:= addr_unmet;
					branches_temp(i).addr_valid 	:= '1';
					exit;
				end if;
				
			--condition for when we've gotten to the last valid instruction in the branch_addrs
			elsif branches_temp(i).addr_valid = '1' and branches_temp(i + 1).addr_valid = '0' then
				
				if addr_valid = '1' then
					--n_clear_zero automatically shifts ROB entries
					branches_temp(i + n_clear_zero).addr_met	:= addr_met;
					branches_temp(i + n_clear_zero).addr_unmet	:= addr_unmet;
					branches_temp(i + n_clear_zero).addr_valid 	:= '1';
					
					exit;
				end if;

			--condition for when the ROB is full, we want to buffer incoming PM_data_in, and can clear the zeroth instruction (i.e., make room)
			elsif i = ROB_DEPTH - 2 and clear_zero = '1' and ROB_temp(ROB_DEPTH - 1).valid = '1' then
				
				if addr_valid = '1' then
					
					branches_temp(9).addr_met 		:= addr_met;
					branches_temp(9).addr_unmet 	:= addr_unmet;
					branches_temp(9).addr_valid 	:= '1';
					
				end if;
			
			else
				--clear_zero automatically shifts ROB entries
				ROB_temp(i) := ROB_temp(i + convert_CZ(clear_zero));
				
			end if; --ROB_temp(i).valid
		end loop;
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
	function results_ready( bne 			: in std_logic; 
							bnez			: in std_logic; 
							RF_in_3_valid 	: in std_logic;  --valid marker from RF for Reg1 field of branch IW
							RF_in_4_valid	: in std_logic;  --valid marker from RF for Reg2 field of branch IW
							RF_in_3			: in std_logic_vector(15 downto 0);
							RF_in_4			: in std_logic_vector(15 downto 0);
							ROB_in			: in ROB) 
		return std_logic_vector(1 downto 0) is --std_logic_vector([[condition met]], [[results ready]])
								
		variable i, j 		: integer 		:= 0;	
		
	begin
		if RF_in_3_valid = '1' and bnez = '1' then
			--have a BNEZ, need Reg1, which is in the RF 
			if RF_in_3 /= "0000000000000000" then
				--write PM_data_in, which will now just be a memory address to jump to, to PC_reg somehow
				return "11"; 
			else
				--write PC_reg + 1 to PC_reg, branch condition not met
				return "01";
			end if;
			
		elsif RF_in_3_valid = '1' and RF_in_4_valid = '1' and bne = '1' then
			--have a BNE, need both operands, which are both in the RF 
			if RF_in_3 /= RF_in_4 then
				--write PM_data_in, which will now just be a memory address to jump to, to PC_reg somehow
				return "11";
			else
				--write PC_reg + 1 to PC_reg, branch condition not met
				return "01";
			end if;
		else 			--don't have one or both results issued to RF yet. check ROB if results are buffered as "complete" there 
			for i in 0 to 9 loop
				if ROB_in(i).inst(15 downto 12) = "1010" and ROB_in(i).valid = '1' then	--we have the first branch instruction in ROB
					
					for j in 9 downto 0 loop	--now loop from the top down to determine the first instruction right before the
												--branch that matches the branch operand(s)
						if ROB_in(j).inst(11 downto 7) = ROB_in(i).inst(11 downto 7) and ROB_in(j).valid = '1' and ROB_in(j).complete = '1' and bnez = '1' and i > j then	--
							--its a BNEZ, the instruction dest_reg matches the branch register, the instruction results are "complete", and was issued just prior to the branch
							if ROB_in(j).result /= "0000000000000000" then
								return "11";
							else
								return "01";
							end if;
							
						else	--the above "if" handles all BNEZ instructions, this "else" handles all BNE instructions
							if RF_in_3_valid = '1' and RF_in_4_valid = '0' and bne = '1' then 
								--we only need to find Reg2 value in ROB
								if ROB_in(j).inst(11 downto 7) = ROB_in(i).inst(6 downto 2) and ROB_in(j).valid = '1' and ROB_in(j).complete = '1' and bne = '1' and i > j then	--
									--if its a BNE, the instruction dest_reg matches the branch register, the instruction results are "complete", and was issued just prior to the branch
									if RF_in_3 /= ROB_in(j).result then
										--write PM_data_in, which will now just be a memory address to jump to, to PC_reg somehow
										return "11";
									else
										--write PC_reg + 1 to PC_reg, branch condition not met
										return "01";
									end if;
								end if;
								
							elsif RF_in_3_valid = '0' and RF_in_4_valid = '1' and bne = '1' then --we need to find RF_in_3 value in ROB
								--we only need to find Reg1 value in ROB
								if ROB_in(j).inst(11 downto 7) = ROB_in(i).inst(11 downto 7) and ROB_in(j).valid = '1' and ROB_in(j).complete = '1' and bne = '1' and i > j then	--
									--if its a BNE, the instruction dest_reg matches the branch register, the instruction results are "complete", and was issued just prior to the branch
									if RF_in_4 /= ROB_in(j).result then
										--write PM_data_in, which will now just be a memory address to jump to, to PC_reg somehow
										return "11";
									else
										--write PC_reg + 1 to PC_reg, branch condition not met
										return "01";
									end if;
								end if;
								
							elsif RF_in_3_valid = '0' and RF_in_4_valid = '0' and bne = '1' then --we need to find RF_in_3 value and RF_in_4 value in ROB
								--TODO: we need to find both Reg1 and Reg2 values
								
								
							end if;
						end if;
						
					end loop; --j
				end if; --ROB_in(15 downto 12) = "1010"
			end loop; --for i
		end if; --RF_in_3_valid
	end function;


end package body LAB_functions;
