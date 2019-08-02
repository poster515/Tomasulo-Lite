--Written by: Joe Post

--This file receives operands from the ID stage and executes operations by forwarding data via control instructions to ALU.
--This file will not contain the ALU however. 


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.arrays.ALL;

entity EX is
   port ( 
		--Input data and clock
		reset_n, sys_clock	: in std_logic;	
		IW_in						: in std_logic_vector(15 downto 0);
		EX_stall_in				: in std_logic;
		mem_addr_in				: in std_logic_vector(15 downto 0); --memory address from ID stage
		immediate_val_in		: in std_logic_vector(15 downto 0); --immediate value from ID stage
		ALU_fwd_reg_1_in		: in std_logic;
		ALU_fwd_reg_2_in		: in std_logic;
		
		--Control
		ALU_out1_en, ALU_out2_en		: out std_logic; --(CSAM) enables ALU_outX on A, B, or C bus
		ALU_d1_in_sel, ALU_d2_in_sel	: out std_logic_vector(1 downto 0); --(ALU_top) 1 = select from a bus, 0 = don't.
		ALU_fwd_data_out_en				: out std_logic; -- (ALU_top) ALU forwarding register out enable
		
		--Outputs
		ALU_op			: out std_logic_vector(3 downto 0);
		ALU_inst_sel	: out std_logic_vector(1 downto 0);
		EX_stall_out	: out std_logic;
		IW_out			: out std_logic_vector(15 downto 0); -- forwarding to MEM control unit
		mem_addr_out	: out std_logic_vector(15 downto 0); -- memory address directly to ALU
		immediate_val	: out	std_logic_vector(15 downto 0); --represents various immediate values from various OpCodes
		reset_out		: out std_logic
	);
end EX;

architecture behavioral of EX is
	signal reset_reg				: std_logic := '0';
	signal ALU_op_reg				: std_logic_vector(3 downto 0);
	signal ALU_inst_sel_reg		: std_logic_vector(1 downto 0);
	signal immediate_val_reg	: std_logic_vector(15 downto 0);
	signal mem_addr_reg			: std_logic_vector(15 downto 0);
	constant opcode_translator : array_16_4 := ("0000", --add
																 "0001", --sub
																 "0010", --mult
																 "0011", --div
																 "0100", --logic
																 "0101", --rot
																 "0110", --shift_l
																 "0111", --shift_a
																 "0000", --load/store
																 "1001", --jump
																 "0001", --bne(z)
																 "1011", --GPIO/I2C
																 "1100", --logic_i
																 "0000", --cp
																 "0000",
																 "0000"
																);

begin

	process(reset_n, sys_clock)
	begin
		if reset_n = '0' then
		
			ALU_op_reg					<= "0000";
			ALU_inst_sel_reg			<= "00";
			mem_addr_reg				<= "0000000000000000";
			immediate_val_reg 		<= "0000000000000000";
			ALU_out1_en 				<= '0';
			ALU_out2_en 				<= '0';
			EX_stall_out 				<= '0';
			ALU_fwd_data_out_en 		<= '0';
			ALU_d1_in_sel 				<= "00";
			ALU_d2_in_sel 				<= "00";
			IW_out 						<= "0000000000000000";
			reset_reg					<= '0';
			
		elsif rising_edge(sys_clock) then
			reset_reg <= '1';
		
			if EX_stall_in = '0' then
			
				immediate_val_reg 	<= immediate_val_in;
				mem_addr_reg 			<= mem_addr_in;
				
				ALU_op_reg <= opcode_translator(to_integer(unsigned(IW_in(15 downto 12))));
				
				--report "opcode_translator index is: " & integer'image(to_integer(unsigned(IW_in(15 downto 12)))) & " and translated opcode is: " & integer'image(to_integer(unsigned(opcode_translator(to_integer(unsigned(IW_in(15 downto 12)))))));
				
				ALU_inst_sel_reg 	<= IW_in(1 downto 0);
				
				if ALU_fwd_reg_1_in = '0' then
					--report "Setting ALU_d1_in_sel based on IW_in.";
					
					--Updated 7/29 for SLAI, SRAI, SLLI, SRLI and CP
					ALU_d1_in_sel(0) <= not(IW_in(15)) or (IW_in(15) and not(IW_in(12)) and (IW_in(14) xor IW_in(13))) or (IW_in(15) and IW_in(14) and not(IW_in(13)) and not(IW_in(12)));
					--Updated 7/29 for SLAI, SRAI, SLLI, SRLI and CP								
					ALU_d1_in_sel(1) <= IW_in(15) and not(IW_in(14)) and not(IW_in(13)) and not(IW_in(12));
				else
					--report "Defaulting to '11' for ALU_d1_in_sel.";
					ALU_d1_in_sel <= "11";
				end if;
				
				if ALU_fwd_reg_2_in = '0' then
					--report "Setting ALU_d2_in_sel based on IW_in.";
					--Updated 7/29 for SLAI, SRAI, SLLI, SRLI and CP
					ALU_d2_in_sel(0) <= (not(IW_in(15)) and ((IW_in(14) and (not(IW_in(13)) or not(IW_in(1)))) or (not(IW_in(1)) and not(IW_in(0))))) or
												(IW_in(15) and not(IW_in(14)) and ((not(IW_in(13)) and not(IW_in(12)) and not(IW_in(1)) and IW_in(0)) or (not(IW_in(13)) and not(IW_in(12)) and not(IW_in(0))))) or
												(IW_in(14) and not(IW_in(13)) and IW_in(12));
					--Updated 7/29 for SLAI, SRAI, SLLI, SRLI	and CP						
					ALU_d2_in_sel(1) <= (IW_in(15) and not(IW_in(13)) and not(IW_in(12)) and IW_in(0)) or (not(IW_in(15)) and not(IW_in(14)) and not(IW_in(1)) and IW_in(0)) or
												(IW_in(15) and IW_in(14) and not(IW_in(13)) and not(IW_in(12))) or (not(IW_in(15)) and IW_in(14) and IW_in(13) and IW_in(1));
				else
					--report "Defaulting to '11' for ALU_d2_in_sel.";
					ALU_d2_in_sel <= "11";
				end if;
				
				ALU_out1_en <= not(IW_in(15)) or (not(IW_in(13)) and not(IW_in(12))) or (IW_in(15) and IW_in(14) and not(IW_in(13)) and IW_in(12));
				
				ALU_out2_en <= (not(IW_in(15)) and not(IW_in(14)) and IW_in(13)) or 
										(IW_in(15) and not(IW_in(14)) and not(IW_in(13)) and not(IW_in(12)) and IW_in(1)) or
										(IW_in(15) and not(IW_in(14)) and IW_in(13) and IW_in(12) and IW_in(0));
				
				--stores (1000..1X), I2C/GPIO writes (1011..X1), need to forward data from ALU
				if (IW_in(15) and not(IW_in(14)) and ((not(IW_in(13)) and not(IW_in(12)) and IW_in(1)) or (IW_in(13) and IW_in(12) and IW_in(0)))) = '1' then
					ALU_fwd_data_out_en <= '1';
				else
					ALU_fwd_data_out_en <= '0';
				end if;

				EX_stall_out <= '0';
				IW_out <= IW_in;	--forward IW to MEM stage

			else
				--do nothing
				
			end if; --stall_in

		end if; --reset_n
		
	end process;
	
	--latch inputs
	
	--latch outputs
	ALU_op 			<= ALU_op_reg;
	ALU_inst_sel 	<=	ALU_inst_sel_reg;
	immediate_val	<= immediate_val_reg;
	mem_addr_out 	<= mem_addr_reg;
	reset_out 		<= reset_reg;
	
end behavioral;