library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity ALU_top is
	port (
		--Input data and clock
		clk 					: in std_logic;
		MEM_address			: in std_logic_vector(15 downto 0); --memory address forwarded directly from LAB
		value_immediate	: in std_logic_vector(15 downto 0); --Reg2 data field from IW directly from EX
																				--used to forward shift/rotate distance and immediate value for addi & subi

		--Control signals
		reset_n				: in std_logic; --all registers reset to 0 when this goes low
		ALU_op				: in std_logic_vector(3 downto 0); 	--dictates ALU operation (i.e., OpCode)
		ALU_inst_sel		: in std_logic_vector(1 downto 0); 	--dictates what sub-function to execute (last two bits of OpCode)
		
		ALU_d2_bus_in_sel	: in std_logic_vector(1 downto 0); 	--used to control which bus to send to ALU input 2 (from CSAM)
		ALU_d2_immed_op	: in std_logic; 	--1 = need to get value_immediate to ALU_in_2, 0 = just use A, B, or C bus data (using ALU_d2_bus_in_sel) (from EX)
		ALU_d1_bus_in_sel : in std_logic_vector(1 downto 0); 	--used to control which bus to send to ALU input 1 (from CSAM)
		ALU_d1_DM_op		: in std_logic;	--1 = need to get MEM_address to ALU_in_1, 0 = just use A, B, or C bus data (using ALU_d1_bus_in_sel) (from EX)
		ALU_out_1_mux 		: in std_logic_vector(1 downto 0); --used to output results on A, B, or C bus
		ALU_out_2_mux		: in std_logic_vector(1 downto 0); --used to output results on A, B, or C bus
		ALU_fwd_data_in_mux_sel : in std_logic_vector(1 downto 0); --(CSAM)
		ALU_fwd_data_out_en		: in std_logic; --selects fwd reg to output data onto A, B, or C bus (EX)
		
		--Outputs
		ALU_SR 				: out std_logic_vector(3 downto 0); --provides | Zero (Z) | Overflow (V) | Negative (N) | Carry (C) |
		A_bus, B_bus, C_bus		: inout std_logic_vector(15 downto 0)
   );
end ALU_top; 

architecture behavioral of ALU_top is

	component ALU is
		port (
			--Input data
			carry_in				: in std_logic; --carry in bit from the Control Unit Status Register
			data_in_1 			: in std_logic_vector(15 downto 0); --data from RF data out 1
			data_in_2 			: in std_logic_vector(15 downto 0); --data from RF data out 2
			value_immediate	: in std_logic_vector(15 downto 0);
			
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
	
	component mux_8_new is
	PORT
		(
			data0x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			data1x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			data2x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			data3x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			data4x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			data5x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			data6x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			data7x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			sel			: IN STD_LOGIC_VECTOR (2 DOWNTO 0);
			result		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
		);
	end component mux_8_new;

	signal ALU_out_1, ALU_out_2			 	: std_logic_vector(15 downto 0); --output signals from the ALU
	signal ALU_data_in_1, ALU_data_in_2		: std_logic_vector(15 downto 0); --signal between data_in_2_mux and data_in_2 input of ALU
	signal ALU_d1_in_reg, ALU_d2_in_reg		: std_logic_vector(15 downto 0); --registers latching ALU inputs
	signal ALU_status								: std_logic_vector(3 downto 0);	--ALU temporary status register
	signal ALU_d1_mux_sel, ALU_d2_mux_sel	: std_logic_vector(2 downto 0); --mux select lines for ALU_in_1 and ALU_in_2
	signal ALU_fwd_data_reg, ALU_fwd_data_in	: std_logic_vector(15 downto 0); --stores forwarding data (e.g., DM stores)

begin
	
	ALU_inst	: ALU
	port map (
		--Input data
		carry_in				=> ALU_status(0),	--forward ALU status register (carry bit) into ALU
		data_in_1 			=> ALU_d2_in_reg,
		data_in_2 			=> ALU_d1_in_reg, --for STORES, forward source register data to this input
		value_immediate	=> value_immediate, --needed as immediate value for shift amounts, ADDI, SUBI, etc.

		--Control signals
		ALU_op			=> ALU_op,
		ALU_inst_sel	=> ALU_inst_sel,

		--Outputs
		ALU_out_1   => ALU_out_1,
		ALU_out_2   => ALU_out_2,	
		ALU_status 	=> ALU_status
	);
	
	--mux for ALU input 2 
	ALU_in_2_mux	: mux_8_new
	port map (
		data0x  	=> A_bus, 		--input from A, B, or C bus
		data1x  	=> B_bus,		--
		data2x	=> C_bus,
		data3x	=> value_immediate,
		data4x	=> "0000000000000000",
		data5x	=> "0000000000000000",
		data6x	=> "0000000000000000",
		data7x	=> "0000000000000000",
		sel 		=> ALU_d2_mux_sel,
		result  	=> ALU_data_in_2
	);
	
	--mux for ALU input 1 
	ALU_in_1_mux	: mux_8_new
	port map (
		data0x  	=> A_bus, 		--input from A, B, or C bus
		data1x  	=> B_bus,		--
		data2x	=> C_bus,
		data3x	=> MEM_address,
		data4x	=> "0000000000000000",
		data5x	=> "0000000000000000",
		data6x	=> "0000000000000000",
		data7x	=> "0000000000000000",
		sel 		=> ALU_d1_mux_sel,
		result  	=> ALU_data_in_1
	);
	
	--mux for ALU fwd data register
	ALU_fwd_data_mux	: mux_4_new
	port map (
		data0x  	=> A_bus, 		--input from A, B, or C bus
		data1x  	=> B_bus,		--
		data2x	=> C_bus,
		data3x	=> "0000000000000000",
		sel 		=> ALU_fwd_data_in_mux_sel,
		result  	=> ALU_fwd_data_in
	);
	
	ALU_d2_mux_sel(0) <= not(ALU_d2_bus_in_sel(0)) and (ALU_d2_bus_in_sel(1) or ALU_d2_immed_op);
	ALU_d2_mux_sel(1) <= (ALU_d2_bus_in_sel(1) and ALU_d2_bus_in_sel(0)) or 
								(not(ALU_d2_bus_in_sel(1)) and not(ALU_d2_bus_in_sel(0)) and ALU_d2_immed_op);
	ALU_d2_mux_sel(2) <= not(ALU_d2_bus_in_sel(1)) and not(ALU_d2_bus_in_sel(0)) and not(ALU_d2_immed_op);
	
	ALU_d1_mux_sel(0) <= not(ALU_d1_bus_in_sel(0)) and (ALU_d1_bus_in_sel(1) or ALU_d1_DM_op);
	ALU_d1_mux_sel(1) <= (ALU_d1_bus_in_sel(1) and ALU_d1_bus_in_sel(0)) or 
								(not(ALU_d1_bus_in_sel(1)) and not(ALU_d1_bus_in_sel(0)) and ALU_d1_DM_op);
	ALU_d1_mux_sel(2) <= not(ALU_d1_bus_in_sel(1)) and not(ALU_d1_bus_in_sel(0)) and not(ALU_d1_DM_op);
	
	process(reset_n, clk, ALU_out_1_mux, ALU_out_2_mux)
	begin
		if reset_n = '0' then
			ALU_SR <= "0000";
			A_bus <= "ZZZZZZZZZZZZZZZZ";
			B_bus <= "ZZZZZZZZZZZZZZZZ";
			C_bus <= "ZZZZZZZZZZZZZZZZ";
		
		elsif clk'event and clk = '1' then
		
			ALU_SR <= ALU_status;
		
			--latch ALU inputs
			ALU_d1_in_reg <= ALU_data_in_1;
			ALU_d2_in_reg <= ALU_data_in_2;
			ALU_fwd_data_reg <= ALU_fwd_data_in;
			
			--output latches. by using the "00" for high impendance output we ensure that during resets
			--the busses are being driven high.
			if ALU_out_1_mux = "01" then
				A_bus <= ALU_out_1;
				
			elsif ALU_out_1_mux = "10" then
				B_bus <= ALU_out_1;
				
			elsif ALU_out_1_mux = "11" then
				C_bus <= ALU_out_1;
				
			else 
				A_bus <= "ZZZZZZZZZZZZZZZZ";
				B_bus <= "ZZZZZZZZZZZZZZZZ";
				C_bus <= "ZZZZZZZZZZZZZZZZ";
			end if;
			
			if ALU_out_2_mux = "01" then
			
				if ALU_fwd_data_out_en = '1' then
					A_bus <= ALU_fwd_data_reg;
				else
					A_bus <= ALU_out_2;
				end if;
				
			elsif ALU_out_2_mux = "10" then
			
				if ALU_fwd_data_out_en = '1' then
					B_bus <= ALU_fwd_data_reg;
				else
					B_bus <= ALU_out_2;
				end if;
				
			elsif ALU_out_2_mux = "11" then
			
				if ALU_fwd_data_out_en = '1' then
					C_bus <= ALU_fwd_data_reg;
				else
					C_bus <= ALU_out_2;
				end if;
				
			else 
				A_bus <= "ZZZZZZZZZZZZZZZZ";
				B_bus <= "ZZZZZZZZZZZZZZZZ";
				C_bus <= "ZZZZZZZZZZZZZZZZ";
			end if;
		end if; -- reset_n, clock
	end process;
		
end behavioral;