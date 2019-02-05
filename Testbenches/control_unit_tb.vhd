
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control_unit_tb is
end control_unit_tb;

architecture test of control_unit_tb is
--import 
component control_unit
  port ( 
		
		--TEST INPUTS ONLY, REMOVE AFTER LAB INSTANTIATED
		LAB_mem_addr_out					: in std_logic_vector(15 downto 0); 
		LAB_ID_IW							: in std_logic_vector(15 downto 0); 
		LAB_stall_out						: in std_logic;
		
		--TEST INPUTS ONLY, REMOVE AFTER CSAM INSTANTIATED
		WB_A_bus_in_sel					: in std_logic; 	-- from CSAM, selects data from memory stage to buffer in ROB
		WB_C_bus_in_sel					: in std_logic; 	-- from CSAM, selects data from memory stage to buffer in ROB
		WB_B_bus_out_en					: in std_logic;	-- from CSAM, if '1', we can write result on B_bus
		WB_C_bus_out_en					: in std_logic; 	-- from CSAM, if '1', we can write result on C_bus
		
		--TEST INPUTS ONLY, REMOVE AFTER LAB INSTANTIATED (signal goes to LAB for arbitration)
		I2C_error_out						: out std_logic; 	
		
		--END TEST INPUTS
		
		--Input data and clock
		reset_n, sys_clock				: in std_logic;	
		PM_data_in							: in std_logic_vector(15 downto 0);
		--PC	: out std_logic_vector(10 downto 0);
		
		--MEM Feedback Signals
		I2C_error, I2C_op_run			: in std_logic;	
		
		--(ID) RF control Signals
		ID_RF_out_1_mux					: out std_logic_vector(4 downto 0);	--controls first output mux
		ID_RF_out_2_mux					: out std_logic_vector(4 downto 0);	--controls second output mux
		ID_RF_out1_en, ID_RF_out2_en	: out std_logic; --enables RF_out_X on B and C bus
		
		--(EX) ALU control Signals
		--ALU_out1_en, ALU_out2_en		: out std_logic; --(CSAM) enables ALU_outX on A, B, or C bus
		ALU_d1_in_sel, ALU_d2_in_sel	: out std_logic_vector(1 downto 0); --(ALU_top) 1 = select from a bus, 0 = don't.
		ALU_fwd_data_in_en				: out std_logic; --(ALU_top) latches data from RF_out1/2 for forwarding
		ALU_fwd_data_out_en				: out std_logic; -- (ALU_top) ALU forwarding register out enable
		
		ALU_op								: out std_logic_vector(3 downto 0);
		ALU_inst_sel						: out std_logic_vector(1 downto 0);
		ALU_mem_addr_out					: out std_logic_vector(15 downto 0); -- memory address directly to ALU
		ALU_immediate_val					: out	std_logic_vector(15 downto 0);	 --represents various immediate values from various OpCodes
		
		--(MEM) MEM control Signals
		MEM_MEM_in_sel						: out std_logic; --selects bus for MEM_top to select data from 
		MEM_MEM_out_en						: out std_logic; --enables MEM output on busses, goes to CSAM for arbitration
		MEM_MEM_wr_en						: out std_logic; --write enable for data memory
		MEM_MEM_op							: out std_logic;
		
		MEM_GPIO_r_en, MEM_GPIO_wr_en : out std_logic; --enables read/write for GPIO (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
		MEM_I2C_r_en, MEM_I2C_wr_en	: out std_logic; --initiates reads/writes for I2C (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
		MEM_ION_out_en						: out std_logic; --enables input_buffer onto either A or B bus for GPIO reads, goes to CSAM for arbitration
		MEM_ION_in_sel						: out std_logic; --enables A or B bus onto output_buffer for digital writes, goes to CSAM for arbitration
		MEM_slave_addr						: out std_logic_vector(6 downto 0);
		
		--(WB) WB control Signals
		WB_RF_in_demux						: out std_logic_vector(4 downto 0); -- selects which 
		WB_RF_in_en, WB_wr_en			: out std_logic;	-- RF_in_en sent to CSAM for arbitration. wr_en also sent to CSAM, although it's passed through. 
		
		--Inouts
		A_bus, B_bus, C_bus	: inout std_logic_vector(15 downto 0) --A/C bus because we need access to memory stage outputs, B/C bus because RF has access to them
	);
end component;



--time delta for waiting between test inputs
constant TIME_DELTA : time := 10 ns;

  --TEST INPUTS ONLY, REMOVE AFTER LAB INSTANTIATED
	signal	LAB_mem_addr_out				: std_logic_vector(15 downto 0) := "0000000000000000"; 
	signal	LAB_ID_IW							    : std_logic_vector(15 downto 0) := "0000000000000000"; 
	signal	LAB_stall_out						 : std_logic := '0';
		
		--TEST INPUTS ONLY, REMOVE AFTER CSAM INSTANTIATED
	signal	WB_A_bus_in_sel					: std_logic := '0'; 	-- from CSAM, selects data from memory stage to buffer in ROB
	signal	WB_C_bus_in_sel					: std_logic := '0'; 	-- from CSAM, selects data from memory stage to buffer in ROB
	signal	WB_B_bus_out_en					: std_logic := '0';	-- from CSAM, if '1', we can write result on B_bus
	signal	WB_C_bus_out_en					: std_logic := '0'; 	-- from CSAM, if '1', we can write result on C_bus
		
		--TEST INPUTS ONLY, REMOVE AFTER LAB INSTANTIATED (signal goes to LAB for arbitration)
	signal	I2C_error_out						 : std_logic := '0'; 	
		
		--END TEST INPUTS
		
		--Input data and clock
	signal	reset_n, sys_clock				: std_logic := '0';	
	signal	PM_data_in							     : std_logic_vector(15 downto 0) := "0000000000000000";
		--PC	: out std_logic_vector(10 downto 0);
		
		--MEM Feedback Signals
	signal	I2C_error, I2C_op_run			: std_logic := '0';	
		
		--(ID) RF control Signals
	signal	ID_RF_out_1_mux					: std_logic_vector(4 downto 0) := "00000";	--controls first output mux
	signal	ID_RF_out_2_mux					: std_logic_vector(4 downto 0) := "00000";	--controls second output mux
	signal	ID_RF_out1_en, ID_RF_out2_en	: std_logic := '0'; --enables RF_out_X on B and C bus
		
		--(EX) ALU control Signals
	--signal	ALU_out1_en, ALU_out2_en		    : std_logic := '0'; --(CSAM) enables ALU_outX on A, B, or C bus
	signal	ALU_d1_in_sel, ALU_d2_in_sel	 : std_logic_vector(1 downto 0) := "00"; --(ALU_top) 1 = select from a bus, 0 = don't.
	signal	ALU_fwd_data_in_en				: std_logic := '0'; --(ALU_top) latches data from RF_out1/2 for forwarding
	signal	ALU_fwd_data_out_en			: std_logic := '0'; -- (ALU_top) ALU forwarding register out enable
		
	signal	ALU_op								        : std_logic_vector(3 downto 0) := "0000";
	signal	ALU_inst_sel						    : std_logic_vector(1 downto 0) := "00";
	signal	ALU_mem_addr_out					 : std_logic_vector(15 downto 0) := "0000000000000000"; -- memory address directly to ALU
	signal	ALU_immediate_val					: std_logic_vector(15 downto 0) := "0000000000000000";	 --represents various immediate values from various OpCodes
		
		--(MEM) MEM control Signals
	signal	MEM_MEM_in_sel						: std_logic := '0'; --selects bus for MEM_top to select data from 
	signal	MEM_MEM_out_en						: std_logic := '0'; --enables MEM output on busses, goes to CSAM for arbitration
	signal	MEM_MEM_wr_en						 : std_logic := '0'; --write enable for data memory
	signal	MEM_MEM_op							   : std_logic := '0';
		
	signal	MEM_GPIO_r_en, MEM_GPIO_wr_en : std_logic := '0'; --enables read/write for GPIO (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
	signal	MEM_I2C_r_en, MEM_I2C_wr_en	  : std_logic := '0'; --initiates reads/writes for I2C (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
	signal	MEM_ION_out_en						: std_logic := '0'; --enables input_buffer onto either A or B bus for GPIO reads, goes to CSAM for arbitration
	signal	MEM_ION_in_sel						: std_logic := '0'; --enables A or B bus onto output_buffer for digital writes, goes to CSAM for arbitration
	signal	MEM_slave_addr						: std_logic_vector(6 downto 0) := "0000000";
		
		--(WB) WB control Signals
	signal	WB_RF_in_demux						      : std_logic_vector(4 downto 0) := "00000"; -- selects which 
	signal WB_RF_in_en, WB_wr_en			  : std_logic := '0';	-- RF_in_en sent to CSAM for arbitration. wr_en also sent to CSAM, although it's passed through. 
  signal A_bus, B_bus, C_bus       : std_logic_vector(15 downto 0) := "ZZZZZZZZZZZZZZZZ"; 
  
  begin
    
    CU_top : entity work.control_unit
      port map(
        
        --TEST INPUTS ONLY, REMOVE AFTER LAB INSTANTIATED
		    LAB_mem_addr_out		=> LAB_mem_addr_out,
		    LAB_ID_IW		       => LAB_ID_IW,	 
		    LAB_stall_out		   => LAB_stall_out,
		    
		    --TEST INPUTS ONLY, REMOVE AFTER CSAM INSTANTIATED
		    WB_A_bus_in_sel		=> WB_A_bus_in_sel,
		    WB_C_bus_in_sel		=> WB_C_bus_in_sel,
		    WB_B_bus_out_en		=> WB_B_bus_out_en,
		    WB_C_bus_out_en		=> WB_C_bus_out_en,
		    
		    --TEST OUTPUT ONLY, REMOVE AFTER LAB INSTANTIATED (signal goes to LAB for arbitration)
		    I2C_error_out				=> I2C_error_out,	
		    
		    --END TEST INPUTS
		    
        --Input data and clock
		    reset_n       => reset_n, 
		    sys_clock	    => sys_clock,
		    PM_data_in				=> PM_data_in,
		    
		    --MEM Feedback Signals
		    I2C_error        => I2C_error, 
		    I2C_op_run			    => I2C_op_run,	
		    
		    --(ID) RF control Signals
		    ID_RF_out_1_mux		 => ID_RF_out_1_mux, 	
		    ID_RF_out_2_mux		 => ID_RF_out_2_mux,			
		    ID_RF_out1_en     => ID_RF_out1_en,
		    ID_RF_out2_en	    => ID_RF_out2_en,
		    
		    --(EX) ALU control Signals
      		--ALU_out1_en		     =>	ALU_out1_en,		
      		--ALU_out2_en		     => ALU_out2_en,
     		 ALU_d2_in_sel		   => ALU_d2_in_sel,
      		ALU_d1_in_sel		   => ALU_d1_in_sel,
		    ALU_fwd_data_in_en   => ALU_fwd_data_in_en,
				ALU_fwd_data_out_en  => ALU_fwd_data_out_en,
				ALU_op				        => ALU_op,
      		ALU_inst_sel			   => ALU_inst_sel,
      		ALU_mem_addr_out		=> ALU_mem_addr_out,
		    ALU_immediate_val	=> ALU_immediate_val,
		
		    --(MEM) MEM control Signals
		    MEM_MEM_in_sel				=> MEM_MEM_in_sel,
		    MEM_MEM_out_en				=> MEM_MEM_out_en,
		    MEM_MEM_wr_en					=> MEM_MEM_wr_en,
		    MEM_MEM_op						  => MEM_MEM_op,
		    MEM_GPIO_r_en     => MEM_GPIO_r_en,
		    MEM_GPIO_wr_en    => MEM_GPIO_wr_en,
		    MEM_I2C_r_en      => MEM_I2C_r_en,
		    MEM_I2C_wr_en	    => MEM_I2C_wr_en,
		    MEM_ION_out_en				=> MEM_ION_out_en,
		    MEM_ION_in_sel				=> MEM_ION_in_sel,
		    MEM_slave_addr				=> MEM_slave_addr,
		
		    --(WB) WB control Signals
		    WB_RF_in_demux				=> WB_RF_in_demux,
		    WB_RF_in_en						 => WB_RF_in_en, 
		    WB_wr_en							   => WB_wr_en,
		
		    --Inouts
		    A_bus							=> A_bus, 
		    B_bus							=> B_bus, 		
		    C_bus							=> C_bus
      );
      
      
    sys_clock <=  '1' after TIME_DELTA / 2 when sys_clock = '0' else
                  '0' after TIME_DELTA / 2 when sys_clock = '1'; 
        
    simulation : process
    begin
      --initialize all registers, and wait a few clocks
      reset_n <= '0';
      wait for TIME_DELTA * 2;
      
      reset_n <= '1';
      
      -- first try some non-memory/ION operation
      PM_data_in <= "0000000100001000"; --ADD R2, R2
      wait for TIME_DELTA * 4;
      
      ---- try some non-memory/ION operation
--      PM_data_in <= "0001000100001000"; --SUB R2, R2
--      wait for TIME_DELTA;
--      
--      -- try some non-memory/ION operation
--      PM_data_in <= "1100000100001000"; --ANDI R2, #2
--      wait for TIME_DELTA;
--      
--      -- now try some a memory operation
--      PM_data_in <= "1000000100001000"; --LD R2, 0x08(R2)
--      wait for TIME_DELTA;
--      
--      -- now try some an GPIO write operation
--      PM_data_in <= "1011000100000001"; --WR R2
--      wait for TIME_DELTA;
--      
--      -- now try some an GPIO read operation
--      PM_data_in <= "1011001010000000"; --RD R5
--      wait for TIME_DELTA;
--      
--      -- now try some an I2C read operation
--      PM_data_in <= "1011001010000010"; --RD 0x00000, R5
--      wait for TIME_DELTA;
--      
--      -- now try some another immediate I2C write operation
--      PM_data_in <= "1011001110000011"; --WR 0x00000, R7
--      wait for TIME_DELTA;
--     
--      PM_data_in <= "1000000100001000"; --LD R2, 0x08(R2)
--      wait for 1000 ns;
      
    end process simulation;

end architecture test;






