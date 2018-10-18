library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ALU_logic is
	port(
			A_in 			: in std_logic_vector(15 downto 0);
			B_in 			: in std_logic_vector(15 downto 0);
			logic_func 	: in std_logic_vector(1 downto 0);
			result 		: out std_logic_vector(15 downto 0);
			zero, negative	: out std_logic
			);
end ALU_logic;

architecture behav of ALU_logic is
	--signal declaration
	signal and_result, or_result, xor_result, not_result	: std_logic_vector(15 downto 0);
	signal and_zero, or_zero, xor_zero, not_zero				: std_logic;
	
	--function prototype
	function zero_check (temp_result : in std_logic_vector(15 downto 0))
		return std_logic is variable temp_zero : std_logic := '0';
			begin
				for i in 0 to temp_result'length-1 loop
				temp_zero := temp_zero or temp_result(i);
				end loop;
				return not(temp_zero);
			  
	end function zero_check;

	begin
		--non-latched, combinational logic functions	
		and_result 	<= A_in and B_in;
		or_result	<= A_in or B_in;
		xor_result	<= A_in xor B_in;
		not_result	<= not(A_in);
		
		and_zero		<= zero_check(and_result);
		or_zero		<= zero_check(or_result);
		xor_zero		<= zero_check(xor_result);
		not_zero		<= zero_check(not_result);

		--latched outputs based on changing intputs
		process(A_in, B_in, logic_func, and_result, or_result, xor_result, not_result, and_zero, or_zero, xor_zero, not_zero)
			begin	
				if (logic_func = "00") then
					result <= and_result;
					negative <= and_result(15);
					zero <= and_zero;
	
				elsif (logic_func = "01") then
					result <= or_result;
					negative <= or_result(15);
					zero <= or_zero;
					
				elsif (logic_func = "10") then
					result <= xor_result;
					negative <= xor_result(15);
					zero <= xor_zero;
					
				elsif (logic_func = "11") then
					result <= not_result;
					negative <= not_result(15);
					zero <= not_zero;
					
				else
					result <= "UUUUUUUUUUUUUUUU";
				end if; --logic_func
				
		end process;
end behav;