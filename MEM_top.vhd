--Written by: Joe Post

--This block instantiates the highest level data memory block, which has access to the A and C busses. 
--DM writes are only enabled if the X_bus_in_sel and wren lines are high simultaneously. 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity MEM_top is
   port ( 
		--Input data and clock
		reset_n, sys_clock	: in std_logic;	
		mem_addr_in				: in std_logic_vector(10 downto 0);	--data memory address directly from MEM control unit
		
		--Control 
		A_bus_out_en, C_bus_out_en		: in std_logic; --enables data memory output on A and C bus
		A_bus_in_sel, C_bus_in_sel		: in std_logic; --enables A or C bus to data_in
		wr_en									: in std_logic; --write enable for data memory
		
		--Outputs
		
		
		--Inouts
		A_bus, C_bus	: inout std_logic_vector(15 downto 0)
	);
end MEM_top;

architecture behavioral of MEM_top is

	component DataMem is
	port
		(
			address	: IN STD_LOGIC_VECTOR (10 DOWNTO 0);
			clock		: IN STD_LOGIC  := '1';
			data		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			wren		: IN STD_LOGIC ;
			q			: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
		);
	end component;
	
	signal mem_addr					: std_logic_vector(10 downto 0);
	signal data_in, data_out		: std_logic_vector(15 downto 0);
	signal A_out_en_reg, C_out_en_reg	: std_logic;
	
begin

	data_memory : DataMem
	port map
		(
			address	=> mem_addr,
			clock		=> sys_clock,
			data		=> data_in,
			wren		=> wr_en,
			q			=> data_out
		);

	process(reset_n, sys_clock)
	begin
		if reset_n = '0' then
			
		elsif rising_edge(sys_clock) then
		
			if A_bus_out_en = '1' then
				A_out_en_reg <= '1';
				
			elsif C_bus_out_en = '1' then
				C_out_en_reg <= '1';
			
			else
				A_out_en_reg <= '0';
				C_out_en_reg <= '0';
			
			end if; --A_bus_out_en
			
		end if; --reset_n
	end process;
	
	--latch inputs
	mem_addr <= mem_addr_in;
	
	data_in <= 	A_bus when A_bus_in_sel = '1' else
					C_bus when C_bus_in_sel = '1' else
					A_bus;
	
	--latch outputs
	
	A_bus <= data_out when A_out_en_reg = '1' and reset_n = '1' else
				"ZZZZZZZZZZZZZZZZ";
				
	C_bus <= data_out when C_out_en_reg = '1' and reset_n = '1' else
				"ZZZZZZZZZZZZZZZZ";

end behavioral;