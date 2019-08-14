library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity mux_2 is
   port ( 
		sel 		: in  std_logic;
		--
		in_0   	: in  std_logic_vector(15 downto 0);
		in_1   	: in  std_logic_vector(15 downto 0);
		--
		data_out  : out std_logic_vector(15 downto 0)
	);
end mux_2;

architecture behavioral of mux_2 is
begin

with sel select
	data_out <= in_0 when '0',
				  in_1 when '1',
				  "ZZZZZZZZZZZZZZZZ" when others;
end behavioral;