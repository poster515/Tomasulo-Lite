--Written by: Joe Post

--This file receives bus control signals from most CU modules (i.e., ID, EX, MEM, WB), and arbitrates them.
--All logic is purely combinational since the outputs are needed in the same clock cycle they're issued.
--Priority arbitrarily is delegated to the control unit farthest into process (i.e., WB). 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity CSAM is
   port ( 
		--Input data and clock
		reset_n, sys_clock	: in std_logic;	
		
		--Control Inputs
		RF_B_bus_out1_en, RF_C_bus_out1_en	: out std_logic; --enables RF_out_1 on B and C bus
		RF_B_bus_out2_en, RF_C_bus_out2_en	: out std_logic; --enables RF_out_1 on B and C bus
		
		ALU_B_bus_out1_en, ALU_C_bus_out1_en	: out std_logic; --enables ALU_out_1 on B and C bus
		ALU_B_bus_out2_en, ALU_C_bus_out2_en	: out std_logic; --enables ALU_out_1 on B and C bus
		
		ION_A_bus_out_sel, ION_B_bus_out_sel	: in std_logic --enables A or B bus onto output_buffer (ONLY SET HIGH WHEN RESULTS ARE READY)

		--Control Outputs
		
	);
end CSAM;

architecture behavioral of CSAM is
	
begin

	process(reset_n, sys_clock)
	begin
		if reset_n = '0' then
			
		elsif rising_edge(sys_clock) then

		end if; --reset_n
		
	end process;
	
	--latch inputs
	
	--latch outputs
	
end behavioral;