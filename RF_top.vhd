library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity RF_top is
   port ( 
		--Input data and clock
		RF_in 	: in std_logic_vector(15 downto 0);
		clk 		: in std_logic;

		--Control signals
		reset_n			: in std_logic; --all registers reset to 0 when this goes low
		wr_en 			: in std_logic; --enables write for a selected register
		RF_out_1_mux	: in std_logic_vector(3 downto 0);	--controls first output mux
		RF_out_2_mux	: in std_logic_vector(3 downto 0);	--controls second output mux
		RF_in_demux		: in std_logic_vector(3 downto 0);	--controls which register to write data to
		B_bus_out1_en, C_bus_out1_en		: in std_logic; --enables RF_out_1 on B and C bus
		B_bus_out2_en, C_bus_out2_en		: in std_logic; --enables RF_out_2 on B and C bus

		--Outputs
		B_bus, C_bus	: inout std_logic_vector(15 downto 0)
	);
end RF_top;

architecture behavioral of RF_top is

	component RF is
	port (
		--Input data and clock
		RF_in 	: in std_logic_vector(15 downto 0);
		clk 		: in std_logic;

		--Control signals
		reset_n			: in std_logic; --all registers reset to 0 when this goes low
		wr_en 			: in std_logic; --enables write for a selected register
		RF_out_1_mux	: in std_logic_vector(3 downto 0);	--controls first output mux
		RF_out_2_mux	: in std_logic_vector(3 downto 0);	--controls second output mux
		RF_in_demux		: in std_logic_vector(3 downto 0);	--controls which register to write data to

		--Outputs
		RF_out_1   	: out std_logic_vector(15 downto 0);
		RF_out_2 	: out std_logic_vector(15 downto 0)
	);
	end component RF;

	signal RF_out_1, RF_out_2		: std_logic_vector(15 downto 0);

begin

	RF_inst	: RF
	port map (
		--Input data and clock
		RF_in 	=> RF_in,
		clk 		=> clk,

		--Control signals
		reset_n			=> reset_n,
		wr_en 			=> wr_en,
		RF_out_1_mux	=> RF_out_1_mux,
		RF_out_2_mux	=> RF_out_2_mux,
		RF_in_demux		=> RF_in_demux,

		--Outputs
		RF_out_1   	=> RF_out_1,
		RF_out_2 	=> RF_out_2
	);

	process(reset_n, clk, B_bus_out1_en, C_bus_out1_en, B_bus_out2_en, C_bus_out2_en)
	begin
		if (B_bus_out1_en = '1') then
			B_bus <= RF_out_1;
			
		elsif (C_bus_out1_en = '1') then
			C_bus <= RF_out_1;
			
		elsif (B_bus_out2_en = '1') then
			B_bus <= RF_out_2;
			
		elsif (C_bus_out2_en = '1') then
			C_bus <= RF_out_2;
			
		else
			B_bus <= "ZZZZZZZZZZZZZZZZ";
			C_bus <= "ZZZZZZZZZZZZZZZZ";
		end if; --bus signals
	end process;
end behavioral;