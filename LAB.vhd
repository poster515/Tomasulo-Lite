-- Written by Joe Post

--Credit for a majority of this source goes to Peter Samarin: https://github.com/oetr/FPGA-I2C-Slave/blob/master/I2C_slave.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
------------------------------------------------------------
entity LAB is
	port (

		sys_clock, reset_n  	: in std_logic;
		stall_pipeline			: in std_logic; --needed when waiting for certain commands, should be formulated in top level CU module
		ID_op1, ID_op2			: in std_logic_vector(4 downto 0); --source registers for instruction in ID stage
		EX_op1, EX_op2			: in std_logic_vector(4 downto 0); --source registers for instruction in EX stage
		MEM_op1, MEM_op2		: in std_logic_vector(4 downto 0); --source registers for instruction in MEM stage (results available)
		WB_op1, WB_op2			: in std_logic_vector(4 downto 0); --source registers for instruction in WB stage (results available)
		complete_inst_tag		: in integer;	--input from WB stage, which denotes the tag of the instruction that has been written back, only valid for single clock
		
		
		PM_data_in		: in 	std_logic_vector(15 downto 0);
		PM_address		: out std_logic_vector(10 downto 0);
		PM_clk_en		: out std_logic;
	);
end entity LAB;

------------------------------------------------------------
architecture arch of LAB is

	
	type MOAB_entry is
		record
		  data		: std_logic_vector(15 downto 0);	--buffers data such as memory addresses 
		  tag       : integer range 0 to 4; 			--associated with inst currently in LAB
		  valid     : std_logic; 							--0 = not valid/not used, 1 = valid and in pipeline or waiting for commit 	
		end record;

	type LAB_entry is
		record
		  inst		: std_logic_vector(15 downto 0);	--buffers instruction
		  tag       : integer range 0 to 4; 			--provides unique identifier for inst in pipeline
		  valid     : std_logic; 							--0 = not valid/not used, 1 = valid and in pipeline or waiting for commit 	
		end record;
	
	--type declaration for actual MOAB, which has 5 entries, one for each pipeline stage
	type MOAB_actual is array(4 downto 0) of MOAB_entry;
	
	--type declaration for actual LAB, which has 5 entries, one for each pipeline stage
	type LAB_actual is array(4 downto 0) of LAB_entry;
		
	--create array of LAB_entry to create LAB, and initialize to all zeroes
	signal LAB	: LAB_actual;
	
	--signal to enable the system clock on the PM
	signal PM_clk_en	: std_logic;
	
	--output of PM (i.e., program instructions)
	signal PM_data	: std_logic_vector(15 downto 0);
	
	--signal to denote that LAB is full and we need to stall PM input clock
	signal LAB_full	: std_logic := '0';
	
--	component PM is
--	port (
--		address	: IN STD_LOGIC_VECTOR (10 DOWNTO 0);
--		clken		: IN STD_LOGIC  := '1';
--		clock		: IN STD_LOGIC  := '1';
--		q			: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
--	);
--	end component PM;
	
	--function which initializes LAB	tags									
	function init_LAB (	LAB_in	: in 	LAB_actual ) 
		return LAB_actual is
								
		variable i 			: integer 		:= 0;	
		variable LAB_temp : LAB_actual 	:= LAB_in;
		
	begin
		
		for i in 0 to 4 loop
			LAB_temp(i).inst		:= "0000000000000000";
			LAB_temp(i).tag 		:= i;
			LAB_temp(i).valid		:= '0';
		end loop; --for i
		
		return LAB_temp;
	end function;
	
	--function to determine if there are any open LAB spots	
	--if an open spot exists, take it:	(return [spot to take])
	--if not, return a stall 			:	(return 5 since there is no fifth spot in LAB)
	function find_LAB_spot(	 	LAB_in	: in 	LAB_actual; 
										IW			: in 	std_logic_vector(15 downto 0) 	) 
		return LAB_actual is
								
		variable i 			: integer 								:= 0;	
		variable LAB_temp : LAB_actual 							:= LAB_in;
		variable IW_temp	: std_logic_vector(15 downto 0) 	:= IW;
		
	begin
		
		for i in 0 to 4 loop
			if(LAB_temp(i).valid	= '0') then
			
				return i;
				
			end if;
		end loop; --for i
		
		return 5;
	end function;
	
	--function to write new IW into LAB
	function load_IW(	 	LAB_in	: in LAB_actual;
								LAB_spot	: in integer;
								IW			: in std_logic_vector(15 downto 0)	) 
	
		return LAB_actual is
								
		variable LAB_temp 		: LAB_actual 			:= LAB_in;
		variable LAB_spot_temp	: integer				:= LAB_spot;
		variable IW_temp			: std_logic_vector	:= IW;
		
	begin
	
		LAB_temp(LAP_spot_temp).inst 	<= IW_temp;
		LAB_temp(LAP_spot_temp).valid <= '1';
		
		return LAB_temp;
	end function;
	
	--function to invalidate tag of instruction that has been completed
	function commit_IW(	 	LAB_in	: in 	LAB_actual; 
									tag		: in 	integer 		) 
		return std_logic is
								
		variable i 			: integer 								:= 0;	
		variable LAB_temp : LAB_actual 							:= LAB_in;
		variable IW_temp	: std_logic_vector(15 downto 0) 	:= IW;
		
	begin
		
		for i in 0 to 4 loop
			if(LAB_temp(i).valid	= '0') then
				
				LAB_temp(i).inst 	<= IW_temp;
				LAB_temp(i).valid <= '1';
				
				return '1';
				
			end if;
		end loop; --for i
		
		--if we leave the loop, we haven't found a LAB spot. return 0.
		return '0';
	end function;

begin

	PM_clk_en <= reset_n and not(stall_pipeline) and not(LAB_full);
	
	process(reset_n, sys_clock)
		begin
		
		if(reset_n = '0') then
			LAB 			<= init_LAB(LAB);
			--PM_clk_en 	<= '0';
			
		elsif rising_edge(sys_clock) then
			if PM_clk_en = '1' then --we know that PM address progressed 
				if(find_LAB_spot(LAB, PM_data_in) < 5) then 
					--there is a spot in the LAB for it, go load IW into LAB
					LAB <= load_IW(LAB, i, PM_data_in);
				else
					--there is no spot in LAB, stall PM_clk_en
					LAB_full <= '1';
				
				end if; --find_LAB_spot
		
			else
				--PM data is stale and should not be buffered into LAB
				
		end if;
	end process;

end architecture arch;