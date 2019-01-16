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
		
		--Outputs
		ALU_op			: out std_logic_vector(3 downto 0);
		ALU_inst_sel	: out std_logic_vector(1 downto 0);
		EX_stall_out	: out std_logic;
		IW_out			: out std_logic_vector(15 downto 0);	--forwarding to MEM control unit
		immediate_val	: out	std_logic_vector(15 downto 0)--represents various immediate values from various OpCodes
	);
end EX;

architecture behavioral of EX is
--	--ALU Control signals
--	reset_n					: in std_logic; --all registers reset to 0 when this goes low
--	ALU_op					: in std_logic_vector(3 downto 0); 	--dictates ALU operation (i.e., OpCode)
--	ALU_inst_sel			: in std_logic_vector(1 downto 0); 	--dictates what sub-function to execute (last two bits of OpCode)
--	ALU_d2_mux_sel			: in std_logic_vector(1 downto 0); 	--used to control which data to send to ALU input 2
--																				--0=ALU result 1=data forwarded from ALU_data_in_1
--	B_bus_out1_en, C_bus_out1_en		: in std_logic; --enables ALU_out_1 on B and C bus
--	B_bus_out2_en, C_bus_out2_en		: in std_logic; --enables ALU_out_2 on B and C bus

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
			
		elsif rising_edge(sys_clock) then
		
			if stall_in = '0' then
			
				immediate_val_reg 	<= immediate_val_in;
				
				ALU_op_reg 			<= IW_in(15 downto 12);
				ALU_inst_sel_reg 	<= IW_in(1 downto 0);
				
				--for jumps (1001), loads (1000...01), don't need any ALU output
				if IW_in(15 downto 12) = "1001"  or (IW_in(15 downto 12) = "1000" and IW_in(1 downto 0) = "01") then 
					ALU_out1_en <= '0'; 
					ALU_out2_en <= '0';
				
				--for BNEZ (1010...00), shifts (0110, 0111), rotates (0101), loads (1000...00), stores (1000...11) only need 1 RF output
				elsif (IW_in(15 downto 12) = "1010" and IW_in(1 downto 0) = "00") or
						(IW_in(15 downto 12) = "1000" and (IW_in(1 downto 0) = "00" or IW_in(1 downto 0) = "11")) or
						IW_in(15 downto 12) = "0101" or IW_in(15 downto 12) = "0110" or 
						IW_in(15 downto 12) = "0111" then
					ALU_out1_en <= '1'; 
					ALU_out2_en <= '0';
					
				--for all other instructions, need both RF outputs
				else
					ALU_out1_en <= '1'; 
					ALU_out2_en <= '1';
					
				end if;
				
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