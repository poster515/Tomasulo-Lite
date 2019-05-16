library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity ALU_top is
	port (
		--Input data and clock
		sys_clock, reset_n	: in std_logic;
		RF_in_1, RF_in_2		: in std_logic_vector(15 downto 0);
		MEM_in					: in std_logic_vector(15 downto 0); --data forwarded from data memory output
		MEM_address				: in std_logic_vector(15 downto 0); --memory address forwarded directly from LAB via ID stage
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
end ALU_top; 

architecture behavioral of ALU_top is

	component ALU is
		port (
			--Input data
			carry_in				: in std_logic; --carry in bit from the Control Unit Status Register
			data_in_1 			: in std_logic_vector(15 downto 0); --data from RF data out 1
			data_in_2 			: in std_logic_vector(15 downto 0); --data from RF data out 2
			
			--Control signals
			ALU_op				: in std_logic_vector(3 downto 0); --dictates ALU operation (i.e., OpCode)
			ALU_inst_sel		: in std_logic_vector(1 downto 0); --dictates what sub-function to execute
			
			--Outputs
			ALU_out_1   		: out std_logic_vector(15 downto 0); --output for almost all logic functions
			ALU_out_2   		: out std_logic_vector(15 downto 0); --use for MULT MSBs and DIV remainder
			ALU_status 			: out std_logic_vector(3 downto 0) --provides | Zero (Z) | Overflow (V) | Negative (N) | Carry (C) |
		);
	end component ALU;
	
	component mux_4_new is
	PORT
	(
		data0x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		data1x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		data2x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		data3x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		sel			: IN STD_LOGIC_VECTOR (1 DOWNTO 0);
		result		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
	end component mux_4_new;
	
	component mux_2_new is
	PORT
	(
		data0x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		data1x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		sel			: IN STD_LOGIC;
		result		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
	end component mux_2_new;

	signal ALU_out_1, ALU_out_2	 			: std_logic_vector(15 downto 0); --output signals from the ALU
	signal ALU_out1_reg, ALU_out2_reg		: std_logic_vector(15 downto 0); --output registers for ALU_top
	signal ALU_SR_reg								: std_logic_vector(3 downto 0); --
	signal ALU_data_in_1, ALU_data_in_2		: std_logic_vector(15 downto 0); --signal between data_in_2_mux and data_in_2 input of ALU
	signal ALU_status								: std_logic_vector(3 downto 0);	--ALU temporary status register

begin
	
	ALU_inst	: ALU
	port map (
		--Input data
		carry_in				=> ALU_status(0),	--forward ALU status register (carry bit) into ALU
		data_in_1 			=> ALU_data_in_1,
		data_in_2 			=> ALU_data_in_2, --for STORES, forward source register data to this input

		--Control signals
		ALU_op			=> ALU_op,
		ALU_inst_sel	=> ALU_inst_sel,

		--Outputs
		ALU_out_1   => ALU_out_1,
		ALU_out_2   => ALU_out_2,	
		ALU_status 	=> ALU_status
	);
	--mux for ALU input 1 
	ALU_in_1_mux	: mux_4_new
	port map (
		data0x	=> "0000000000000000",
		data1x  	=> RF_in_1, 		--input from RF_out_1
		data2x	=> MEM_address,
		data3x	=> MEM_in,
		sel 		=> ALU_d1_in_sel,
		result  	=> ALU_data_in_1
	);
	
	--mux for ALU input 2 
	ALU_in_2_mux	: mux_4_new
	port map (
		data0x	=> "0000000000000000",
		data1x  	=> RF_in_2, 		--input from RF_out_2
		data2x  	=> value_immediate,
		data3x	=> MEM_in,
		sel 		=> ALU_d2_in_sel,
		result  	=> ALU_data_in_2
	);
	
	process(reset_n, sys_clock, ALU_out_1, ALU_out_2, ALU_out1_en, ALU_out2_en)
	begin
		if reset_n = '0' then
			ALU_out1_reg 	<= "0000000000000000";
			ALU_out2_reg 	<= "0000000000000000";
			ALU_SR_reg		<= "0000";
			
		elsif rising_edge(sys_clock) then
			if ALU_out1_en = '1' then
				ALU_out1_reg 	<= ALU_out_1;
			end if;
			
			if ALU_fwd_data_out_en = '0' and ALU_out2_en = '1' then
				ALU_out2_reg 	<= ALU_out_2;
			elsif ALU_fwd_data_out_en = '1' and ALU_out2_en = '1' then
				ALU_out2_reg 	<= RF_in_1; --forwarding data for stores, e.g.
			end if;
			
			ALU_SR_reg		<= ALU_status;
		
		end if; --reset_n
	end process;
	
	--latch outputs
	ALU_top_out_1 	<= ALU_out1_reg;
	ALU_top_out_2 	<= ALU_out2_reg;
	ALU_SR 			<= ALU_SR_reg;
	
end behavioral;