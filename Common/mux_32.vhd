library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity mux_32 is
   port ( 
		sel 		: in  std_logic_vector(4 downto 0);
		
		in_0   	: in  std_logic_vector(15 downto 0);
		in_1   	: in  std_logic_vector(15 downto 0);
		in_2   	: in  std_logic_vector(15 downto 0);
		in_3   	: in  std_logic_vector(15 downto 0);
		in_4   	: in  std_logic_vector(15 downto 0);
		in_5   	: in  std_logic_vector(15 downto 0);
		in_6   	: in  std_logic_vector(15 downto 0);
		in_7   	: in  std_logic_vector(15 downto 0);
		in_8   	: in  std_logic_vector(15 downto 0);
		in_9   	: in  std_logic_vector(15 downto 0);
		in_10   	: in  std_logic_vector(15 downto 0);
		in_11   	: in  std_logic_vector(15 downto 0);
		in_12   	: in  std_logic_vector(15 downto 0);
		in_13   	: in  std_logic_vector(15 downto 0);
		in_14   	: in  std_logic_vector(15 downto 0);
		in_15   	: in  std_logic_vector(15 downto 0);
		in_16   	: in  std_logic_vector(15 downto 0);
		in_17   	: in  std_logic_vector(15 downto 0);
		in_18   	: in  std_logic_vector(15 downto 0);
		in_19   	: in  std_logic_vector(15 downto 0);
		in_20   	: in  std_logic_vector(15 downto 0);
		in_21   	: in  std_logic_vector(15 downto 0);
		in_22   	: in  std_logic_vector(15 downto 0);
		in_23   	: in  std_logic_vector(15 downto 0);
		in_24   	: in  std_logic_vector(15 downto 0);
		in_25   	: in  std_logic_vector(15 downto 0);
		in_26   	: in  std_logic_vector(15 downto 0);
		in_27   	: in  std_logic_vector(15 downto 0);
		in_28   	: in  std_logic_vector(15 downto 0);
		in_29   	: in  std_logic_vector(15 downto 0);
		in_30   	: in  std_logic_vector(15 downto 0);
		in_31   	: in  std_logic_vector(15 downto 0);
		
		--
		sig_out  : out std_logic_vector(15 downto 0)
	);
end mux_32;

architecture behavioral of mux_32 is
begin

with sel select
	sig_out <= in_0 when "00000",
				  in_1 when "00001",
				  in_2 when "00010",
				  in_3 when "00011",
				  in_4 when "00100",
				  in_5 when "00101",
				  in_6 when "00110",
				  in_7 when "00111",
				  in_8 when "01000",
				  in_9 when "01001",
				  in_10 when "01010",
				  in_11 when "01011",
				  in_12 when "01100",
				  in_13 when "01101",
				  in_14 when "01110",
				  in_15 when "01111",
				  in_16 when "10000",
				  in_17 when "10001",
				  in_18 when "10010",
				  in_19 when "10011",
				  in_20 when "10100",
				  in_21 when "10101",
				  in_22 when "10110",
				  in_23 when "10111",
				  in_24 when "11000",
				  in_25 when "11001",
				  in_26 when "11010",
				  in_27 when "11011",
				  in_28 when "11100",
				  in_29 when "11101",
				  in_30 when "11110",
				  in_31 when "11111",
				  "ZZZZZZZZZZZZZZZZ" when others;
		
end behavioral;