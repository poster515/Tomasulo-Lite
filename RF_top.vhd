library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.arrays.ALL;

entity RF_top is
   port ( 
		--Input data and clock
		clk 		: in std_logic;

		--Control signals
		reset_n			: in std_logic; --all registers reset to 0 when this goes low
		wr_en 			: in std_logic; --enables write for a selected register
		RF_out_1_mux, RF_out_2_mux		: in std_logic_vector(4 downto 0);	--controls first output mux
		RF_out_1_en, RF_out_2_en		: in std_logic;
		B_bus_in_en, C_bus_in_en		: in std_logic; --(WB) used for WB write backs
		RF_in_demux		: in std_logic_vector(4 downto 0);	--controls which register to write data to

		--Outputs
		RF_out_1, RF_out_2	: out std_logic_vector(15 downto 0);
		
		--Inouts
		B_bus, C_bus		: inout std_logic_vector(15 downto 0)
	);
end RF_top;

architecture behavioral of RF_top is

	signal RF							: array_32_16;
	signal in_index, out1_index, out2_index	: integer range 0 to 31;
	
begin

	--process to write back results to RF
	process(reset_n, clk, B_bus, C_bus, wr_en, RF_in_demux)
	begin
	
		--type conversion for RF index
		in_index <= to_integer(unsigned(RF_in_demux));
		
		if reset_n = '0' then
			RF <= (others => (others => '0'));
			
		elsif rising_edge(clk) and wr_en = '1' then
			if B_bus_in_en = '1' and C_bus_in_en = '0' then
				RF(in_index) <= B_bus;
				
			elsif C_bus_in_en = '1' and B_bus_in_en = '0' then
				RF(in_index) <= C_bus;
				
			elsif B_bus_in_en = '1' and C_bus_in_en = '1' then
				report "Conflicting read assignment. Defaulting to B bus.";
				RF(in_index) <= B_bus;
				
			end if;
		end if;
	end process;
	
	--process to read either RF output onto either B or C bus
	process(reset_n, clk, RF_out_1_en, RF_out_2_en, RF_out_1_mux, RF_out_2_mux)
	begin
	
		--type conversion for RF index
		out1_index <= to_integer(unsigned(RF_out_1_mux));
		out2_index <= to_integer(unsigned(RF_out_2_mux));
		

		if reset_n = '0' then
			B_bus <= "ZZZZZZZZZZZZZZZZ";
			C_bus <= "ZZZZZZZZZZZZZZZZ";
			
		elsif rising_edge(clk) then
		
--			--latch outputs
--			if (RF_out_1_en = '1') then
--				RF_out_1 <= RF(out1_index);
--				
--			elsif (RF_out_1_en = '1') then
--				RF_out_2 <= RF(out2_index);
--
--			end if; --out signals
		end if; --reset_n
	end process;
	
	--latch outputs
	RF_out_1 <= RF(out1_index) when RF_out_1_en = '1' else
						RF(0);
		
	RF_out_2 <= RF(out2_index) when RF_out_2_en = '1' else
						RF(0);
end behavioral;