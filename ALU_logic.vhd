library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ALU_logic is
	port(
			A_in 			: in unsigned(15 downto 0);
			B_in 			: in unsigned(15 downto 0);
			logic_func 	: in std_logic_vector(1 downto 0);
			result 		: inout unsigned(15 downto 0);
			zero, negative	: out std_logic
			);
end ALU_logic;

architecture boolean_logic of ALU_logic is
begin
	
	with logic_func select result <=
		not(A_in) 	  when "00",
		A_in AND B_in when "01",
		A_in OR  B_in when "10",
		A_in XOR B_in when "11",
		(others => 'U') when others;
	process(result)
		begin	
			if(result = "000000000000") then zero <= '1';
			else zero <= '0';
			end if;
	
			negative <= result(15);
	end process;
end boolean_logic;