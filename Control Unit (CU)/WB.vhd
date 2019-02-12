--Written by: Joe Post

--This file generates control signals necessary to forward data to other pipeline stages and write back data to RF.
--This file will not contain the RF however. 
--This file will also contain a ROB which contains each instruction as it is issued from PM (i.e., in order), and 
-- will only commit in-order the results. 


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.arrays.ALL;

entity WB is
	generic ( ROB_DEPTH : integer := 10 );
   port ( 
		--Input data and clock
		reset_n, reset_MEM 	: in std_logic;
		sys_clock				: in std_logic;	
		IW_in, PM_data_in		: in std_logic_vector(15 downto 0); --IW from MEM and from PM, via LAB, respectively
		LAB_stall_in			: in std_logic;		--set high when an upstream CU block needs this 
		MEM_out_top				: in std_logic_vector(15 downto 0);
		GPIO_out					: in std_logic_vector(15 downto 0);
		I2C_out					: in std_logic_vector(15 downto 0);
		
		--Control
		RF_in_demux				: out std_logic_vector(4 downto 0); -- selects which register to write back to
		RF_wr_en					: out std_logic;	--
					
		--Outputs
		stall_out		: out std_logic;
		WB_data_out		: inout std_logic_vector(15 downto 0)
	);
end WB;

architecture behavioral of WB is

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

	type ROB_entry is
		record
		  inst		: std_logic_vector(15 downto 0);	--buffers instruction
		  complete  : std_logic; 							-- 0 = no result yet, 1 = valid result buffered
		  valid		: std_logic;							--tracks if valid instruction buffered
		  result		: std_logic_vector(15 downto 0); --buffers result. 
		end record;
	
	type ROB is array(ROB_DEPTH - 1 downto 0) of ROB_entry;
	
	signal WB_out_mux_sel					: std_logic_vector(1 downto 0); --selects data input to redirect to RF
	signal stall, zero_inst_match			: std_logic; --overall stall signal;
	signal PM_data_in_reg, IW_to_update : std_logic_vector(15 downto 0);
	signal PM_data_valid, IW_update_en	: std_logic;
	signal clear_zero_inst 					: std_logic;
	signal i	: integer range 0 to ROB_DEPTH - 1;
	
	--type declaration for actual ROB, which has 10 entries
	signal ROB_actual	: ROB := (
											others => ( 
												inst => (others => '0'), 
												complete => '0', 
												valid => '0', 
												result => (others => '0')
											)
										);
	
	-- FUNCTION DEFINITIONS -- 
	
	function initialize_ROB(ROB_in : in ROB)
   
	return ROB is
	
	variable ROB_temp	: ROB := ROB_in;
	variable i			: integer range 0 to ROB_DEPTH - 1;
	
	begin
		
		for i in 0 to ROB_DEPTH - 1 loop
			
			ROB_temp(i).valid 	:= '0';
			ROB_temp(i).complete := '0';
			ROB_temp(i).inst 		:= "0000000000000000";
			ROB_temp(i).result	:= "0000000000000000";
			
		end loop;
  
		return ROB_temp;
   end;
	
	--function to type convert std_logic to integer
	function convert_CZ ( clear_zero : in std_logic )
	
	return integer is

	begin
	
		if clear_zero = '1' then
			return 1;
		else
			return 0;
		end if;
		
	end;
	
	--this function reorders the buffer to eliminate stale/committed instructions and results
	function update_ROB( 
		ROB_in 			: in ROB;
		PM_data_in		: in std_logic_vector(15 downto 0);
		PM_buffer_en	: in std_logic;
		IW_in				: in std_logic_vector(15 downto 0);
		IW_result		: in std_logic_vector(15 downto 0);
		IW_result_en	: in std_logic;
		clear_zero		: in std_logic
		)
   
	return ROB is
	
	variable ROB_temp	: ROB := ROB_in;
	variable i			: integer range 0 to ROB_DEPTH - 1;
	variable n_clear_zero	: integer := 0;
	variable IW_updated	: std_logic := '0';
	 
	begin
	
		n_clear_zero := convert_CZ(not(clear_zero));
		
		for i in 0 to ROB_DEPTH - 2 loop
		
			if ROB_temp(i).valid = '0' then
			
				if PM_buffer_en = '1' then
					report "Buffering PM_data_in at ROB slot " & integer'image(i);
					ROB_temp(i).inst 	:= PM_data_in;
					ROB_temp(i).valid := '1';
					exit;
				end if;
			
			elsif ROB_temp(i).valid = '1' and ROB_temp(i + 1).valid = '0' then
			
				if PM_buffer_en = '1' then
					report "Buffering PM_data_in at ROB slot " & integer'image(i + n_clear_zero);
					ROB_temp(i + n_clear_zero).inst 	:= PM_data_in;
					ROB_temp(i + n_clear_zero).valid := '1';
					exit;
				end if;

			elsif ROB_temp(i + 1).valid = '1' and ROB_temp(i + 1).inst = IW_in then
			
				if IW_result_en = '1' and IW_updated = '0' then
					report "Updating ROB entry at slot " & integer'image(i + 1);
					ROB_temp(i + n_clear_zero).result 		:= IW_result;
					ROB_temp(i + n_clear_zero).inst 			:= ROB_temp(i + 1).inst;
					ROB_temp(i + n_clear_zero).valid 		:= '1';
					ROB_temp(i + n_clear_zero).complete 	:= '1';
					IW_updated := '1';
				end if;
				
			else

				ROB_temp(i) := ROB_temp(i + convert_CZ(clear_zero));
				
			end if; --ROB_temp(i).valid
			
		end loop;
		
		return ROB_temp;
	end;
	
	
---------------------------------------------------------------	
begin

	--mux for WB output
	WB_out_mux	: mux_4_new
	port map (
		data0x	=> ROB_actual(0).result,
		data1x  	=> MEM_out_top, 		
		data2x  	=> GPIO_out,
		data3x	=> I2C_out,
		sel 		=> WB_out_mux_sel,
		result  	=> WB_data_out
	);
	
	stall <= LAB_stall_in;
	
	--update whether ROB zeroth instruction matches the new IW_in, does not depend on ROB(0).inst itself since it won't change
	process(IW_in)
	begin
		if ROB_actual(0).inst = IW_in and ROB_actual(0).valid = '1' and zero_inst_match = '0' then
			zero_inst_match <= '1';
		
		elsif ROB_actual(1).inst = IW_in and ROB_actual(1).valid = '1' and zero_inst_match = '1' then
			zero_inst_match <= '1';
		
		else
			zero_inst_match <= '0';
		end if;
	end process;

	process(reset_n, sys_clock, stall)
	begin
		if reset_n = '0' then
			stall_out 		<= '0';
			RF_in_demux 	<= "00000";
			RF_wr_en 		<= '0';
			WB_out_mux_sel <= "01";
			clear_zero_inst <= '0'; 
			IW_update_en	<= '0';
			PM_data_valid	<= '0';
			PM_data_in_reg <= "0000000000000000";
			IW_to_update	<= "0000000000000000";
			
		elsif rising_edge(sys_clock) then
			
			if stall = '0' then
			
				--have to ensure that new PM_data_in is buffered
				PM_data_in_reg <= PM_data_in;
				PM_data_valid	<= '1';	--enables buffering PM_data_in into ROB
				stall_out <= '0';

				if zero_inst_match = '1' then --have a match to zeroth ROB inst and therefore re-issue result
					
					--if reset_MEM = '1', then we know incoming data and IW_in are valid, and can choose to do something with them
					if reset_MEM = '1' then
					
						IW_update_en		<= '0'; --enables updating an ROB instruction with the applicable results
						clear_zero_inst 	<= '1'; --enable clearing the zeroth instruction since zero_inst_match = '1'
						RF_in_demux 		<= IW_in(11 downto 7);	--use IW to find destination register for the aforementioned instructions
						RF_wr_en 			<= '1';	--enable writing back into RF
						
					else
						RF_wr_en 			<= '0'; --disable writing back into RF
						clear_zero_inst 	<= '0'; --disable clearing the zeroth instruction since zero_inst_match = '1'
					
					end if; --reset_MEM	
				else --IW_in does not match zeroth instruction, therefore need to buffer results in ROB
				
					clear_zero_inst 	<= '0'; --disable clearing the zeroth instruction
				
					--if reset_MEM = '1', then we know incoming data and IW_in are valid, and can choose to do something with them
					if reset_MEM = '1' then
					
						IW_to_update		<= IW_in;
						IW_update_en		<= '1';
						
						if ROB_actual(0).complete = '1' then
							RF_wr_en 			<= '1';
						else 
							RF_wr_en 			<= '0';
						end if;
						
					else
						--don't buffer IW_in results since reset_MEM = '0'
						IW_update_en		<= '0';
						RF_wr_en 			<= '0';
						
					end if;
					
				end if; --zero_inst_match
				
				--this if..else series assigns the correct data input corresponding to IW_in
				if ROB_actual(0).complete = '1' then
					WB_out_mux_sel <= "00";
					
				--for loads and ALU operations, forward MEM_top_data to RF
				elsif ((IW_in(15 downto 12) = "1000") and (IW_in(1) = '0')) or (IW_in(15) = '0') or
						(IW_in(15 downto 12) = "1100") then
					WB_out_mux_sel <= "01";
					
				--GPIO reads
				elsif (IW_in(15 downto 12) = "1011" and IW_in(1 downto 0) = "00") then
					WB_out_mux_sel <= "10";
								
				--I2C reads	
				elsif (IW_in(15 downto 12) = "1011" and IW_in(1 downto 0) = "10") then
					WB_out_mux_sel <= "11";
					
				else
					WB_out_mux_sel <= "00";
					
				end if; ----IW_in (various)
				
			elsif stall = '1' then
				
				RF_wr_en <= '0';
				stall_out <= '1';
				PM_data_valid	<= '0';
				
			end if; --LAB_stall_in

		end if; --reset_n
	end process;
	
	ROB_process : process(reset_n, sys_clock)
	begin
		if reset_n = '0' then
		
			--reset ROB
			ROB_actual <= initialize_ROB(ROB_actual);
			
		elsif sys_clock'event and sys_clock = '1' then
			--update_ROB parameters:
			
--			ROB_in 			: in ROB;
--			PM_data_in		: in std_logic_vector(15 downto 0);
--			PM_buffer_en	: in std_logic;
--			IW_in				: in std_logic_vector(15 downto 0);
--			IW_result		: in std_logic_vector(15 downto 0);
--			IW_result_en	: in std_logic;
--			clear_zero		: in std_logic
			
			--values set in main portion of WB
--			PM_data_in_reg 	
--			PM_data_valid		
--			IW_to_update		
--			IW_update_en		
--			clear_zero_inst 	
			
			ROB_actual <= update_ROB(ROB_actual, PM_data_in_reg, PM_data_valid, IW_to_update, WB_data_out, IW_update_en, clear_zero_inst);
		end if; --reset_n
	end process;
	
end behavioral;