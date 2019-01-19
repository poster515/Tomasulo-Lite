--Written by: Joe Post

--This file receives operands from the ID stage and executes operations by forwarding data via control instructions to ALU.
--This file will not contain the ALU however. 


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity EX is
   port ( 
		--Input data and clock
		reset_n, sys_clock	: in std_logic;	
		IW_in						: in std_logic_vector(15 downto 0);
		LAB_stall_in			: in std_logic;
		WB_stall_in				: in std_logic;		--set high when an upstream CU block needs this 
		MEM_stall_in			: in std_logic;
		immediate_val_in		: in std_logic_vector(15 downto 0); --immediate value from ID stage
		
		--Control
		ALU_out1_en, ALU_out2_en	: out std_logic; --enables ALU_out_X on B or C bus
		ALU_d1_DM_op 					: out std_logic; --1 = MEM_address to ALU_in_1, 0 = just use A, B, or C bus data (using ALU_d1_bus_in_sel) 
		ALU_d2_immed_op 				: out std_logic; --1 = val_immediate to ALU_in_2, 0 = just use A, B, or C bus data (using ALU_d2_bus_in_sel) 
		
		--Outputs
		ALU_op			: out std_logic_vector(3 downto 0);
		ALU_inst_sel	: out std_logic_vector(1 downto 0);
		EX_stall_out	: out std_logic;
		IW_out			: out std_logic_vector(15 downto 0);	--forwarding to MEM control unit
		immediate_val	: out	std_logic_vector(15 downto 0)--represents various immediate values from various OpCodes
	);
end EX;

architecture behavioral of EX is

	signal stall_in			: std_logic := '0'; --'1' if either stall is '1', '0' if both stalls are '0'	
	signal ALU_op_reg			: std_logic_vector(3 downto 0);
	signal ALU_inst_sel_reg	: std_logic_vector(1 downto 0);
	signal immediate_val_reg:std_logic_vector(15 downto 0);
	
begin

	stall_in <= LAB_stall_in or WB_stall_in or MEM_stall_in;

	process(reset_n, sys_clock)
	begin
		if reset_n = '0' then
		
			ALU_op_reg			<= "0000";
			ALU_inst_sel_reg	<= "00";
			immediate_val_reg <= "0000000000000000";
			ALU_out1_en 		<= '0';
			ALU_out2_en 		<= '0';
			EX_stall_out 		<= '0';
			ALU_d1_DM_op 		<= '0';
			ALU_d2_immed_op 	<= '0';
			IW_out 				<= "0000000000000000";
			
		elsif rising_edge(sys_clock) then
		
			if stall_in = '0' then
			
				immediate_val_reg 	<= immediate_val_in;
				
				ALU_op_reg(2 downto 0) 		<= IW_in(14 downto 12); 
				ALU_op_reg(3)					<= (IW_in(14) or IW_in(13) or IW_in(12)) and IW_in(15);
				
				ALU_inst_sel_reg 	<= IW_in(1 downto 0);
				
				ALU_out1_en <= not(IW_in(15)) or (not(IW_in(13)) and not(IW_in(12)));
				ALU_out2_en <= not(IW_in(15)) and not(IW_in(14)) and IW_in(13);
				
				ALU_d2_immed_op <= (not(IW_in(15)) and not(IW_in(14)) and ALU_inst_sel_reg(1)) or
											(IW_in(15) and IW_in(14) and not(IW_in(13)) and not(IW_in(12))) or
												(IW_in(15) and not(IW_in(14)) and not(IW_in(13)) and not(IW_in(12)) and ALU_inst_sel_reg(0));
												
				ALU_d1_DM_op <= IW_in(15) and not(IW_in(14)) and not(IW_in(13)) and not(IW_in(12)); --"1000"

				EX_stall_out <= '0';
				IW_out <= IW_in;	--forward IW to MEM stage

			elsif stall_in = '1' then
				--propagate stall signal and keep immediate value
				EX_stall_out <= '1';
				immediate_val_reg <= immediate_val_reg;
				
			end if; --stall_in

		end if; --reset_n
		
	end process;
	
	--latch inputs
	
	--latch outputs
	ALU_op 			<= ALU_op_reg;
	ALU_inst_sel 	<=	ALU_inst_sel_reg;
	immediate_val	<= immediate_val_reg;
	
end behavioral;