--Written by: Joe Post

--This file contains all control unit sub-blocks, and provides all control signals to the other CPU sub-blocks. 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.arrays.ALL;
use work.control_unit_types.all;

entity control_unit is
   port ( 

		--TEST OUTPUT ONLY, REMOVE AFTER LAB INSTANTIATED (signal goes to LAB for arbitration)
		I2C_error_out						: out std_logic; 	
		
		--END TEST INPUTS
		
		--Input data and clock
		reset_n, sys_clock				: in std_logic;	
		PM_data_in							: in std_logic_vector(15 downto 0);
		PC_CU_out							: out std_logic_vector(10 downto 0);
		RF_in_3, RF_in_4					: in std_logic_vector(15 downto 0);
		RF_in_3_valid, RF_in_4_valid	: in std_logic;
		ALU_SR_in							: in std_logic_vector(3 downto 0);
		
		--MEM Feedback Signals
		I2C_error, I2C_op_run			: in std_logic;	
		I2C_complete						: in std_logic;
		
		--(ID) RF control signals
		ID_RF_out_1_mux					: out std_logic_vector(4 downto 0);	--controls first output mux
		ID_RF_out_2_mux					: out std_logic_vector(4 downto 0);	--controls second output mux
		ID_RF_out_3_mux					: out std_logic_vector(4 downto 0);	--controls third output mux
		ID_RF_out_4_mux					: out std_logic_vector(4 downto 0);	--controls fourth output mux
		ID_RF_out1_en, ID_RF_out2_en	: out std_logic; --enables RF_out_X 
		ID_RF_out3_en, ID_RF_out4_en	: out std_logic; --enables RF_out_X 
		RF_revalidate						: out std_logic_vector(31 downto 0);
		ID_EX_IW_actual					: out std_logic_vector(15 downto 0);
		
		--(EX) ALU control Signals
		ALU_out1_en, ALU_out2_en		: out std_logic; 
		ALU_d1_in_sel, ALU_d2_in_sel	: out std_logic_vector(1 downto 0); 
		ALU_fwd_data_out_en				: out std_logic; -- (ALU_top) ALU forwarding register out enable
		
		ALU_op								: out std_logic_vector(3 downto 0);
		ALU_inst_sel						: out std_logic_vector(1 downto 0);
		ALU_mem_addr_out					: out std_logic_vector(15 downto 0); -- memory address directly to ALU
		ALU_immediate_val					: out	std_logic_vector(15 downto 0); --represents various immediate values from various OpCodes
		
		--(MEM) MEM control Signals
		MEM_MEM_out_mux_sel				: out std_logic_vector(1 downto 0); --
		MEM_MEM_wr_en						: out std_logic; --write enable for data memory
		
		MEM_GPIO_in_en, MEM_GPIO_wr_en 	: out std_logic; --enables read/write for GPIO (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
		MEM_I2C_r_en, MEM_I2C_wr_en		: out std_logic; --initiates reads/writes for I2C (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
		MEM_slave_addr							: out std_logic_vector(6 downto 0);
		MEM_WB_mux_IW							: inout std_logic_vector(15 downto 0);
		
		--(WB) WB control Signals and Input/Output data
		WB_RF_in_demux						: out std_logic_vector(4 downto 0); -- selects which 
		WB_wr_en								: out std_logic;	-- RF_in_en sent to CSAM for arbitration. wr_en also sent to CSAM, although it's passed through. 
		
		MEM_out_top				: in std_logic_vector(15 downto 0);
		GPIO_out					: in std_logic_vector(15 downto 0);
		I2C_out					: in std_logic_vector(15 downto 0);
		WB_data_out				: inout std_logic_vector(15 downto 0);
		ROB_in					: inout ROB
	);
end control_unit;

architecture behavioral of control_unit is

	signal LAB_stall				: std_logic; --signal to logically or all other CU stall signals
	
	--LAB <-> ID Signals
	signal LAB_ID_IW				: std_logic_vector(15 downto 0);
	signal LAB_mem_addr_out		: std_logic_vector(15 downto 0);
	signal LAB_reset_out			: std_logic;
	signal LAB_stall_out			: std_logic;
	signal ID_stall_out			: std_logic;
	signal LAB_ID_fwd_reg1		: std_logic;
	signal LAB_ID_fwd_reg2		: std_logic;
	signal clear_ID_IW_out		: std_logic;
	
	--ID <-> EX Signals
	signal ID_EX_IW					: std_logic_vector(15 downto 0); --goes to mux
	signal ID_EX_mux_IW				: std_logic_vector(15 downto 0); --goes to EX control unit
	signal EX_stall_out				: std_logic;
	signal ID_EX_mem_address		: std_logic_vector(15 downto 0);
	signal ID_EX_immediate_val		: std_logic_vector(15 downto 0); --represents various immediate values from various OpCodes
	signal ID_reset_out				: std_logic;
	signal ID_EX_fwd_reg1			: std_logic;
	signal ID_EX_fwd_reg2			: std_logic;
	signal clear_EX_IW_out			: std_logic;
 
	--EX <-> MEM Signals
	signal EX_MEM_IW, EX_MEM_mux_IW	: std_logic_vector(15 downto 0); -- forwarding to MEM control unit
	signal MEM_stall_out					: std_logic;
	signal EX_reset_out					: std_logic;
	signal clear_MEM_IW_out				: std_logic;
	
	--MEM <-> WB Signals
	signal MEM_WB_IW						: std_logic_vector(15 downto 0);
	signal WB_stall_out					: std_logic;
	signal MEM_reset_out					: std_logic;
	
	--WB <-> LAB signals
	signal condition_met			: std_logic;
	signal results_available	: std_logic;
	signal WB_IW_out				: std_logic_vector(15 downto 0);
	signal frst_branch_index	: integer;
	
	component IFetch is
		generic ( 	LAB_MAX		: integer	:= 5;
						ROB_DEPTH 	: integer	:= 10	);
		port (
			reset_n, sys_clock  	: in std_logic;
			stall_pipeline			: in std_logic; --needed when waiting for certain commands, should be formulated in top level CU module
			ID_IW						: in std_logic_vector(15 downto 0); --source registers for instruction in ID stage (results available)
			EX_IW						: in std_logic_vector(15 downto 0); --source registers for instruction in EX stage (results available)
			MEM_IW					: in std_logic_vector(15 downto 0); --source registers for instruction in MEM stage (results available)
			WB_IW_in					: in std_logic_vector(15 downto 0);
			ID_reset, EX_reset, MEM_reset	: in std_logic;
			PM_data_in				: in std_logic_vector(15 downto 0);
			RF_in_3, RF_in_4		: in std_logic_vector(15 downto 0);
			WB_IW_out				: in std_logic_vector(15 downto 0);
			WB_data_out				: in std_logic_vector(15 downto 0);
			RF_in_3_valid			: in std_logic;
			RF_in_4_valid			: in std_logic;
			ROB_in					: in ROB;
			ALU_SR_in				: in std_logic_vector(3 downto 0);
			frst_branch_idx		: in integer;
			I2C_op_run				: in std_logic;
			
			PC							: out std_logic_vector(10 downto 0);
			IW							: out std_logic_vector(15 downto 0);
			MEM						: out std_logic_vector(15 downto 0); --MEM is the IW representing the next IW as part of LD, ST, JMP, BNE(Z) operations
			LAB_reset_out			: out std_logic; --reset signal for ID stage
			LAB_stall				: out std_logic;
			RF_out_3_mux			: out std_logic_vector(4 downto 0);
			RF_out_4_mux			: out std_logic_vector(4 downto 0);
			RF_out_3_en				: out std_logic;
			RF_out_4_en				: out std_logic;
			condition_met			: inout std_logic;	--signal to WB for ROB. as soon as "results_available" goes high, need to evaluate all instructions after first branch
			results_available		: inout std_logic;		--signal to WB for ROB. as soon as it goes high, need to evaluate all instructions after first branch
			ALU_fwd_reg_1 			: out std_logic;		--output to ID stage to tell EX stage to forward MEM_out data in to ALU_in_1
			ALU_fwd_reg_2 			: out std_logic;
			RF_revalidate			: out std_logic_vector(31 downto 0);
			clear_ID_IW_out		: out std_logic;
			clear_EX_IW_out		: out std_logic;
			clear_MEM_IW_out		: out std_logic
		);
	end component;

	component ID is
		port ( 
			--Input data and clock
			reset_n, sys_clock			: in std_logic;	
			IW_in								: in std_logic_vector(15 downto 0);
			ID_stall_in						: in std_logic;
			mem_addr_in						: in std_logic_vector(15 downto 0);
			ALU_fwd_reg_1_in				: in std_logic;		--input to tell EX stage to forward MEM_out data in to ALU_in_1
			ALU_fwd_reg_2_in				: in std_logic;		--input to tell EX stage to forward MEM_out data in to ALU_in_2
			
			--Control
			RF_out_1_mux					: out std_logic_vector(4 downto 0);	--controls first output mux
			RF_out_2_mux					: out std_logic_vector(4 downto 0);	--controls second output mux
			RF_out1_en, RF_out2_en		: out std_logic; --enables RF_out_X on B and C bus
			
			--Outputs
			IW_out							: out std_logic_vector(15 downto 0); --goes to EX control unit
			stall_out						: out std_logic;
			immediate_val					: out	std_logic_vector(15 downto 0); --represents various immediate values from various OpCodes
			mem_addr_out					: out std_logic_vector(15 downto 0);
			reset_out						: out std_logic;
			ALU_fwd_reg_1_out				: out std_logic;
			ALU_fwd_reg_2_out				: out std_logic
		);
	end component;
	
	component EX is
		port ( 
			--Input data and clock
			reset_n, sys_clock		: in std_logic;	
			IW_in							: in std_logic_vector(15 downto 0);
			EX_stall_in					: in std_logic;
			mem_addr_in					: in std_logic_vector(15 downto 0); --memory address from ID stage
			immediate_val_in			: in std_logic_vector(15 downto 0); --immediate value from ID stage
			ALU_fwd_reg_1_in			: in std_logic;
			ALU_fwd_reg_2_in			: in std_logic;
			
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
			MEM_stall_in				: in std_logic;
			I2C_error					: in std_logic;	--in case we can't write to slave after three attempts
			I2C_op_run					: in std_logic;	--when high, lets CU know that there is a CU operation occurring
			
			--MEM Control Outputs
			MEM_wr_en					: out std_logic; --write enable for data memory
			MEM_out_mux_sel			: out std_logic_vector(1 downto 0); --enables MEM output 
			
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
			reset_n, reset_MEM 	: in std_logic;
			sys_clock				: in std_logic;	
			IW_in, PM_data_in		: in std_logic_vector(15 downto 0); --IW from MEM and from PM, via LAB, respectively
			WB_stall_in				: in std_logic;		--set high when an upstream CU block needs this 
			MEM_out_top				: in std_logic_vector(15 downto 0);
			GPIO_out					: in std_logic_vector(15 downto 0);
			I2C_out					: in std_logic_vector(15 downto 0);
			condition_met			: in std_logic;		--signal to WB for ROB. as soon as "results_available" goes high, need to evaluate all instructions after first branch
			results_available		: in std_logic;		--signal to WB for ROB. as soon as it goes high, need to evaluate all instructions after first branch
			
			--Control
			RF_in_demux				: out std_logic_vector(4 downto 0); -- selects which register to write back to
			RF_wr_en					: out std_logic;	--
						
			--Outputs
			stall_out				: out std_logic;
			WB_data_out				: out std_logic_vector(15 downto 0);
			ROB_out					: out ROB;
			WB_IW_out				: out std_logic_vector(15 downto 0);
			frst_branch_index		: inout integer
		);
	end component;
	
	component mux_2_new is
	PORT
	(
		data0x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		data1x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		sel			: IN STD_LOGIC;
		result		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
	end component mux_2_new;
	
begin

	LAB_stall <= I2C_complete or LAB_stall_out;

	--currently using the LAB, ID, and EX feedback signals for data hazard checks, vice ID, EX, and MEM
	LAB	: IFetch
		port map(

		reset_n			=> reset_n, 
		sys_clock		=> sys_clock,
		stall_pipeline	=> LAB_stall,
		ID_IW				=> LAB_ID_IW,	
		EX_IW				=> ID_EX_IW,
		MEM_IW			=> EX_MEM_IW,
		WB_IW_in			=> MEM_WB_IW,
		ID_reset			=> LAB_reset_out,
		EX_reset			=> ID_reset_out, 
		MEM_reset		=> EX_reset_out,
		PM_data_in		=> PM_data_in,
		RF_in_3			=> RF_in_3,
		RF_in_4			=> RF_in_4,
		WB_IW_out		=> WB_IW_out,
		WB_data_out		=> WB_data_out,
		RF_in_3_valid	=> RF_in_3_valid,
		RF_in_4_valid	=> RF_in_4_valid,
		ROB_in			=>	ROB_in,
		ALU_SR_in		=> ALU_SR_in,
		frst_branch_idx => frst_branch_index,
		I2C_op_run		=> I2C_op_run,
		PC					=> PC_CU_out,
		IW					=> LAB_ID_IW,
		MEM				=> LAB_mem_addr_out,
		LAB_reset_out 	=> LAB_reset_out,
		LAB_stall		=> LAB_stall_out,
		RF_out_3_mux	=> ID_RF_out_3_mux,
		RF_out_4_mux	=> ID_RF_out_4_mux,
		RF_out_3_en		=> ID_RF_out3_en,
		RF_out_4_en		=> ID_RF_out4_en,
		condition_met	=> condition_met,
		results_available	=> results_available,
		ALU_fwd_reg_1 	=> LAB_ID_fwd_reg1,
		ALU_fwd_reg_2 	=> LAB_ID_fwd_reg2,
		RF_revalidate	=> RF_revalidate,
		clear_ID_IW_out	=> clear_ID_IW_out,
		clear_EX_IW_out	=> clear_EX_IW_out,
		clear_MEM_IW_out	=> clear_MEM_IW_out
	);

	ID_actual	: ID
	port map ( 
		--Input data and clock
		reset_n			=> LAB_reset_out, 
		sys_clock		=> sys_clock,	
		IW_in				=> LAB_ID_IW,
		ID_stall_in		=> I2C_complete,	
		mem_addr_in		=> LAB_mem_addr_out,
		ALU_fwd_reg_1_in	=> LAB_ID_fwd_reg1,
		ALU_fwd_reg_2_in	=> LAB_ID_fwd_reg2,
		
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
		reset_out		=> ID_reset_out,
		ALU_fwd_reg_1_out	=> ID_EX_fwd_reg1,
		ALU_fwd_reg_2_out	=> ID_EX_fwd_reg2
	);
	
	ID_EX_output_IW	: mux_2_new 
	PORT MAP
	(
		data0x		=> ID_EX_IW,
		data1x		=> "1111111111111111",
		sel			=> clear_ID_IW_out,
		result		=> ID_EX_mux_IW
	);
	
	ID_EX_IW_actual <= ID_EX_mux_IW;
	
	EX_actual : EX
	port map (
		--Input data and clock
		reset_n					=> ID_reset_out, 
		sys_clock				=> sys_clock,	
		IW_in						=> ID_EX_mux_IW,
		EX_stall_in				=> I2C_complete,
		mem_addr_in				=> ID_EX_mem_address,
		immediate_val_in		=> ID_EX_immediate_val,
		ALU_fwd_reg_1_in		=> ID_EX_fwd_reg1,
		ALU_fwd_reg_2_in		=> ID_EX_fwd_reg2,
		
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
	
	EX_MEM_output_IW	: mux_2_new 
	PORT MAP
	(
		data0x		=> EX_MEM_IW,
		data1x		=> "1111111111111111",
		sel			=> clear_EX_IW_out,
		result		=> EX_MEM_mux_IW
	);
	
	MEM_actual : MEM
	port map ( 
		--Input data and clock
		reset_n						=> EX_reset_out, 
		sys_clock					=> sys_clock,	
		IW_in							=> EX_MEM_mux_IW,
		MEM_stall_in				=> I2C_complete,
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
	
	MEM_WB_output_IW	: mux_2_new 
	PORT MAP
	(
		data0x		=> MEM_WB_IW,
		data1x		=> "1111111111111111",
		sel			=> clear_MEM_IW_out,
		result		=> MEM_WB_mux_IW
	);
	
	WB_actual : WB
	port map ( 
		--Input data and clock
		reset_n						=> reset_n, 
		reset_MEM					=> MEM_reset_out,
		sys_clock					=> sys_clock,	
		IW_in							=> MEM_WB_mux_IW, 
		PM_data_in					=> PM_data_in,
		WB_stall_in					=> '0',
		MEM_out_top					=> MEM_out_top,
		GPIO_out						=> GPIO_out,
		I2C_out						=> I2C_out,
		condition_met				=> condition_met,
		results_available			=> results_available,
		
		--Control
		RF_in_demux					=> WB_RF_in_demux,
		RF_wr_en						=> WB_wr_en,
			
		--Outputs
		stall_out					=> WB_stall_out,
		WB_data_out					=> WB_data_out,
		ROB_out						=> ROB_in,
		WB_IW_out					=> WB_IW_out,
		frst_branch_index			=> frst_branch_index
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