--Written by: Joe Post

--This file generates control signals necessary to forward data to other pipeline stages and write back data to RF.
--This file will not contain the RF however. 


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity WB is
   port ( 
		--Input data and clock
		reset_n, sys_clock	: in std_logic;	
		IW_in						: in std_logic_vector(15 downto 0);
		LAB_stall_in			: in std_logic;		--set high when an upstream CU block needs this 
		
		--Control
		--WB stage will direct MEM and/or ION traffic back into RF, need to create appropriate control signals
		
		--Outputs
		IW_out			: out std_logic_vector(15 downto 0);
		stall_out		: out std_logic;
		immediate_val	: out	std_logic_vector(15 downto 0)--represents various immediate values from various OpCodes
	);
end WB;

architecture behavioral of WB is

	
begin
	process(reset_n, sys_clock)
	begin
		if reset_n = '0' then
			
		elsif rising_edge(sys_clock) then
		
			if LAB_stall_in = '0' then
			
				IW_out <= IW_in;	--forward IW back to LAB

			elsif LAB_stall_in = '1' then

			end if; --LAB_stall_in

		end if; --reset_n
	end process;
	
	--latch inputs
	
	--latch outputs
	
end behavioral;