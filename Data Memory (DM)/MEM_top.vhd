--Written by: Joe Post

--This block instantiates the highest level data memory block, which has access to the A and C busses. 
--DM writes are only enabled if the X_bus_in_sel and wren lines are high simultaneously. 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity MEM_top is
   port ( 
		--Input data and clock
		reset_n, sys_clock	: in std_logic;	
		MEM_in_1, MEM_in_2 	: in std_logic_vector(15 downto 0);
		
		--Control 
		MEM_out_mux_sel		: in std_logic_vector(1 downto 0);
		wr_en						: in std_logic; --write enable for data memory
		
		--Output
		MEM_out_top				: out std_logic_vector(15 downto 0)
	
	);
end MEM_top;

architecture behavioral of MEM_top is

	component mux_4_new is
	PORT
	(
		data0x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		data1x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		data2x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		data3x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		sel			: IN STD_LOGIC_VECTOR (1 DOWNTO 0);
		result		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
	end component mux_4_new;

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
	
	signal mem_addr_reg				: std_logic_vector(10 downto 0);
	signal wr_en_reg					: std_logic;
	signal data_in_reg, MEM_out_top_reg, data_out, MEM_mux_out		: std_logic_vector(15 downto 0);
	signal MEM_out_mux_sel_reg 		: std_logic_vector(1 downto 0);

	
begin

	--output mux
	MEM_out_mux	: mux_4_new
	port map (
		data0x	=> "0000000000000000",
		data1x  	=> data_out,		--data from DM 		
		data2x  	=> MEM_in_1,		--data from ALU output
		data3x	=> MEM_in_2,		--data forwarded through ALU
		sel 		=> MEM_out_mux_sel_reg,
		result  	=> MEM_mux_out
	);
	
	data_memory : DataMem
	port map
		(
			address	=> MEM_in_1(10 downto 0),
			clock		=> sys_clock,
			data		=> MEM_in_2,
			wren		=> wr_en_reg,
			q			=> data_out
		);

	process(reset_n, sys_clock)
	begin
		if reset_n = '0' then
			wr_en_reg				<= '0';
			MEM_out_mux_sel_reg 	<= "00";
			MEM_out_top_reg		<= "0000000000000000";
			
		elsif rising_edge(sys_clock) then

			wr_en_reg				<= wr_en;
			MEM_out_mux_sel_reg 	<= MEM_out_mux_sel;
			MEM_out_top_reg		<= MEM_mux_out;
			
		end if; --reset_n
	end process;
	
	--latch inputs

	--latch outputs
	MEM_out_top <= MEM_out_top_reg;
	
end behavioral;