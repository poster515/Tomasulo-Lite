--Written by: Joe Post

--This block instantiates the highest level data memory block, which has access to the A and C busses. 
--DM writes are only enabled if the X_bus_in_sel and wren lines are high simultaneously. 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity MEM_top is
   port ( 
		--Input data and clock
		reset_n, sys_clock	: in std_logic;	
		mem_addr_in				: in std_logic_vector(10 downto 0);	--data memory address directly from ALU
		MEM_in_1, MEM_in_2 	: in std_logic_vector(15 downto 0);
		
		--Control 
		A_bus_out_en, C_bus_out_en		: in std_logic; --enables data memory output on A and C bus
		MEM_in_1_sel, MEM_in_2_sel		: in std_logic; --enables MEM_in_1 or MEM_in_2 to data_in
		wr_en									: in std_logic; --write enable for data memory
		MEM_op								: in std_logic; --'1' = DM operation, '0' = forward data, not a memory operation 
		
		--Outputs
		MEM_out_1, MEM_out_2				: out std_logic_vector(15 downto 0)
		
		--Inouts
		
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
	
	data_in <= 	MEM_in_1 when MEM_in_1_sel = '1' else
					MEM_in_2 when MEM_in_2_sel = '1' else
					MEM_in_1;
	
	--latch outputs
	
	MEM_out_1 <= data_out when A_out_en_reg = '1' and reset_n = '1' and MEM_op = '1' else
				data_in  when A_out_en_reg = '1' and reset_n = '1' and MEM_op = '0' else
				"ZZZZZZZZZZZZZZZZ";
				
	MEM_out_2 <= data_out when C_out_en_reg = '1' and reset_n = '1' and MEM_op = '1' else
				data_in  when A_out_en_reg = '1' and reset_n = '1' and MEM_op = '0' else
				"ZZZZZZZZZZZZZZZZ";

end behavioral;