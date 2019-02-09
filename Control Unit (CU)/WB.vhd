--Written by: Joe Post

--This file generates control signals necessary to forward data to other pipeline stages and write back data to RF.
--This file will not contain the RF however. 
--This file will also contain a ROB which contains each instruction as it is issued from PM (i.e., in order), and 
-- will only commit in-order the results. 


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
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
		WB_data_out		: out std_logic_vector(15 downto 0)
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
	
	function bufferPM_IW( 
		ROB_in 		: in ROB; 
		PM_data_in 	: in std_logic_vector(15 downto 0))
   
	return ROB is
	
	variable ROB_temp	: ROB := ROB_in;
	variable i			: integer range 0 to ROB_DEPTH - 1;
	
	begin
		
		for i in 0 to ROB_DEPTH - 1 loop
			
			if ROB_temp(i).valid = '0' then
			
				--found an invalid instruction, buffer new instruction at this spot
				ROB_temp(i).valid := '1';
				ROB_temp(i).inst := PM_data_in;
				exit;
			end if;
		end loop;
  
		return ROB_temp;
   end;
	
	--function to buffer result into ROB if zeroth instruction doesn't match IW_in
	function buffer_result( 
		ROB_in 	: in ROB; 
		result 	: in std_logic_vector(15 downto 0);
		IW_in		: in std_logic_vector(15 downto 0);
		PM_data_in	: in std_logic_vector(15 downto 0))
   
	return ROB is
	
	variable ROB_temp	: ROB := ROB_in;
	variable i			: integer range 0 to ROB_DEPTH - 1;
	
	begin
		
		for i in 0 to ROB_DEPTH - 1 loop
			
			if ROB_temp(i).valid = '1' and ROB_temp(i).inst = IW_in then
				report "Found matching IW in ROB at location " & Integer'image(i) & ", writing back result...";
				ROB_temp(i).result := result;
				ROB_temp(i).complete := '1';
				
			elsif ROB_temp(i).valid = '0' then
			
				ROB_temp(i).inst := PM_data_in;
				ROB_temp(i).valid := '1';
				exit;
			end if;
		end loop;
  
		return ROB_temp;
   end;
	
	
	--this function reorders the buffer to eliminate stale/committed instructions and results
	function update_ROB( 
		ROB_in 		: in ROB;
		PM_data_in	: in std_logic_vector(15 downto 0))
   
	return ROB is
	
	variable ROB_temp	: ROB := ROB_in;
	variable i			: integer range 0 to ROB_DEPTH - 1;
	 
	begin
	
		for i in 0 to ROB_DEPTH - 2 loop
			if ROB_temp(i).valid = '0' then
				ROB_temp(i).inst := PM_data_in;
				ROB_temp(i).valid := '1';
				exit;
				
			elsif ROB_temp(i).valid = '1' and ROB_temp(i + 1).valid = '0' then
				ROB_temp(i).inst := PM_data_in;
				ROB_temp(i).valid := '1';
				exit;
				
			else
				ROB_temp(i) := ROB_temp(i + 1);
			end if;
		end loop;
		
		--ROB_temp(ROB_DEPTH - 1) := ( (others => '0'), '0', '0', (others => '0'));

		return ROB_temp;
	end;
	
	--function buffers result from previous cycle if zero_inst_match = 0 and zero_inst_match = 1 this cycle
	--clears the zeroth instruction as well since inst_match = 1 this cycle
	function buffer_result_clear_zero (
		ROB_in 	: in ROB; 
		result 	: in std_logic_vector(15 downto 0);
		IW_in		: in std_logic_vector(15 downto 0);
		PM_data_in	: in std_logic_vector(15 downto 0))
   
	return ROB is
	
	variable ROB_temp	: ROB := ROB_in;
	variable i			: integer range 0 to ROB_DEPTH - 1;
	
	begin
		
		for i in 1 to ROB_DEPTH - 2 loop
			if ROB_temp(i).valid = '0' then --should never get into this particular case
				ROB_temp(i).inst := PM_data_in;
				ROB_temp(i).valid := '1';
				exit;
				
			elsif ROB_temp(i).valid = '1' then
			
				if ROB_temp(i).inst = IW_in then
					report "Found matching IW in ROB at location " & Integer'image(i) & ", writing back result...";
					ROB_temp(i - 1).inst := IW_in;
					ROB_temp(i - 1).valid := '1';
					ROB_temp(i - 1).result := result;
					ROB_temp(i - 1).complete := '1';
					
				end if;
				
				if ROB_temp(i + 1).valid = '0' then
					ROB_temp(i).inst := PM_data_in;
					ROB_temp(i).valid := '1';
					exit; --exit since we reached the end of the ROB scanning needs
				
				end if;
					
			else
				ROB_temp(i) := ROB_temp(i + 1);
			end if;
			
		end loop;
  
		return ROB_temp;
   end;
	
	signal NZM_nxt_cycle : std_logic;
	--type write_back_state is {reset, stalled, no_zero_match, zero_match, unknown};
---------------------------------------------------------------	
begin

	--mux for WB output
	WB_out_mux	: mux_4_new
	port map (
		data0x	=> "0000000000000000",
		data1x  	=> MEM_out_top, 		
		data2x  	=> GPIO_out,
		data3x	=> I2C_out,
		sel 		=> WB_out_mux_sel,
		result  	=> WB_data_out
	);
	
	stall <= LAB_stall_in;
	
	--update whether ROB zeroth instruction matches the new IW_in, does not depend on ROB(0).inst itself since it won't change
	process(IW_in, sys_clock)
	begin
		if ROB_actual(0).inst = IW_in and ROB_actual(0).valid = '1' then
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
			NZM_nxt_cycle	<= '0';
			
		elsif rising_edge(sys_clock) then
			
			if stall = '0' then
			
				stall_out <= '0';

				if zero_inst_match = '1' then --have a match to zeroth ROB inst and therefore re-issue result
					
					--report "Zeroth instruction matches IW_in.";
					if reset_MEM = '1' then
					
						if NZM_nxt_cycle = '0' then
					
							--report "Made it to ROB reorder code.";
							ROB_actual <= update_ROB(ROB_actual, PM_data_in);
							RF_in_demux <= IW_in(11 downto 7);	--use IW to find destination register for the aforementioned instructions
						
							--for loads and ALU operations, forward MEM_top_data to RF
							if ((IW_in(15 downto 12) = "1000") and (IW_in(1) = '0')) or (IW_in(15) = '0') or
									(IW_in(15 downto 12) = "1100") then
								WB_out_mux_sel <= "01";
								RF_wr_en <= '1';

							--GPIO reads
							elsif (IW_in(15 downto 12) = "1011" and IW_in(1 downto 0) = "00") then
								WB_out_mux_sel <= "10";
								RF_wr_en <= '1';
											
							--I2C reads	
							elsif (IW_in(15 downto 12) = "1011" and IW_in(1 downto 0) = "10") then
								WB_out_mux_sel <= "11";
								RF_wr_en <= '1';

							else
								WB_out_mux_sel <= "00";
								RF_wr_en <= '0';
								
							end if; --
						
						elsif NZM_nxt_cycle = '1' then
						
							NZM_nxt_cycle	<= '0';
					
							if IW_in(15 downto 12) = "1000" and IW_in(1) = '0' then --don't have a match to zeroth instruction, receiving load data
								
								--buffer A_bus_result in ROB_actual
								ROB_actual <= buffer_result_clear_zero(ROB_actual, MEM_out_top, IW_in, PM_data_in);
								
							elsif IW_in(15 downto 12) = "1011" and IW_in(1 downto 0) = "00" then --don't have a match to zeroth instruction, receiving GPIO data in
								
								--buffer C_bus_result in ROB_actual
								ROB_actual <= buffer_result_clear_zero(ROB_actual, GPIO_out, IW_in, PM_data_in);
								
							elsif IW_in(15 downto 12) = "1011" and IW_in(1 downto 0) = "10" then --don't have a match to zeroth instruction, receiving I2C data in
								
								--buffer C_bus_result in ROB_actual
								ROB_actual <= buffer_result_clear_zero(ROB_actual, I2C_out, IW_in, PM_data_in);

							end if; --IW_in (various)
						end if; --NZM_nxt_cycle
							
					end if; --reset_MEM	
				else 
					if NZM_nxt_cycle = '0' then
							--need to update ROB since the incoming IW last cycle didn't match the ROB(0).inst entry
							RF_wr_en <= '0';
							NZM_nxt_cycle	<= '1';
							
					elsif NZM_nxt_cycle = '1' then
					
						if IW_in(15 downto 12) = "1000" and IW_in(1) = '0' then --don't have a match to zeroth instruction, receiving load data
							
							--buffer A_bus_result in ROB_actual
							ROB_actual <= buffer_result(ROB_actual, MEM_out_top, IW_in, PM_data_in);
							RF_wr_en <= '0';
							
						elsif IW_in(15 downto 12) = "1011" and IW_in(1 downto 0) = "00" then --don't have a match to zeroth instruction, receiving GPIO data in
							
							--buffer C_bus_result in ROB_actual
							ROB_actual <= buffer_result(ROB_actual, GPIO_out, IW_in, PM_data_in);
							RF_wr_en <= '0';
							
						elsif IW_in(15 downto 12) = "1011" and IW_in(1 downto 0) = "10" then --don't have a match to zeroth instruction, receiving I2C data in
							
							--buffer C_bus_result in ROB_actual
							ROB_actual <= buffer_result(ROB_actual, I2C_out, IW_in, PM_data_in);
							RF_wr_en <= '0';
							
						else --just default to buffering the incoming PM data, if the CU/MEM output reset signal is high
							ROB_actual <= bufferPM_IW(ROB_actual, PM_data_in);
							RF_wr_en <= '0';
							
						end if; --IW_in (various)
					end if; --NZM_nxt_cycle

				end if; --zero_inst_match
				
			elsif stall = '1' then
				
				RF_wr_en <= '0';
				stall_out <= '1';

			end if; --LAB_stall_in

		end if; --reset_n
	end process;
	
end behavioral;