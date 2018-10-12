library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity demux_16 is
   port ( 
		sel 		: in  std_logic_vector(3 downto 0);
		data_in  	: in std_logic_vector(15 downto 0);
		
		out_0   	: out  std_logic_vector(15 downto 0);
		out_1   	: out  std_logic_vector(15 downto 0);
		out_2   	: out  std_logic_vector(15 downto 0);
		out_3   	: out  std_logic_vector(15 downto 0);
		out_4   	: out  std_logic_vector(15 downto 0);
		out_5   	: out  std_logic_vector(15 downto 0);
		out_6   	: out  std_logic_vector(15 downto 0);
		out_7   	: out  std_logic_vector(15 downto 0);
		out_8   	: out  std_logic_vector(15 downto 0);
		out_9   	: out  std_logic_vector(15 downto 0);
		out_10   	: out  std_logic_vector(15 downto 0);
		out_11   	: out  std_logic_vector(15 downto 0);
		out_12   	: out  std_logic_vector(15 downto 0);
		out_13   	: out  std_logic_vector(15 downto 0);
		out_14   	: out  std_logic_vector(15 downto 0);
		out_15   	: out  std_logic_vector(15 downto 0)
	);
end demux_16;

architecture behavioral of demux_16 is
begin
	process(sel, data_in)
		begin
			out_0_case: case sel is
			  when "0000" => out_0 <= data_in;
			  when others => out_0 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_1_case: case sel is
			  when "0001" => out_1 <= data_in;
			  when others => out_1 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_2_case: case sel is
			  when "0010" => out_2 <= data_in;
			  when others => out_2 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_3_case: case sel is
			  when "0011" => out_3 <= data_in;
			  when others => out_3 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_4_case: case sel is
			  when "0100" => out_4 <= data_in;
			  when others => out_4 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_5_case: case sel is
			  when "0101" => out_5 <= data_in;
			  when others => out_5 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_6_case: case sel is
			  when "0110" => out_6 <= data_in;
			  when others => out_6 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_7_case: case sel is
			  when "0111" => out_7 <= data_in;
			  when others => out_7 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_8_case: case sel is
			  when "1000" => out_8 <= data_in;
			  when others => out_8 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_9_case: case sel is
			  when "1001" => out_9 <= data_in;
			  when others => out_9 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_10_case: case sel is
			  when "1010" => out_10 <= data_in;
			  when others => out_10 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_11_case: case sel is
			  when "1011" => out_11 <= data_in;
			  when others => out_11 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_12_case: case sel is
			  when "1100" => out_12 <= data_in;
			  when others => out_12 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_13_case: case sel is
			  when "1101" => out_13 <= data_in;
			  when others => out_13 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_14_case: case sel is
			  when "1110" => out_14 <= data_in;
			  when others => out_14 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_15_case: case sel is
			  when "1111" => out_15 <= data_in;
			  when others => out_15 <= "ZZZZZZZZZZZZZZZZ";
			end case;
		end process;
end behavioral;