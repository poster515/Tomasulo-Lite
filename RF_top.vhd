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
		B_bus_out_mux	: in std_logic_vector(4 downto 0);	--controls first output mux
		C_bus_out_mux	: in std_logic_vector(4 downto 0);	--controls second output mux
		RF_in_demux		: in std_logic_vector(4 downto 0);	--controls which register to write data to
		B_bus_out_en, C_bus_out_en		: in std_logic; --enables RF_out_1 on B and C bus
		B_bus_in_en, C_bus_in_en		: in std_logic; --enables B and C bus data in to RF

		--Outputs
		B_bus, C_bus	: inout std_logic_vector(15 downto 0)
	);
end RF_top;

architecture behavioral of RF_top is

	signal RF							: array_32_16;
	signal in_index, outB_index, outC_index	: integer range 0 to 31;
	
begin

	--process to write back results to RF
	process(reset_n, clk, B_bus, C_bus, wr_en, B_bus_in_en, C_bus_in_en, RF_in_demux)
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
				
			else 
				RF <= RF;
				
			end if;
		end if;
	end process;
	
	--process to read either RF output onto either B or C bus
	process(reset_n, clk, B_bus_out_en, C_bus_out_en, B_bus_out_mux, C_bus_out_mux)
	begin
	
	--type conversion for RF index
	outB_index <= to_integer(unsigned(B_bus_out_mux));
	outC_index <= to_integer(unsigned(C_bus_out_mux));
	

	if reset_n = '0' then
		B_bus <= "ZZZZZZZZZZZZZZZZ";
		C_bus <= "ZZZZZZZZZZZZZZZZ";
		
	elsif rising_edge(clk) then
	
		--latch outputs
		if (B_bus_out_en = '1') then
			B_bus <= RF(outB_index);
			
		elsif (C_bus_out_en = '1') then
			C_bus <= RF(outC_index);
			
		else
			B_bus <= "ZZZZZZZZZZZZZZZZ";
			C_bus <= "ZZZZZZZZZZZZZZZZ";
		end if; --bus signals
	end if; --reset_n
	end process;
end behavioral;