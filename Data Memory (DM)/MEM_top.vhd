--Written by: Joe Post

--This block instantiates the highest level data memory block, which has access to the A and C busses. 
--DM writes are only enabled if the X_bus_in_sel and wren lines are high simultaneously. 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.control_unit_types.all;

entity MEM_top is
   port ( 
		--Input data and clock
		reset_n, sys_clock	: in std_logic;	
		MEM_in_1, MEM_in_2 	: in std_logic_vector(15 downto 0); --ALU_top_out_1(2)
		
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
	signal data_in_reg, MEM_out_top_reg, data_out, MEM_mux_out		: std_logic_vector(15 downto 0);
	signal 

begin

	--output mux
	MEM_out_mux	: mux_4_new
	port map (
		data0x	=> "0000000000000000",
		data1x  	=> data_out,		--data from DM 					(data_out)
		data2x  	=> MEM_in_1,		--data from ALU output			(ALU_top_out_1)
		data3x	=> MEM_in_2,		--data forwarded through ALU 	(ALU_top_out_2)
		sel 		=> MEM_out_mux_sel,
		result  	=> MEM_mux_out
	);
	
	data_memory : DataMem
	port map
		(
			address	=> MEM_in_1(10 downto 0),
			clock		=> sys_clock,
			data		=> MEM_in_2,
			wren		=> wren_non_speculative,
			q			=> data_out
		);

	process(reset_n, sys_clock, store_inst)
	begin
		if reset_n = '0' then
			MEM_out_top_reg		<= "0000000000000000";
		
		--elsif store_inst = '1' and inst_is_specul = '0'
		elsif store_inst = '1' and inst_is_specul = '0' then
			--if address not in store_buffer, just write to DM
			if check_st_buff_for_address(MEM_in_1(10 downto 0)) = '0' then
				wren_non_speculative <= wr_en;
			--elsif address is in store_buffer, we have to buffer at end of st_buff
			elsif check_st_buff_for_address(MEM_in_1(10 downto 0)) = '1' then
				--have an address match in st_buff - need to add to st_buff instead
				--determine if we can execute another, non-speculative store first though
				if shift_st_buff_down(0).valid = '1' and shift_st_buff_down(0).specul = '0' then
					st_buff_wren 	<= '1';					--wr_en signal for storing in DM from st_buff
					st_buff_data 	<= st_buff(0).data;	--data for storing back to DM from st_buff
					st_buff_addr 	<= st_buff(0).addr;	--address for storing back to DM from st_buff
					st_buff			<= store_shift_st_buff(MEM_in_1(10 downto 0), MEM_in_2, inst_is_specul);
				else
					--can neither write to DM from ALU nor write to DM from st_buff - just buffer ALU outputs in st_buff
					st_buff			<= store_new_store(MEM_in_1(10 downto 0), MEM_in_2, inst_is_specul);
					st_buff_wren 	<= '0';
					wren_non_speculative <= '0';
				end if;
			end if;
			
		elsif rising_edge(sys_clock) then
			--if load_inst = '1', check store_buffer for data
			if load_inst = '1' then
			
				--if address not in store_buffer, just read DM
				if check_st_buff_for_address(MEM_in_1(10 downto 0)) = '0' then
					--read DM data instead
					MEM_out_top_reg	<= MEM_mux_out;
				else
					--read latest store_buffer data
					MEM_out_top_reg	<= fetch_st_buff_data(MEM_in_1(10 downto 0));
				end if;
				
			--elsif store_inst = '1' and inst_is_specul = '1' then store data at end of store_buffer
			elsif store_inst = '1' and inst_is_specul = '1' then 
				st_buff	<= store_new_store(MEM_in_1(10 downto 0), MEM_in_2, inst_is_specul);

			--elsif store_inst = '1' and inst_is_specul = '0'
			elsif store_inst = '1' and inst_is_specul = '0' then
				--don't do anything here - this case is handled as a separate process event
				
			--elsif store_inst = '0' 
			elsif store_inst = '0' and load_inst = '0' then
				--check if we can write any stores back to DM from store_buffer
				if shift_st_buff_down(0).valid = '1' and shift_st_buff_down(0).specul = '0' then
					st_buff_wren <= '1';
					st_buff_data <= st_buff(0).data;
					st_buff_addr <= st_buff(0).addr;
				else
					st_buff_wren <= '0';
				end if;
				
				MEM_out_top_reg		<= MEM_mux_out;
			end if
		end if; --reset_n
	end process;
	
	--latch inputs

	--latch outputs
	MEM_out_top <= MEM_out_top_reg;
	
end behavioral;