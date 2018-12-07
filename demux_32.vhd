library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity demux_32 is
   port ( 
		sel 		: in  std_logic_vector(4 downto 0);
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
		out_10   : out  std_logic_vector(15 downto 0);
		out_11   : out  std_logic_vector(15 downto 0);
		out_12   : out  std_logic_vector(15 downto 0);
		out_13   : out  std_logic_vector(15 downto 0);
		out_14   : out  std_logic_vector(15 downto 0);
		out_15   : out  std_logic_vector(15 downto 0);
		out_16   : out  std_logic_vector(15 downto 0);
		out_17   : out  std_logic_vector(15 downto 0);
		out_18   : out  std_logic_vector(15 downto 0);
		out_19   : out  std_logic_vector(15 downto 0);
		out_20   : out  std_logic_vector(15 downto 0);
		out_21   : out  std_logic_vector(15 downto 0);
		out_22   : out  std_logic_vector(15 downto 0);
		out_23   : out  std_logic_vector(15 downto 0);
		out_24   : out  std_logic_vector(15 downto 0);
		out_25   : out  std_logic_vector(15 downto 0);
		out_26   : out  std_logic_vector(15 downto 0);
		out_27   : out  std_logic_vector(15 downto 0);
		out_28   : out  std_logic_vector(15 downto 0);
		out_29   : out  std_logic_vector(15 downto 0);
		out_30   : out  std_logic_vector(15 downto 0);
		out_31   : out  std_logic_vector(15 downto 0)
	);
end demux_32;

architecture behavioral of demux_32 is
begin
	process(sel, data_in)
		begin
			out_0_case: case sel is
			  when "00000" => out_0 <= data_in;
			  when others => out_0 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_1_case: case sel is
			  when "00001" => out_1 <= data_in;
			  when others => out_1 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_2_case: case sel is
			  when "00010" => out_2 <= data_in;
			  when others => out_2 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_3_case: case sel is
			  when "00011" => out_3 <= data_in;
			  when others => out_3 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_4_case: case sel is
			  when "00100" => out_4 <= data_in;
			  when others => out_4 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_5_case: case sel is
			  when "00101" => out_5 <= data_in;
			  when others => out_5 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_6_case: case sel is
			  when "00110" => out_6 <= data_in;
			  when others => out_6 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_7_case: case sel is
			  when "00111" => out_7 <= data_in;
			  when others => out_7 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_8_case: case sel is
			  when "01000" => out_8 <= data_in;
			  when others => out_8 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_9_case: case sel is
			  when "01001" => out_9 <= data_in;
			  when others => out_9 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_10_case: case sel is
			  when "01010" => out_10 <= data_in;
			  when others => out_10 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_11_case: case sel is
			  when "01011" => out_11 <= data_in;
			  when others => out_11 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_12_case: case sel is
			  when "01100" => out_12 <= data_in;
			  when others => out_12 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_13_case: case sel is
			  when "01101" => out_13 <= data_in;
			  when others => out_13 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_14_case: case sel is
			  when "01110" => out_14 <= data_in;
			  when others => out_14 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_15_case: case sel is
			  when "01111" => out_15 <= data_in;
			  when others => out_15 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_16_case: case sel is
			  when "10000" => out_16 <= data_in;
			  when others => out_16 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_17_case: case sel is
			  when "10001" => out_17 <= data_in;
			  when others => out_17 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_18_case: case sel is
			  when "10010" => out_18 <= data_in;
			  when others => out_18 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_19_case: case sel is
			  when "10011" => out_19 <= data_in;
			  when others => out_19 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_20_case: case sel is
			  when "10100" => out_20 <= data_in;
			  when others => out_20 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_21_case: case sel is
			  when "10101" => out_21 <= data_in;
			  when others => out_21 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_22_case: case sel is
			  when "10110" => out_22 <= data_in;
			  when others => out_22 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_23_case: case sel is
			  when "10111" => out_23 <= data_in;
			  when others => out_23 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_24_case: case sel is
			  when "11000" => out_24 <= data_in;
			  when others => out_24 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_25_case: case sel is
			  when "11001" => out_25 <= data_in;
			  when others => out_25 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_26_case: case sel is
			  when "11010" => out_26 <= data_in;
			  when others => out_26 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_27_case: case sel is
			  when "11011" => out_27 <= data_in;
			  when others => out_27 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_28_case: case sel is
			  when "11100" => out_28 <= data_in;
			  when others => out_28 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_29_case: case sel is
			  when "11101" => out_29 <= data_in;
			  when others => out_29 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_30_case: case sel is
			  when "11110" => out_30 <= data_in;
			  when others => out_30 <= "ZZZZZZZZZZZZZZZZ";
			end case;
			
			out_31_case: case sel is
			  when "11111" => out_31 <= data_in;
			  when others => out_31 <= "ZZZZZZZZZZZZZZZZ";
			end case;
		end process;
end behavioral;