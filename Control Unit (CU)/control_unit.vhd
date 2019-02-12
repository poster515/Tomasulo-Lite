--Written by: Joe Post

--This file contains all control unit sub-blocks, and provides all control signals to the other CPU sub-blocks. 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.arrays.ALL;

entity control_unit is
   port ( 
	
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
		WB_wr_en								: out std_logic;	-- RF_in_en sent to CSAM for arbitration. wr_en also sent to CSAM, although it's passed through. 
		
		MEM_out_top				: in std_logic_vector(15 downto 0);
		GPIO_out					: in std_logic_vector(15 downto 0);
		I2C_out					: in std_logic_vector(15 downto 0);
		WB_data_out				: inout std_logic_vector(15 downto 0)
	);
end control_unit;

architecture behavioral of control_unit is

	signal ID_stall_out			: std_logic;
	
	--ID <-> EX Signals
	signal ID_EX_IW				: std_logic_vector(15 downto 0); --goes to EX control unit
	signal EX_stall_out			: std_logic;
	signal ID_EX_mem_address	: std_logic_vector(15 downto 0);
	signal ID_EX_immediate_val	: std_logic_vector(15 downto 0); --represents various immediate values from various OpCodes
	signal ID_reset_out			: std_logic;
 
	--EX <-> MEM Signals
	signal EX_MEM_IW				: std_logic_vector(15 downto 0); -- forwarding to MEM control unit
	signal MEM_stall_out			: std_logic;
	signal EX_reset_out			: std_logic;
	
	--MEM <-> WB Signals
	signal MEM_WB_IW				: std_logic_vector(15 downto 0);
	signal WB_stall_out			: std_logic;
	signal MEM_reset_out			: std_logic;
	
	

--	component LAB is
--		generic ( 	LAB_MAX	: integer	:= 5;	
--						LAB2_MAX : integer 	:= 5 	);
--		port (
--
--			sys_clock, reset_n  	: in std_logic;
--			stall_pipeline			: in std_logic; --needed when waiting for certain commands, should be formulated in top level CU module
--			ID_tag			: in std_logic_vector(4 downto 0); --source registers for instruction in ID stage
--			EX_tag			: in std_logic_vector(4 downto 0); --source registers for instruction in EX stage (results available)
--			MEM_tag			: in std_logic_vector(4 downto 0); --source registers for instruction in MEM stage (results available)
--			WB_tag			: in std_logic_vector(4 downto 0); --source registers for instruction in WB stage (results available)
--			
--			tag_to_commit	: in integer;	--input from WB stage, which denotes the tag of the instruction that has been written back, only valid for single clock
--			
--			PM_data_in		: in 	std_logic_vector(15 downto 0);
--			PC					: out std_logic_vector(10 downto 0);
--			IW					: out std_logic_vector(15 downto 0);
--			MEM				: out std_logic_vector(15 downto 0)	--MEM is the IW representing the next IW as part of LD, ST, JMP, BNE(Z) operations
--		);
--	end component;

	component ID is
		port ( 
			--Input data and clock
		reset_n, sys_clock			: in std_logic;	
		IW_in								: in std_logic_vector(15 downto 0);
		LAB_stall_in					: in std_logic;
		WB_stall_in						: in std_logic;		--set high when an upstream CU block needs this 
		MEM_stall_in					: in std_logic;
		EX_stall_in						: in std_logic;
		mem_addr_in						: in std_logic_vector(15 downto 0);
		
		--Control
		RF_out_1_mux					: out std_logic_vector(4 downto 0);	--controls first output mux
		RF_out_2_mux					: out std_logic_vector(4 downto 0);	--controls second output mux
		RF_out1_en, RF_out2_en		: out std_logic; --enables RF_out_X on B and C bus
		
		--Outputs
		IW_out							: out std_logic_vector(15 downto 0); --goes to EX control unit
		stall_out						: out std_logic;
		immediate_val					: out	std_logic_vector(15 downto 0); --represents various immediate values from various OpCodes
		mem_addr_out					: out std_logic_vector(15 downto 0);
		reset_out						: out std_logic		--
		);
	end component;
	
	component EX is
		port ( 
			--Input data and clock
			reset_n, sys_clock		: in std_logic;	
			IW_in							: in std_logic_vector(15 downto 0);
			LAB_stall_in				: in std_logic;
			WB_stall_in					: in std_logic;		--set high when an upstream CU block needs this 
			MEM_stall_in				: in std_logic;
			mem_addr_in					: in std_logic_vector(15 downto 0); --memory address from ID stage
			immediate_val_in			: in std_logic_vector(15 downto 0); --immediate value from ID stage
			
			--Control
			ALU_out1_en, ALU_out2_en		: out std_logic; --(EX) enables ALU_outX on A, B, or C bus
			ALU_d1_in_sel, ALU_d2_in_sel	: out std_logic_vector(1 downto 0); --(ALU_top) 1 = select from a bus, 0 = don't.
			ALU_fwd_data_out_en				: out std_logic; -- (ALU_top) ALU forwarding register out enable
			
			--Outputs
			ALU_op						: out std_logic_vector(3 downto 0);
			ALU_inst_sel				: out std_logic_vector(1 downto 0);
			EX_stall_out				: out std_logic;
			IW_out						: out std_logic_vector(15 downto 0); -- forwarding to MEM control unit
			mem_addr_out				: out std_logic_vector(15 downto 0); -- memory address directly to ALU
			immediate_val				: out	std_logic_vector(15 downto 0);	 --represents various immediate values from various OpCodes
			reset_out					: out std_logic
		);
	end component;
	
	component MEM is
		port ( 
			--Input data and clock
			reset_n, sys_clock		: in std_logic;	
			IW_in							: in std_logic_vector(15 downto 0);
			LAB_stall_in				: in std_logic;
			WB_stall_in					: in std_logic;		--set high when an upstream CU block needs this 
			I2C_error					: in std_logic;	--in case we can't write to slave after three attempts
			I2C_op_run					: in std_logic;	--when high, lets CU know that there is a CU operation occurring
			
			--MEM Control Outputs
			MEM_wr_en					: out std_logic; --write enable for data memory
			MEM_out_mux_sel		: out std_logic_vector(1 downto 0); --enables MEM output 
			
			--ION Control Outputs
			GPIO_in_en, GPIO_wr_en 	: out std_logic; --enables read/write for GPIO (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
			I2C_r_en, I2C_wr_en		: out std_logic; --initiates reads/writes for I2C (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
			slave_addr					: out std_logic_vector(6 downto 0);
			
			--Outputs
			I2C_error_out				: out std_logic;	--in case we can't write to slave after three attempts, send to LAB for arbitration
			IW_out						: out std_logic_vector(15 downto 0);
			stall_out					: out std_logic;
			reset_out					: out std_logic
		);
	end component;
	
	component WB is
		generic ( ROB_DEPTH : integer := 10 );
		port ( 
			--Input data and clock
			reset_n, reset_MEM	: in std_logic;
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
	end component;
	
begin

	ID_actual	: ID
	port map ( 
		--Input data and clock
		reset_n			=> reset_n, 
		sys_clock		=> sys_clock,	
		IW_in				=> LAB_ID_IW,
		LAB_stall_in	=> LAB_stall_out,
		WB_stall_in		=> WB_stall_out,			
		MEM_stall_in	=> MEM_stall_out,			
		EX_stall_in		=> EX_stall_out,	
		mem_addr_in		=> LAB_mem_addr_out,
		
		--Control	
		RF_out_1_mux	=> ID_RF_out_1_mux,
		RF_out_2_mux	=> ID_RF_out_2_mux,
		RF_out1_en		=> ID_RF_out1_en, 	
		RF_out2_en		=> ID_RF_out2_en,
		
		--Outputs
		IW_out			=> ID_EX_IW,			
		stall_out		=> ID_stall_out,		
		immediate_val	=> ID_EX_immediate_val,	
		mem_addr_out 	=> ID_EX_mem_address,
		reset_out		=> ID_reset_out	
	);
	
	EX_actual : EX
	port map (
		--Input data and clock
		reset_n					=> ID_reset_out, 
		sys_clock				=> sys_clock,	
		IW_in						=> ID_EX_IW,
		LAB_stall_in			=> LAB_stall_out,
		WB_stall_in				=> WB_stall_out,
		MEM_stall_in			=> MEM_stall_out,
		mem_addr_in				=> ID_EX_mem_address,
		immediate_val_in		=> ID_EX_immediate_val,
		
		--Control
		ALU_out1_en				=> ALU_out1_en, 
		ALU_out2_en				=> ALU_out2_en,
		ALU_d1_in_sel			=> ALU_d1_in_sel, 
		ALU_d2_in_sel			=> ALU_d2_in_sel,
		ALU_fwd_data_out_en	=> ALU_fwd_data_out_en,
		
		--Outputs
		ALU_op					=> ALU_op,
		ALU_inst_sel			=> ALU_inst_sel,
		EX_stall_out			=> EX_stall_out,
		IW_out					=> EX_MEM_IW,	
		mem_addr_out			=> ALU_mem_addr_out,
		immediate_val			=> ALU_immediate_val,
		reset_out				=>	EX_reset_out
	);
	
	MEM_actual : MEM
	port map ( 
		--Input data and clock
		reset_n						=> EX_reset_out, 
		sys_clock					=> sys_clock,	
		IW_in							=> EX_MEM_IW,
		LAB_stall_in				=> LAB_stall_out,
		WB_stall_in					=> WB_stall_out,
		I2C_error					=> I2C_error,
		I2C_op_run					=> I2C_op_run,
		
		--MEM Control Outputs
		MEM_out_mux_sel			=> MEM_MEM_out_mux_sel,
		MEM_wr_en					=> MEM_MEM_wr_en,
		
		--ION Control Outputs
		GPIO_in_en					=> MEM_GPIO_in_en, 
		GPIO_wr_en 					=> MEM_GPIO_wr_en,
		I2C_r_en						=> MEM_I2C_r_en, 
		I2C_wr_en					=> MEM_I2C_wr_en,
		slave_addr					=> MEM_slave_addr,
		
		--Outputs
		I2C_error_out				=> I2C_error_out,
		IW_out						=> MEM_WB_IW,
		stall_out					=> MEM_stall_out,
		reset_out					=> MEM_reset_out
	);
	
	WB_actual : WB
	port map ( 
		--Input data and clock
		reset_n						=> reset_n, 
		reset_MEM					=> MEM_reset_out,
		sys_clock					=> sys_clock,	
		IW_in							=> MEM_WB_IW, 
		PM_data_in					=> PM_data_in,
		LAB_stall_in				=> LAB_stall_out,
		MEM_out_top					=> MEM_out_top,
		GPIO_out						=> GPIO_out,
		I2C_out						=> I2C_out,
		
		--Control
		RF_in_demux					=> WB_RF_in_demux,
		RF_wr_en						=> WB_wr_en,
			
		--Outputs
		stall_out					=> WB_stall_out,
		WB_data_out					=> WB_data_out
	);
		
		
	process(reset_n, sys_clock)
	begin
		if reset_n = '0' then
			
				
		elsif rising_edge(sys_clock) then
		
			

		end if; --reset_n
		
	end process;
	
	--latch inputs
	
	--latch outputs
	
	
end behavioral;