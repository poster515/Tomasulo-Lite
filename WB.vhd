--Written by: Joe Post

--This file generates control signals necessary to forward data to other pipeline stages and write back data to RF.
--This file will not contain the RF however. 
--This file will also contain a ROB which contains each instruction as it is issued from PM (i.e., in order), and 
-- will only commit in-order the results. 


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.arrays.ALL;

entity WB is
   port ( 
		--Input data and clock
		reset_n, sys_clock	: in std_logic;	
		IW_in, PM_data_in		: in std_logic_vector(15 downto 0); --IW from MEM and from PM, via LAB, respectively
		LAB_stall_in			: in std_logic;		--set high when an upstream CU block needs this 
		
		--Control
		RF_in_demux			: out std_logic_vector(4 downto 0);
		RF_in_en, wr_en	: out std_logic;	-- RF_in_en sent to CSAM for arbitration. wr_en also sent to CSAM, although it's passed through. 
					
		--Outputs
		stall_out		: out std_logic;
		immediate_val	: out	std_logic_vector(15 downto 0)--represents various immediate values from various OpCodes
	);
end WB;

architecture behavioral of WB is

	type ROB_entry is
		record
		  inst		: std_logic_vector(15 downto 0);	--buffers instruction
		  tag       : integer range 0 to 4; 			--provides unique identifier for inst in pipeline	
		  valid		: std_logic;
		end record;
		
	type IWB_entry is
		record
		  inst		: std_logic_vector(15 downto 0);	--buffers instruction
		  tag       : integer range 0 to 4; 			--provides unique identifier for inst in pipeline	
		  valid		: std_logic;
		end record;
	
	--type declaration for actual ROB, which has 5 entries
	type ROB is array(4 downto 0) of ROB_entry;
	
	--type declaration for actual IWB, which has 10 entries
	type IWB is array(9 downto 0) of IWB_entry;
	
begin
	process(reset_n, sys_clock)
	begin
		if reset_n = '0' then
			
		elsif rising_edge(sys_clock) then
		
			if LAB_stall_in = '0' then
			
				--buffer PM_data_in to IWB
				IWB <= bufferIW(IWB, PM_data_in);
			
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
				
				--now buffer IW from PM in ROB
				ROB <= reorder(ROB);

			elsif LAB_stall_in = '1' then
				
--				RF_in_demux <= RF_in_demux;
--				RF_in_en 	 <= RF_in_en;

			end if; --LAB_stall_in

		end if; --reset_n
	end process;
	
	--latch inputs
	
	--latch outputs
	
end behavioral;