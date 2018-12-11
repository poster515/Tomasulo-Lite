--Written by: Joe Post

--This file receives operands from the ID stage and executes operations by forwarding data via control instructions to ALU.
--This file will not contain the ALU however. 


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity EX is
   port ( 
		--Input data and clock
		reset_n, sys_clock	: in std_logic;	
		IW							: in std_logic_vector(15 downto 0);
		stall_in					: in std_logic;		--set high when an upstream CU block needs this 
		
		--Control
		
		
		--Outputs
		stall_out		: out std_logic;
		immediate_val	: out	std_logic_vector(15 downto 0)--represents various immediate values from various OpCodes
	);
end EX;

architecture behavioral of EX is

	
begin
	process(reset_n, sys_clock)
	begin
		if reset_n = '0' then
			
		elsif rising_edge(sys_clock) then
		
			if stall_in = '0' then

			elsif stall_in = '1' then

			end if; --stall_in

		end if; --reset_n
	end process;
	
	--latch inputs
	
	--latch outputs
	
end behavioral;