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
		reset_n, sys_clock	: in std_logic;	
		IW_in, PM_data_in		: in std_logic_vector(15 downto 0); --IW from MEM and from PM, via LAB, respectively
		LAB_stall_in			: in std_logic;		--set high when an upstream CU block needs this 
		
		--Control
		RF_in_demux			: out std_logic_vector(4 downto 0); -- selects which 
		RF_in_en, wr_en	: out std_logic;	-- RF_in_en sent to CSAM for arbitration. wr_en also sent to CSAM, although it's passed through. 
		A_bus_in_sel		: in std_logic; 	-- from CSAM, selects data from memory stage to buffer in ROB
		C_bus_in_sel		: in std_logic; 	-- from CSAM, selects data from memory stage to buffer in ROB
		B_bus_out_en		: in std_logic;	-- from CSAM, if '1', we can write result on B_bus
		C_bus_out_en		: in std_logic;	-- from CSAM, if '1', we can write result on C_bus
					
		--Outputs
		stall_out		: out std_logic;

		--Inouts
		A_bus, B_bus, C_bus	: inout std_logic_vector(15 downto 0) --A/C bus because we need access to memory stage outputs, B/C bus because RF has access to them
	);
end WB;

architecture behavioral of WB is

	type ROB_entry is
		record
		  inst		: std_logic_vector(15 downto 0);	--buffers instruction
		  complete  : std_logic; 							-- 0 = no result yet, 1 = valid result buffered
		  valid		: std_logic;							--tracks if valid instruction buffered
		  result		: std_logic_vector(15 downto 0); --buffers result. 
		end record;
	
	type ROB is array(ROB_DEPTH - 1 downto 0) of ROB_entry;
	
	signal stall, zero_inst_match			: std_logic; --overall stall signal;
	signal A_bus_result, C_bus_result	: std_logic_vector(15 downto 0); --buffers result from A or C bus
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
	
---------------------------------------------------------------	
begin
	
	stall <= LAB_stall_in;
	
	--buffer A and C bus every time they change
	process(A_bus, C_bus)
	begin
	
		A_bus_result <= A_bus;
		C_bus_result <= C_bus;
		
	end process;
	
	--update whether ROB zeroth instruction matches the new IW_in, does not depend on ROB(0).inst itself since it won't change
	process(ROB_actual, IW_in)
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
			stall_out <= '0';
			A_bus <= "ZZZZZZZZZZZZZZZZ";
			B_bus <= "ZZZZZZZZZZZZZZZZ";
			C_bus <= "ZZZZZZZZZZZZZZZZ";
			RF_in_demux <= "00000";
			RF_in_en <= '0';
			wr_en <= '0';
			
		elsif rising_edge(sys_clock) then
			
			if stall = '0' then
			
				
				stall_out <= '0';

				if zero_inst_match = '1' then --have a match to zeroth ROB inst and therefore re-issue result
					
					--report "Made it to ROB reorder code.";
					ROB_actual <= update_ROB(ROB_actual, PM_data_in);
					
					--report "Zeroth instruction matches IW_in.";
					if A_bus_in_sel = '1' and B_bus_out_en = '1' then
					
						B_bus <= A_bus_result;
						
					elsif A_bus_in_sel = '1' and C_bus_out_en = '1' then
							
						C_bus <= C_bus_result;
						
					elsif C_bus_in_sel = '1' and B_bus_out_en = '1' then	
					
						B_bus <= C_bus_result;
						
					elsif C_bus_in_sel = '1' and C_bus_out_en = '1' then	
					
						C_bus <= C_bus_result;
						
					else		
						B_bus <= "ZZZZZZZZZZZZZZZZ";	
						C_bus <= "ZZZZZZZZZZZZZZZZ";	
							
					end if; -- A_bus_in_sel
					
					--for all jumps (1001), BNE(Z) (1010...X0), all stores (1000...1X), and GPIO/I2C writes (1011..X1) don't need any RF output written back
					if 	IW_in(15 downto 12) = "1001" or
							(IW_in(15 downto 12) = "1010" and IW_in(0) = '0') or
							(IW_in(15 downto 12) = "1000" and IW_in(1) = '1') or
							(IW_in(15 downto 12) = "1011" and IW_in(0) = '1') then 
						
						RF_in_demux <= "00000";
						RF_in_en <= '0';
						wr_en <= '0';
					
					--for all "0XXX" instructions, all loads (1000...0X), and GPIO/I2C (1011..X0) reads, need an RF write back
					elsif IW_in(15) = '0' or 
							(IW_in(15 downto 12) = "1000" and IW_in(1) = '0') or  
							(IW_in(15 downto 12) = "1011" and IW_in(0) = '0') then
							
						--report "Updating RF output control signals.";
						RF_in_demux <= IW_in(11 downto 7);	--use IW to find destination register for the aforementioned instructions
						RF_in_en <= '1';
						wr_en <= '1';
						
					--TODO: for all other instructions, shouldn't need any write back to RF?
					else
						RF_in_demux <= "00000";
						RF_in_en <= '0';
						wr_en <= '0';
						
					end if;

				elsif A_bus_in_sel = '1' then --don't have a match to zeroth instruction
					
					--buffer A_bus_result in ROB_actual
					ROB_actual <= buffer_result(ROB_actual, A_bus_result, IW_in, PM_data_in);
					
				elsif C_bus_in_sel = '1' then --don't have a match to zeroth instruction
					
					--buffer C_bus_result in ROB_actual
					ROB_actual <= buffer_result(ROB_actual, C_bus_result, IW_in, PM_data_in);
					
				else
				
					ROB_actual <= bufferPM_IW(ROB_actual, PM_data_in);

				end if; --zero_inst_match
				
			elsif stall = '1' then
				
				stall_out <= '1';

			end if; --LAB_stall_in

		end if; --reset_n
	end process;
	
	--latch inputs
	
	--latch outputs
	
end behavioral;