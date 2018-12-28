--Written by: Joe Post

--This file receives data and memory addresses from the EX stage and executes data memory operations via control instructions to DM.
--This file will not contain the DM however. 


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity MEM is
   port ( 
		--Input data and clock
		reset_n, sys_clock	: in std_logic;	
		IW_in						: in std_logic_vector(15 downto 0);
		LAB_stall_in			: in std_logic;
		WB_stall_in				: in std_logic;		--set high when an upstream CU block needs this 
		
		--Control
		--TODO: Consolidate these into MEM_out_en for CSAM
		A_bus_out_en, C_bus_out_en	: out std_logic;
		
		--Outputs
		IW_out			: out std_logic_vector(15 downto 0);
		MEM_stall_out	: out std_logic;
		immediate_val	: out	std_logic_vector(15 downto 0)--represents various immediate values from various OpCodes
	);
end MEM;

architecture behavioral of MEM is
	
	signal stall_in	: std_logic := '0';
	
	
begin

	stall_in <= LAB_stall_in or WB_stall_in;
	
	process(reset_n, sys_clock)
	begin
		if reset_n = '0' then
			

		elsif rising_edge(sys_clock) then
			
			if WB_stall_in = '0' then
			
				IW_out <= IW_in;	--forward IW to WB stage

			elsif WB_stall_in = '1' then
			
				--continue to propogate stall
				MEM_stall_out <= '1';
				
			else
				
				
			end if; --stall_in

		end if; --reset_n
	end process;
	
	--latch inputs
	
	--latch outputs
	
end behavioral;