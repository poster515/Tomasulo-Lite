 --Written by: Joe Post

--This block instantiates the highest level data memory block, which has access to the A and C busses. 
--DM writes are only enabled if the X_bus_in_sel and wren lines are high simultaneously. 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.control_unit_types.all;
use work.mem_top_functions.all;
use work.LAB_functions.all;

entity MEM_top is
   port ( 
		--Input data and clock
		reset_n, sys_clock	: in std_logic;	
		MEM_in_1, MEM_in_2 	: in std_logic_vector(15 downto 0); --from ALU_top_out_1(2)
		instruction_word		: in std_logic_vector(15 downto 0);	--so we can store in the st_buff with the other information to check against entry in ROB. 
		ROB_in					: in ROB;			--directly from ROB.
		
		--Control 
		MEM_out_mux_sel		: in std_logic_vector(1 downto 0);
		wr_en						: in std_logic; --write enable for data memory
		
		--Output
		MEM_out_top				: out std_logic_vector(15 downto 0)
	
	);
end MEM_top;

architecture behavioral of MEM_top is
	
	component mux_2_new is
	PORT
	(
		data0x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		data1x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		sel			: IN STD_LOGIC ;
		result		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
	END component mux_2_new;

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
	
	signal DM_st_buff_addr													: std_logic_vector(10 downto 0);
	signal DM_st_buff_data													: std_logic_vector(15 downto 0);
	signal MEM_data, MEM_address, long_st_buff_addr					: std_logic_vector(15 downto 0);
	signal data_in_reg, MEM_out_top_reg, data_out, MEM_mux_out	: std_logic_vector(15 downto 0);
	signal non_specul_out, st_buff_data, MEM_out_top_mux_out		: std_logic_vector(15 downto 0);
	signal DM_st_buff_wren, wren_non_speculative 						: std_logic;
	signal inst_is_specul													: std_logic;
	signal MEM_out_top_mux_sel												: std_logic;
	signal DM_data_in_mux_sel, DM_addr_in_mux_sel, DM_wren_in_mux_sel : std_logic;	--select signals that alternate data going to Data Memory
	signal store_inst, load_inst											: std_logic;	--denotes whether the incoming instruction word is a load or a store
	signal st_buff			 													: store_buffer;
	signal buffer_st_in														: std_logic;
begin

	DM_data_in : mux_2_new
	port map
	(
		data0x		=> MEM_in_2,
		data1x		=> DM_st_buff_data,
		sel			=> DM_data_in_mux_sel, 
		result		=> MEM_data
	);
	
	DM_addr_in : mux_2_new
	port map
	(
		data0x		=> MEM_in_1,
		data1x		=> long_st_buff_addr,
		sel			=> DM_addr_in_mux_sel,
		result		=> MEM_address
	);

	--non-speculative DM_out select mux
	non_specul_out_mux	: mux_4_new
	port map (
		data0x	=> "0000000000000000",
		data1x  	=> data_out,		--data from DM 					(data_out)
		data2x  	=> MEM_in_1,		--data from ALU output			(ALU_top_out_1)
		data3x	=> MEM_in_2,		--data forwarded through ALU 	(ALU_top_out_2)
		sel 		=> MEM_out_mux_sel,
		result  	=> non_specul_out
	);
	
	--potentially speculative mem_top output
	MEM_top_out_mux : mux_2_new
	port map
	(
		data0x		=> non_specul_out,
		data1x		=> st_buff_data,
		sel			=> MEM_out_top_mux_sel,
		result		=> MEM_out_top_mux_out
	);
	
	data_memory : DataMem
	port map
		(
			address	=> MEM_address(10 downto 0),
			clock		=> sys_clock,
			data		=> MEM_data,
			wren		=> wren_non_speculative,
			q			=> data_out
		);
		
	--these two instructions do not require implementation in a process
	store_inst		<= instruction_word(15) and not(instruction_word(14)) and not(instruction_word(13)) and not(instruction_word(12)) and instruction_word(1);
	load_inst		<= instruction_word(15) and not(instruction_word(14)) and not(instruction_word(13)) and not(instruction_word(12)) and not(instruction_word(1));
	
	long_st_buff_addr <= "00000" & DM_st_buff_addr;
	
	--process to multiplex wr_en to Data Memory in lieu of instantiating a single bit mux	
	process(DM_wren_in_mux_sel, wr_en, DM_st_buff_wren)
	begin
		if DM_wren_in_mux_sel = '0' then
			wren_non_speculative	<=  wr_en;
		else
			wren_non_speculative <= DM_st_buff_wren;
		end if;
	end process; 
	
	--need triggered process to determine if incoming instruction_word is speculative
	process(reset_n, ROB_in, instruction_word)
	begin
		if reset_n = '0' then
			inst_is_specul		<= '0';
		--now compare the incoming instruction against the ROB to determine if it's speculative still/at all
		else
			--inst_is_specul		<= check_ROB_for_speculation(ROB_in, instruction_word) and results_available and not(condition_met) and check_location_of_IW_in_ROB(ROB_in, instruction_word);
			inst_is_specul		<= check_ROB_for_speculation(ROB_in, instruction_word); 	
		end if;		
	end process;
	
	
	process(reset_n, sys_clock, MEM_in_1, store_inst, load_inst, inst_is_specul, st_buff)
	begin
		if reset_n = '0' then
			st_buff					<= init_st_buff(st_buff);
			DM_st_buff_data		<= "0000000000000000";
			DM_st_buff_addr		<= "00000000000";
			DM_st_buff_wren 		<= '0';
			
			st_buff_data			<= "0000000000000000";
			
			DM_data_in_mux_sel 	<= '0';
			DM_addr_in_mux_sel 	<= '0'; 
			DM_wren_in_mux_sel 	<= '0';
			MEM_out_top_mux_sel  <= '0';
			
			buffer_st_in			<= '0';
			
			MEM_out_top_reg 		<= "0000000000000000";
		else
			--buffer_st_in denotes that the incoming instruction/data must be buffered in st_buff since it is a store and either 1) speculative or 2) existing in st_buff under another address
			buffer_st_in			<= store_inst and (inst_is_specul or check_st_buff_for_address(st_buff, MEM_in_1(10 downto 0)));
			
			DM_data_in_mux_sel 	<= (check_st_buff_for_address(st_buff, MEM_in_1(10 downto 0)) or (not(load_inst) and (not(store_inst) or inst_is_specul))) and st_buff(0).valid and not(st_buff(0).specul);
			DM_addr_in_mux_sel 	<= (check_st_buff_for_address(st_buff, MEM_in_1(10 downto 0)) or (not(load_inst) and (not(store_inst) or inst_is_specul))) and st_buff(0).valid and not(st_buff(0).specul);
			DM_wren_in_mux_sel 	<= (check_st_buff_for_address(st_buff, MEM_in_1(10 downto 0)) or (not(load_inst) and (not(store_inst) or inst_is_specul))) and st_buff(0).valid and not(st_buff(0).specul);
			MEM_out_top_mux_sel 	<= check_st_buff_for_address(st_buff, MEM_in_1(10 downto 0)) and (load_inst or store_inst);
			
			--report "MEM_top: MEM_out_top_mux_sel = " & integer'image(convert_SL(MEM_out_top_mux_sel));
			--report "MEM_top: DM_data_in_mux_sel = " & integer'image(convert_SL(DM_data_in_mux_sel));
			--report "MEM_top: DM_addr_in_mux_sel = " & integer'image(convert_SL(DM_addr_in_mux_sel));
			--report "MEM_top: DM_wren_in_mux_sel = " & integer'image(convert_SL(DM_wren_in_mux_sel));
			
			--this first if statement is entered every time we cannot use the DM for the purpose of loading or storing, as dictated by the incoming IW
			--if (check_st_buff_for_address(st_buff, MEM_in_1(10 downto 0)) = '1') or ((not(load_inst) and (not(store_inst) or inst_is_specul)) = '1') then
			if (check_st_buff_for_address(st_buff, MEM_in_1(10 downto 0)) = '1') and ((load_inst or store_inst) = '1') then
				--have an address match in st_buff - need to add to st_buff instead
				--determine if we can execute another, non-speculative store first though
				if st_buff(0).valid = '1' and st_buff(0).specul = '0' then
					DM_st_buff_wren 	<= '1';					--wr_en signal for storing in DM from st_buff
					DM_st_buff_data 	<= st_buff(0).data;	--data for storing back to DM from st_buff
					DM_st_buff_addr 	<= st_buff(0).addr;	--address for storing back to DM from st_buff
					
					report "MEM_top: Can't use DM for ld/st, writing back st_buff data to DM";
				else
					--can neither write to DM from ALU nor write to DM from st_buff - just buffer ALU outputs in st_buff
					DM_st_buff_wren 	<= '0';
					DM_st_buff_addr	<= "00000000000";
					
					report "MEM_top: Can't use DM for ld/st or write back st_buff data to DM";
				end if;
				
				if load_inst = '1' then
					st_buff_data	<= fetch_st_buff_data(st_buff, MEM_in_1(10 downto 0));
					report "MEM_top: Have address match in st_buff, loading data from st_buff";
				end if;
			else
				--include as a catch-all for this clock cycle
				DM_st_buff_wren 	<= '0';
				DM_st_buff_addr	<= "00000000000";
				report "MEM_top: Hit else statement, do nothing with DM";
			end if;
			
			if rising_edge(sys_clock) then
--				report "MEM_top: MEM_out_top_mux_sel = " & integer'image(convert_SL(MEM_out_top_mux_sel));
--				report "MEM_top: DM_data_in_mux_sel = " & integer'image(convert_SL(DM_data_in_mux_sel));
--				report "MEM_top: DM_addr_in_mux_sel = " & integer'image(convert_SL(DM_addr_in_mux_sel));
--				report "MEM_top: DM_wren_in_mux_sel = " & integer'image(convert_SL(DM_wren_in_mux_sel));
--				
				--now update st_buff. options: 
					--1) buffer incoming store (buffer_st_in) 
					--2) shift st_buff down (DM_wren_in_mux_sel)
					--3) clear/re-mark st_buff instructions as non-speculative (ROB_in) 
					
				st_buff				<= update_st_buff(st_buff, MEM_in_1(10 downto 0), MEM_in_2, buffer_st_in, DM_wren_in_mux_sel, ROB_in, instruction_word); 
				MEM_out_top_reg 	<= MEM_out_top_mux_out;
			end if; 
		end if; --reset_n
	end process;
	
	--latch inputs

	--latch outputs
	MEM_out_top <= MEM_out_top_reg;
	
end behavioral;