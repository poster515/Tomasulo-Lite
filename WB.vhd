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
		immediate_val	: out	std_logic_vector(15 downto 0);	--represents various immediate values from various OpCodes
		
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
	
	--type declaration for actual ROB, which has 10 entries
	type ROB is array(ROB_DEPTH - 1 downto 0) of ROB_entry;
	
	signal result		: std_logic_vector(15 downto 0); --buffers result from A or C bus
	signal ROB_actual	: ROB := (
											others => ( 
												inst => (others => '0'), 
												complete => '0', 
												valid => '0', 
												result = > (others => '0')
											)
										);
	
	-- FUNCTION DEFINITIONS -- 
	
	function bufferPM_IW( 
		ROB_in 		: in ROB; 
		PM_data_in 	: in std_logic_vector(15 downto 0)))
   
	return ROB is
	
	variable ROB_temp	: ROB;
	variable i			: integer range 0 to ROB_DEPTH - 1;
	
	begin
		ROB_temp <= ROB_in;
		
		for i in 0 to ROB_DEPTH - 1 loop
			
			if ROB_temp(i).valid = '0';
			
				--found an invalid instruction, buffer new instruction at this spot
				ROB_temp(i).valid <= '1';
				ROB_temp(i).inst <= PM_data_in;
				exit;
			end if;
		end loop;
  
		return ROB_temp;
   end;
 
	function update_result( 
		ROB_in 		: in ROB; 
		IW_in			: in std_logic_vector(15 downto 0);
		result		: in std_logic_vector(15 downto 0))
   
	return std_logic is
	
	variable ROB_temp	: ROB;
	variable i			: integer range 0 to ROB_DEPTH - 1;
	 
	begin
		ROB_temp <= ROB_in;
	
		for i in 0 to ROB_DEPTH - 1 loop
			if ROB_temp(i).inst = IW_in and ROB_temp(i).valid = '1';
				-- if the incoming instruction matches one in the ROB, update result
				ROB_temp(i).result <= result;
				ROB_temp(i).complete <= '1';
				exit; --no need to continue in the loop
			end if;  --ROB_temp(i).inst = IW_in
		end loop;
		
		return ROB_temp;
	end;
	
begin
	process(reset_n, sys_clock)
	begin
		if reset_n = '0' then
			
		elsif rising_edge(sys_clock) then
		
			--select A or C bus when appropriate, should be independent of stall signal
			result <= 	A_bus when A_bus_in_sel = '1' else
							C_bus when C_bus_in_sel = '1' else
							result;
			
			if LAB_stall_in = '0' then
			
				--buffer instruction issued from PM
				ROB <= bufferPM_IW(ROB, PM_data_in);
				
				--not sure if tags are needed. just look for matching instruction, update 'result', and commit if it's in order.
				--update tag for instruction sent to ID stage
				--ROB <= update_tag(ROB, ID_IW, tag);
				ROB <= update_result(ROB, IW_in, result);

				-- if zeroth entry is valid, commit to RF
				if (ROB(0).complete = '1') then
				
					--for all jumps (1001), BNE(Z) (1010...X0), all stores (1000...1X), and GPIO/I2C writes (1011..X1) don't need any RF output written back
					if 	(IW_in(15 downto 12) = "1001") or
							(IW_in(15 downto 12) = "1010" and IW_in(1 downto 0) = "X0") or
							(IW_in(15 downto 12) = "1000" and IW_in(1 downto 0) = "1X") or
							(IW_in(15 downto 12) = "1011" and IW_in(1 downto 0) = "X1") then 
						
						RF_in_demux <= "00000";
						RF_in_en <= '0';
						wr_en <= '0';
					
					--for all "0XXX" instructions, all loads (1000...0X), and GPIO/I2C (1011..X0) reads, need an RF write back
					elsif IW_in(15 downto 12) = "0XXX" or 
							(IW_in(15 downto 12) = "1000" and IW_in(1 downto 0) = "0X") or  
							(IW_in(15 downto 12) = "1011" and IW_in(1 downto 0) = "X0") then
							
						RF_in_demux <= IW_in(11 downto 7);	--use IW to find destination register for the aforementioned instructions
						RF_in_en <= '1';
						wr_en <= '1';
						
					--TODO: for all other instructions, shouldn't need any write back to RF?
					else
						RF_in_demux <= "00000";
						RF_in_en <= '0';
						wr_en <= '0';
						
					end if;
					
					--now shift down all instructions in ROB
					ROB <= reorder(ROB);
					
				end if; -- ROB_zero_complete
				
			elsif LAB_stall_in = '1' then
				
--				RF_in_demux <= RF_in_demux;
--				RF_in_en 	 <= RF_in_en;

			end if; --LAB_stall_in

		end if; --reset_n
	end process;
	
	--latch inputs
	
	--latch outputs
	
end behavioral;