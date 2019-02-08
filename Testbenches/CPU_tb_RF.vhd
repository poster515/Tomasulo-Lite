
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity CPU_tb_RF is
end CPU_tb_RF;

architecture test of CPU_tb_RF is
--import 
component CPU
  port ( 
		reset_n, sys_clock	: in std_logic;	
		digital_in				: in std_logic_vector(15 downto 0); --top level General Purpose inputs
		digital_out				: out std_logic_vector(15 downto 0); --top level General Purpose outputs
		--I2C_sda, I2C_scl		: inout std_logic; --top level chip inputs/outputs
		
		--TEST INPUTS UNTIL ALL SUB-BLOCKS ARE INSTANTIATED
		--TEST INPUTS ONLY, REMOVE AFTER LAB INSTANTIATED
		LAB_mem_addr_out					: in std_logic_vector(15 downto 0); 
		LAB_ID_IW							: in std_logic_vector(15 downto 0); 
		LAB_stall_out						: in std_logic;

		--TEST OUTPUT ONLY, REMOVE AFTER LAB INSTANTIATED (signal goes to LAB for arbitration)
		I2C_error_out						: out std_logic; 	
		
		--TEST OUTPUTS ONLY, REMOVE AFTER ALU_TOP INSTANTIATED
		RF_out_1, RF_out_2				: out std_logic_vector(15 downto 0);
		
		--TEST OUTPUT ONLY, REMOVE AFTER MEM_TOP INSTANTIATED
		ALU_top_out_1, ALU_top_out_2	: out std_logic_vector(15 downto 0);
		ALU_SR								: out std_logic_vector(3 downto 0);
		
		--TEST INPUT ONLY, REMOVE AFTER PROGRAM MEMORY INSTANTIATED
		PM_data_in							: in std_logic_vector(15 downto 0);
		
		--END TEST INPUTS/OUTPUTS

		--MEM Feedback Signals
		I2C_error, I2C_op_run			: in std_logic;	
		
		--(EX) ALU control Signals
		ALU_out1_en, ALU_out2_en		: out std_logic; --(CSAM) enables ALU_outX on A, B, or C bus
		ALU_d1_in_sel, ALU_d2_in_sel	: out std_logic_vector(1 downto 0); --(ALU_top) 1 = select from a bus, 0 = don't.
		ALU_fwd_data_out_en				: out std_logic; -- (ALU_top) ALU forwarding register out enable
		
		ALU_op								: out std_logic_vector(3 downto 0);
		ALU_inst_sel						: out std_logic_vector(1 downto 0);
		ALU_mem_addr_out					: out std_logic_vector(15 downto 0); -- memory address directly to ALU
		ALU_immediate_val					: out	std_logic_vector(15 downto 0);	 --represents various immediate values from various OpCodes
		
		--(MEM) MEM control Signals
		MEM_MEM_out_mux_sel				: out std_logic_vector(1 downto 0); --
		MEM_MEM_wr_en						: out std_logic; --write enable for data memory
		
		MEM_GPIO_in_en, MEM_GPIO_wr_en 	: out std_logic; --enables read/write for GPIO (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
		MEM_I2C_r_en, MEM_I2C_wr_en		: out std_logic; --initiates reads/writes for I2C (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
		MEM_slave_addr							: out std_logic_vector(6 downto 0);
		
		--(WB) WB control Signals and Input/Output data
		MEM_out_top				: in std_logic_vector(15 downto 0);
		GPIO_out					: in std_logic_vector(15 downto 0);
		I2C_out					: in std_logic_vector(15 downto 0)
		--WB_data_out				: out std_logic_vector(15 downto 0)	
  );
end component;



--time delta for waiting between test inputs
constant TIME_DELTA : time := 10 ns;

  --TEST INPUTS ONLY, REMOVE AFTER LAB INSTANTIATED
	signal	LAB_mem_addr_out				: std_logic_vector(15 downto 0) := "0000000000000000"; 
	signal	LAB_ID_IW							    : std_logic_vector(15 downto 0) := "0000000000000000"; 
	signal	LAB_stall_out						 : std_logic := '0';
		
  --TEST INPUTS ONLY, REMOVE AFTER LAB INSTANTIATED (signal goes to LAB for arbitration)
	signal	I2C_error_out						 : std_logic := '0';
	
	--TEST INPUTS ONLY, REMOVE AFTER ALU INSTANTIATED (signal goes to LAB for arbitration)
	signal	RF_out_1, RF_out_2		: std_logic_vector(15 downto 0) := "0000000000000000";	
		
  --END TEST INPUTS
		
	--Input data and clock
	signal	reset_n, sys_clock				: std_logic := '0';	
	signal digital_in, digital_out : std_logic_vector(15 downto 0);
	signal	PM_data_in							     : std_logic_vector(15 downto 0) := "0000000000000000";
	--PC	: out std_logic_vector(10 downto 0);
		
	--MEM Feedback Signals
	signal	I2C_error, I2C_op_run			: std_logic := '0';	
		
	--(ID) RF control Signals
	signal	ID_RF_out_1_mux					: std_logic_vector(4 downto 0) := "00000";	--controls first output mux
	signal	ID_RF_out_2_mux					: std_logic_vector(4 downto 0) := "00000";	--controls second output mux
	signal	ID_RF_out1_en, ID_RF_out2_en	: std_logic := '0'; --enables RF_out_X on B and C bus
		
	--	--(EX) ALU control Signals
	signal	ALU_out1_en, ALU_out2_en		    : std_logic := '0'; --(CSAM) enables ALU_outX on A, B, or C bus
	signal	ALU_d1_in_sel, ALU_d2_in_sel	 : std_logic_vector(1 downto 0) := "00"; --(ALU_top) 1 = select from a bus, 0 = don't.
	signal	ALU_fwd_data_out_en			: std_logic := '0'; -- (ALU_top) ALU forwarding register out enable
		
	signal	ALU_op								        : std_logic_vector(3 downto 0) := "0000";
	signal	ALU_inst_sel						    : std_logic_vector(1 downto 0) := "00";
	signal	ALU_mem_addr_out					 : std_logic_vector(15 downto 0) := "0000000000000000"; -- memory address directly to ALU
	signal	ALU_immediate_val					: std_logic_vector(15 downto 0) := "0000000000000000";	 --represents various immediate values from various OpCodes
--		
	--(MEM) MEM control Signals
	signal	MEM_MEM_wr_en						 : std_logic := '0'; --write enable for data memory
	signal MEM_MEM_out_mux_sel			: std_logic_vector(1 downto 0) := "00"; -- (MEM_top) MEM forwarding register out enable	

	signal	MEM_GPIO_in_en, MEM_GPIO_wr_en : std_logic := '0'; --enables read/write for GPIO (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
	signal	MEM_I2C_r_en, MEM_I2C_wr_en	  : std_logic := '0'; --initiates reads/writes for I2C (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
	signal	MEM_ION_out_en						: std_logic := '0'; --enables input_buffer onto either A or B bus for GPIO reads, goes to CSAM for arbitration
	signal	MEM_ION_in_sel						: std_logic := '0'; --enables A or B bus onto output_buffer for digital writes, goes to CSAM for arbitration
	signal	MEM_slave_addr						: std_logic_vector(6 downto 0) := "0000000";
		
	
	signal MEM_out_top, GPIO_out, I2C_out     : std_logic_vector(15 downto 0);
	signal ALU_top_out_1, ALU_top_out_2     : std_logic_vector(15 downto 0);
  signal ALU_SR       : std_logic_vector(3 downto 0);
  begin
    
    CPU_top : entity work.CPU
      port map(
        --Input data and clock
		    reset_n       => reset_n, 
		    sys_clock	    => sys_clock,
		    digital_in    => digital_in,
		    digital_out   => digital_out,
		    --I2C_sda       => I2C_sda,
		    --I2C_scl       => I2C_scl,
        
        --TEST INPUTS ONLY, REMOVE AFTER LAB INSTANTIATED
		    LAB_mem_addr_out		=> LAB_mem_addr_out,
		    LAB_ID_IW		       => LAB_ID_IW,	 
		    LAB_stall_out		   => LAB_stall_out,
		    
		    --TEST OUTPUT ONLY, REMOVE AFTER LAB INSTANTIATED (signal goes to LAB for arbitration)
		    I2C_error_out   => I2C_error_out,
		    
		    --TEST OUTPUTS ONLY, REMOVE AFTER ALU_TOP INSTANTIATED
		    RF_out_1        => RF_out_1,
		    RF_out_2				    => RF_out_2,
		    
		    --TEST OUTPUT ONLY, REMOVE AFTER MEM_TOP INSTANTIATED
		    ALU_top_out_1   => ALU_top_out_1, 
		    ALU_top_out_2   => ALU_top_out_2,
		    ALU_SR								  => ALU_SR,
		    		    
		    --TEST INPUT ONLY, REMOVE AFTER PROGRAM MEMORY INSTANTIATED
		    PM_data_in				=> PM_data_in,
		    
		    --END TEST INPUTS
		    
		    --MEM Feedback Signals
		    I2C_error        => I2C_error, 
		    I2C_op_run			    => I2C_op_run,	
		    
		    ----(EX) ALU control Signals
      		ALU_out1_en		     =>	ALU_out1_en,		
      		ALU_out2_en		     => ALU_out2_en,
     		 ALU_d2_in_sel		   => ALU_d2_in_sel,
      		ALU_d1_in_sel		   => ALU_d1_in_sel,
		    ALU_fwd_data_out_en  => ALU_fwd_data_out_en,
		    
				ALU_op				        => ALU_op,
      		ALU_inst_sel			   => ALU_inst_sel,
      		ALU_mem_addr_out		=> ALU_mem_addr_out,
		    ALU_immediate_val	=> ALU_immediate_val,
		
		    --(MEM) MEM control Signals
		    MEM_MEM_out_mux_sel				=> MEM_MEM_out_mux_sel,
		    MEM_MEM_wr_en					=> MEM_MEM_wr_en,
		    
		    MEM_GPIO_in_en     => MEM_GPIO_in_en,
		    MEM_GPIO_wr_en    => MEM_GPIO_wr_en,
		    MEM_I2C_r_en      => MEM_I2C_r_en,
		    MEM_I2C_wr_en	    => MEM_I2C_wr_en,
		    MEM_slave_addr				=> MEM_slave_addr,
		
		    --(WB) WB control Signals and Input/Output data
		    MEM_out_top			    => MEM_out_top,
		    GPIO_out					     => GPIO_out,
		    I2C_out					      => I2C_out
		    --WB_data_out				   => WB_data_out		
      );
      
      
    sys_clock <=  '1' after TIME_DELTA / 2 when sys_clock = '0' else
                  '0' after TIME_DELTA / 2 when sys_clock = '1'; 
        
    simulation : process
    begin
      --initialize all registers, and wait a few clocks
      reset_n <= '0';
      MEM_out_top <= "0000000000000000";
      wait for TIME_DELTA * 2;
      
      reset_n <= '1';
      
      -- first try some non-memory/ION operation
      PM_data_in <= "1100000100001001"; --LOG(OR) R2, #2 
      wait for TIME_DELTA;
      
      LAB_ID_IW <= "1100000100001001"; --LOG(OR) R2, #2 
      PM_data_in <= "1100000110000011"; --LOG(NOT) R3
      wait for TIME_DELTA;
      
      LAB_ID_IW <= "1100000110000011"; --LOG(NOT) R3
      PM_data_in <= "0000000000000000"; --(just reset)
      wait for TIME_DELTA * 2.5;
      
      MEM_out_top  <= "0000000000000010";
      wait for TIME_DELTA;
      
      MEM_out_top <= "1111111111111111";
      wait for TIME_DELTA * 3;
      
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








