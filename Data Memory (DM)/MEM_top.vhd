 --Written by: Joe Post

--This block instantiates the highest level data memory block, which has access to the A and C busses. 
--DM writes are only enabled if the X_bus_in_sel and wren lines are high simultaneously. 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.control_unit_types.all;
use work.LAB_functions.all;

entity MEM_top is
   port ( 
		--Input data and clock
		reset_n, sys_clock	: in std_logic;	
		MEM_in_1					: in std_logic_vector(15 downto 0); --from ALU_top_out_1, this input is the memory address
		MEM_in_2 				: in std_logic_vector(15 downto 0); --from ALU_top_out_2, this input is the data to be stored
		
		--Control 
		MEM_out_mux_sel		: in std_logic_vector(1 downto 0);
		wr_en						: in std_logic; --write enable for data memory
		
		--Output
		MEM_out_top				: out std_logic_vector(15 downto 0);
		MEM_out_top_reg		: out std_logic_vector(15 downto 0)
	
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
	
	signal MEM_data, MEM_address		: std_logic_vector(15 downto 0);
	signal data_out						: std_logic_vector(15 downto 0);
	signal MEM_out_top_mux_out			: std_logic_vector(15 downto 0);

begin

	--non-speculative DM_out select mux
	non_specul_out_mux	: mux_4_new
	port map (
		data0x	=> "0000000000000000",
		data1x  	=> data_out,		--data from DM 					(data_out)
		data2x  	=> MEM_in_1,		--data from ALU output			(ALU_top_out_1)
		data3x	=> MEM_in_2,		--data forwarded through ALU 	(ALU_top_out_2)
		sel 		=> MEM_out_mux_sel,
		result  	=> MEM_out_top_mux_out
	);
	
	data_memory : DataMem
	port map
		(
			address	=> MEM_address(10 downto 0),
			clock		=> sys_clock,
			data		=> MEM_data,
			wren		=> wr_en,
			q			=> data_out
		);
	
	process(reset_n, sys_clock)
	begin
		if reset_n = '0' then
		
			MEM_out_top_reg 		<= "0000000000000000";

		elsif rising_edge(sys_clock) then
					
			--need to have this signal clocked for the ALU to use for data forwarding
			MEM_out_top_reg	<= MEM_out_top_mux_out;

		end if; --reset_n
	end process;
	
	--latch inputs

	--latch outputs
	MEM_out_top <= MEM_out_top_mux_out;
	
end behavioral;