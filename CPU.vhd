--Written by: Joe Post

--This block is the top level of the CPU.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity CPU is
   port ( 
		reset_n, sys_clock	: in std_logic;	
		digital_in				: in std_logic_vector(15 downto 0); --top level General Purpose inputs
		digital_out				: out std_logic_vector(15 downto 0); --top level General Purpose outputs, driven by ION
		--I2C_sda, I2C_scl		: inout std_logic; --top level chip inputs/outputs
		
		--TEST INPUTS UNTIL ALL SUB-BLOCKS ARE INSTANTIATED
		--TEST INPUTS ONLY, REMOVE AFTER LAB INSTANTIATED
		LAB_mem_addr_out					: in std_logic_vector(15 downto 0); 
		LAB_ID_IW							: in std_logic_vector(15 downto 0); 
		LAB_stall_out						: in std_logic;

		--TEST OUTPUT ONLY, REMOVE AFTER LAB INSTANTIATED (signal goes to LAB for arbitration)
		I2C_error_out						: out std_logic; 	
		
		--TEST OUTPUTS ONLY, REMOVE AFTER ALU_TOP INSTANTIATED
		RF_out_1, RF_out_2				: inout std_logic_vector(15 downto 0);

		--TEST OUTPUT ONLY, REMOVE AFTER MEM_TOP INSTANTIATED
		ALU_top_out_1, ALU_top_out_2	: out std_logic_vector(15 downto 0);
		ALU_SR								: out std_logic_vector(3 downto 0);
				
		--TEST INPUT ONLY, REMOVE AFTER PROGRAM MEMORY INSTANTIATED
		PM_data_in							: in std_logic_vector(15 downto 0);
		
		--END TEST INPUTS/OUTPUTS

		--MEM Feedback Signals
		I2C_error, I2C_op_run			: in std_logic;	
		
		--(EX) ALU control Signals
		ALU_out1_en, ALU_out2_en		: inout std_logic; --enables ALU_outX on A, B, or C bus
		ALU_d1_in_sel, ALU_d2_in_sel	: inout std_logic_vector(1 downto 0); --(ALU_top) 1 = select from a bus, 0 = don't.
		ALU_fwd_data_out_en				: inout std_logic; -- (ALU_top) ALU forwarding register out enable
		
		ALU_op								: inout std_logic_vector(3 downto 0);
		ALU_inst_sel						: inout std_logic_vector(1 downto 0);
		ALU_mem_addr_out					: inout std_logic_vector(15 downto 0); -- memory address directly to ALU
		ALU_immediate_val					: inout	std_logic_vector(15 downto 0);	 --represents various immediate values from various OpCodes
--		
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
	);
end CPU;

architecture structural of CPU is

	component control_unit is
	port(
		--TEST INPUTS ONLY, REMOVE AFTER LAB INSTANTIATED
		LAB_mem_addr_out					: in std_logic_vector(15 downto 0); 
		LAB_ID_IW							: in std_logic_vector(15 downto 0); 
		LAB_stall_out						: in std_logic;

		--TEST OUTPUT ONLY, REMOVE AFTER LAB INSTANTIATED (signal goes to LAB for arbitration)
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
		WB_RF_in_demux						: out std_logic_vector(4 downto 0); -- selects which 
		WB_wr_en								: out std_logic;	
		
		MEM_out_top				: in std_logic_vector(15 downto 0);
		GPIO_out					: in std_logic_vector(15 downto 0);
		I2C_out					: in std_logic_vector(15 downto 0);
		WB_data_out				: out std_logic_vector(15 downto 0)
	);
	end component;
	
	component RF_top is
	port (
		--Input data and clock
		clk 				: in std_logic;
		WB_data_in		: in std_logic_vector(15 downto 0);

		--Control signals
		reset_n			: in std_logic; --all registers reset to 0 when this goes low
		wr_en 			: in std_logic; --(WB) enables write for the selected register
		RF_out_1_mux, RF_out_2_mux		: in std_logic_vector(4 downto 0);	--controls first output mux
		RF_out_1_en, RF_out_2_en		: in std_logic;
		RF_in_demux		: in std_logic_vector(4 downto 0);	--(WB) controls which register to write data to

		--Outputs
		RF_out_1, RF_out_2	: out std_logic_vector(15 downto 0)
	);
	end component;
	
	component ALU_top is
	port (
	--Input data and clock
		sys_clock, reset_n	: in std_logic;
		RF_in_1, RF_in_2		: in std_logic_vector(15 downto 0);
		MEM_in, WB_in			: in std_logic_vector(15 downto 0); --
		MEM_address				: in std_logic_vector(15 downto 0); --memory address forwarded directly from LAB
		value_immediate		: in std_logic_vector(15 downto 0); --Reg2 data field from IW directly from EX
																				--used to forward shift/rotate distance and immediate value for addi & subi

		--Control signals
		ALU_op					: in std_logic_vector(3 downto 0); 	--dictates ALU operation (i.e., OpCode)
		ALU_inst_sel			: in std_logic_vector(1 downto 0); 	--dictates what sub-function to execute (last two bits of OpCode)
		ALU_d2_in_sel			: in std_logic_vector(1 downto 0); 	--(EX) control which input to send to ALU input 2
		ALU_d1_in_sel 			: in std_logic_vector(1 downto 0); 	--(EX) control which input to send to ALU input 1
		
		ALU_out1_en, ALU_out2_en	: in std_logic; --enables latching ALU results into ALU_outX_reg
		ALU_fwd_data_out_en			: in std_logic; --(EX) selects fwd reg to output data onto A, B, or C bus (EX)
		
		--Outputs
		ALU_SR 					: out std_logic_vector(3 downto 0); --provides | Zero (Z) | Overflow (V) | Negative (N) | Carry (C) |
		ALU_top_out_1			: out std_logic_vector(15 downto 0); --
		ALU_top_out_2			: out std_logic_vector(15 downto 0) --
	);
	end component;
	
	signal ID_RF_out_1_mux					: std_logic_vector(4 downto 0);	--controls first output mux
	signal ID_RF_out_2_mux					: std_logic_vector(4 downto 0);	--controls second output mux
	signal ID_RF_out1_en, ID_RF_out2_en	: std_logic; -- 
	signal WB_data								: std_logic_vector(15 downto 0);
	signal WB_wr_en							: std_logic;
	signal WB_RF_in_demux					: std_logic_vector(4 downto 0);
--	signal ALU_out1_en, ALU_out2_en		: std_logic;
--	signal ALU_op								: std_logic_vector(3 downto 0); 	--dictates ALU operation (i.e., OpCode)
--	signal ALU_inst_sel						: std_logic_vector(1 downto 0); 	--dictates what sub-function to execute (last two bits of OpCode)
--	signal ALU_d1_in_sel, ALU_d2_in_sel	: std_logic_vector(1 downto 0); 	--(EX) control which input to send to ALU input 2
--	signal ALU_fwd_data_out_en				: std_logic;	 
--	signal ALU_mem_addr_out, ALU_immediate_val	: std_logic_vector(15 downto 0);
--	signal RF_out_1, RF_out_2				: std_logic_vector(15 downto 0);
begin

	control_unit_top	: control_unit
	port map (
		--TEST INPUTS ONLY, REMOVE AFTER LAB INSTANTIATED
		LAB_mem_addr_out					=> LAB_mem_addr_out,
		LAB_ID_IW							=> LAB_ID_IW,
		LAB_stall_out						=> LAB_stall_out,

		--TEST OUTPUT ONLY, REMOVE AFTER LAB INSTANTIATED (signal goes to LAB for arbitration)
		I2C_error_out						=> I2C_error_out,
		
		--END TEST INPUTS
		
		--Input data and clock
		reset_n								=> reset_n, 
		sys_clock							=> sys_clock,
		PM_data_in							=> PM_data_in,
		--PC	: out std_logic_vector(10 downto 0);
		
		--MEM Feedback Signals
		I2C_error							=> I2C_error, 
		I2C_op_run							=> I2C_op_run,
		
		--(ID) RF control Signals
		ID_RF_out_1_mux					=> ID_RF_out_1_mux,		--MAPPED
		ID_RF_out_2_mux					=> ID_RF_out_2_mux,		--MAPPED
		ID_RF_out1_en						=> ID_RF_out1_en, 		--MAPPED
		ID_RF_out2_en						=> ID_RF_out2_en,			--MAPPED
		
		--(EX) ALU control Signals
		ALU_out1_en							=> ALU_out1_en, 			--MAPPED
		ALU_out2_en							=> ALU_out2_en,			--MAPPED
		ALU_d1_in_sel						=> ALU_d1_in_sel, 		--MAPPED
		ALU_d2_in_sel						=> ALU_d2_in_sel,			--MAPPED
		ALU_fwd_data_out_en				=> ALU_fwd_data_out_en,	--MAPPED
		
		ALU_op								=> ALU_op,					--MAPPED
		ALU_inst_sel						=> ALU_inst_sel,			--MAPPED
		ALU_mem_addr_out					=> ALU_mem_addr_out,		--MAPPED
		ALU_immediate_val					=> ALU_immediate_val,	--MAPPED
		
		--(MEM) MEM control Signals
		MEM_MEM_out_mux_sel				=> MEM_MEM_out_mux_sel,
		MEM_MEM_wr_en						=> MEM_MEM_wr_en,
		
		MEM_GPIO_in_en						=> MEM_GPIO_in_en, 
		MEM_GPIO_wr_en 					=> MEM_GPIO_wr_en,
		MEM_I2C_r_en						=> MEM_I2C_r_en, 
		MEM_I2C_wr_en						=> MEM_I2C_wr_en,
		MEM_slave_addr						=> MEM_slave_addr,
		
		--(WB) WB control Signals and Input/Output data
		WB_RF_in_demux						=> WB_RF_in_demux,	--MAPPED
		WB_wr_en								=> WB_wr_en,			--MAPPED
		
		MEM_out_top				=> MEM_out_top,
		GPIO_out					=> GPIO_out,
		I2C_out					=> I2C_out,
		WB_data_out				=> WB_data							--MAPPED
	);
	
	RF	: RF_top
	port map(
		--Input data and clock
		clk 					=> sys_clock,		
		WB_data_in			=> WB_data,

		--Control signals
		reset_n				=> reset_n,
		wr_en 				=> WB_wr_en,
		RF_out_1_mux		=> ID_RF_out_1_mux, 
		RF_out_2_mux		=> ID_RF_out_2_mux,
		RF_out_1_en			=> ID_RF_out1_en,
		RF_out_2_en			=> ID_RF_out2_en,
		RF_in_demux			=> WB_RF_in_demux,

		--Outputs
		RF_out_1				=> RF_out_1,
		RF_out_2				=> RF_out_2
	);
	
	ALU : ALU_top
	port map (
	--Input data and clock
		sys_clock		=> sys_clock,
		reset_n			=> reset_n,
		RF_in_1			=> RF_out_1,
		RF_in_2			=> RF_out_2,
		MEM_in			=> MEM_out_top,
		WB_in				=> WB_data,
		MEM_address		=> ALU_mem_addr_out,
		value_immediate	=> ALU_immediate_val,
		
		--Control signals
		ALU_op			=> ALU_op,
		ALU_inst_sel	=> ALU_inst_sel,
		ALU_d2_in_sel	=> ALU_d2_in_sel,
		ALU_d1_in_sel 	=> ALU_d1_in_sel,
		
		ALU_out1_en		=> ALU_out1_en, 
		ALU_out2_en		=> ALU_out2_en,
		ALU_fwd_data_out_en		=> ALU_fwd_data_out_en,
		
		--Outputs
		ALU_SR 			=> ALU_SR,
		ALU_top_out_1	=> ALU_top_out_1,
		ALU_top_out_2	=> ALU_top_out_2
	);
	
	process(reset_n, sys_clock)
	begin
		if reset_n = '0' then
			
		elsif rising_edge(sys_clock) then

		end if; --reset_n
	end process;
	
end structural;