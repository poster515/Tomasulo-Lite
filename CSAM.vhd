--Written by: Joe Post

--This file receives bus control signals from most CU modules (i.e., ID, EX, MEM, WB), and arbitrates them.
--All logic is purely combinational since the outputs are needed in the same clock cycle they're issued.
--Priority arbitrarily is delegated to the control unit farthest into process (i.e., WB). 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity CSAM is
   port ( 
		--Input data and clock
		reset_n, sys_clock	: in std_logic;	
		
		--Control Inputs
		
		--RF (ID)
		RF_out1_en, RF_out2_en		: in std_logic; --enables RF_out_X on B and C bus
		RF_out_1_mux, RF_out_2_mux	: in std_logic_vector(4 downto 0); --selects register from RF, needs to be coordinated with associated out_en
		
		--RF (WB)
		RF_WB_in_demux					: in std_logic_vector(4 downto 0);
		RF_in_en, RF_WB_wr_en		: in std_logic;	
		
		--ALU (EX)
		ALU_out1_en, ALU_out2_en	: in std_logic; --enables ALU_out_X on B and C bus
		
		--ION (MEM)
		ION_A_bus_out_sel 			: in std_logic; --enables ION output to A or B bus (ONLY SET HIGH WHEN RESULTS ARE READY)
		ION_B_bus_out_sel				: in std_logic; --enables ION output to A or B bus (ONLY SET HIGH WHEN RESULTS ARE READY)

		--TODO: also need to coordinate various input_sel lines, since this CSAM is arbitrating output enables
		
		--Control Outputs
		
		--RF
		RF_wr_enO 							: out std_logic; --enables write for a selected register
		B_bus_out_muxO						: out std_logic_vector(4 downto 0);	--controls first RF output mux
		C_bus_out_muxO						: out std_logic_vector(4 downto 0);	--controls second RF output mux
		RF_in_demuxO						: out std_logic_vector(4 downto 0);	--controls which register to write data to
		RF_B_bus_out_enO					: out std_logic; --enables RF outputs on B bus
		RF_C_bus_out_enO					: out std_logic; --enables RF outputs on C bus
		B_bus_in_enO, C_bus_in_enO		: out std_logic; --enables B and C bus data in to RF
		
		--ALU
		ALU_opO								: out std_logic_vector(3 downto 0); 	--dictates ALU operation (i.e., OpCode)
		ALU_inst_selO						: out std_logic_vector(1 downto 0); 	--dictates what sub-function to execute (last two bits of OpCode)
		ALU_d2_mux_selO					: out std_logic_vector(1 downto 0); 	--which data to send to ALU input 2: 0=ALU result 1=data forwarded from ALU_data_in_1
		ALU_B_bus_out1_enO				: out std_logic; --enables ALU_out_1 on B bus
		ALU_C_bus_out1_enO				: out std_logic; --enables ALU_out_1 on C bus
		ALU_B_bus_out2_enO				: out std_logic; --enables ALU_out_2 on B bus
		ALU_C_bus_out2_enO				: out std_logic; --enables ALU_out_2 on C bus
		
		--MEM
		MEM_A_bus_out_enO					: out std_logic; --enables data memory output on A bus 
		MEM_C_bus_out_enO					: out std_logic; --enables data memory output on C bus
		MEM_A_bus_in_selO					: out std_logic; --enables A bus to data_in
		MEM_C_bus_in_selO					: out std_logic; --enables C bus to data_in
		MEM_wr_enO							: out std_logic; --write enable for data memory
		
		--ION
		GPIO_r_en, GPIO_wr_enO 			: out std_logic; --enables read/write for GPIO (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
		I2C_r_en, I2C_wr_enO				: out std_logic; --initiates reads/writes for I2C (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
		ION_A_bus_out_selO 				: out std_logic; --enables A bus onto output_buffer (ONLY SET HIGH WHEN RESULTS ARE READY)
		ION_B_bus_out_selO				: out std_logic; --enables B bus onto output_buffer (ONLY SET HIGH WHEN RESULTS ARE READY)
		ION_A_bus_in_selO 				: out std_logic; --enables input_buffer from A bus
		ION_B_bus_in_selO					: out std_logic  --enables input_buffer from B bus
		
	);
end CSAM;

architecture behavioral of CSAM is
	
begin

	process(reset_n, sys_clock)
	begin
		if reset_n = '0' then
			
		elsif rising_edge(sys_clock) then

		end if; --reset_n
		
	end process;
	
	--latch inputs
	
	--latch outputs
	
end behavioral;