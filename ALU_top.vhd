library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity ALU_top is
	port (
		--Input data and clock
		clk 					: in std_logic;
		WB_data				: in std_logic_vector(15 downto 0); --data forwarded from the WB stage 
		MEM_data				: in std_logic_vector(15 downto 0); --data forwarded from memory stage
		MEM_address			: in std_logic_vector(15 downto 0); --memory address forwarded directly from LAB
		value_immediate	: in std_logic_vector(15 downto 0); --Reg2 data field from IW directly from EX
																				--used to forward shift/rotate distance and immediate value for addi & subi

		--Control signals
		reset_n					: in std_logic; --all registers reset to 0 when this goes low
		ALU_op					: in std_logic_vector(3 downto 0); 	--dictates ALU operation (i.e., OpCode)
		ALU_inst_sel			: in std_logic_vector(1 downto 0); 	--dictates what sub-function to execute (last two bits of OpCode)
		ALU_d2_mux_sel			: in std_logic_vector(1 downto 0); 	--used to control which data to send to ALU input 2
	
		B_bus_out1_en, C_bus_out1_en		: in std_logic; --enables ALU_out_1 on B and C bus
		B_bus_out2_en, C_bus_out2_en		: in std_logic; --enables ALU_out_2 on B and C bus	
		B_bus_in1_sel, C_bus_in1_sel		: in std_logic; --enables B or C bus into ALU input 1
		B_bus_in2_sel, C_bus_in2_sel		: in std_logic; --enables B or C bus into ALU input 2 
												 
		--Outputs
		mem_addr_eff		: out std_logic_vector(10 downto 0);
		ALU_SR 				: out std_logic_vector(3 downto 0); --provides | Zero (Z) | Overflow (V) | Negative (N) | Carry (C) |
		B_bus, C_bus		: inout std_logic_vector(15 downto 0)
   );
end ALU_top; 

architecture behavioral of ALU_top is

	component ALU is
		port (
			--Input data and clock
			clk 					: in std_logic;	
			carry_in				: in std_logic; --carry in bit from the Control Unit Status Register
			data_in_1 			: in std_logic_vector(15 downto 0); --data from RF data out 1
			data_in_2 			: in std_logic_vector(15 downto 0); --data from RF data out 2
			value_immediate	: in std_logic_vector(15 downto 0);
			
			--Control signals
			reset_n				: in std_logic; --all registers reset to 0 when this goes low
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

	signal ALU_out_1, ALU_out_2			 	: std_logic_vector(15 downto 0); --output signals from the ALU
	signal ALU_data_in_1, ALU_data_in_2		: std_logic_vector(15 downto 0); --signal between data_in_2_mux and data_in_2 input of ALU
	signal ALU_status								: std_logic_vector(3 downto 0);	--ALU temporary status register
	signal LD_ST_op								: std_logic; --1 = its a load/store operation, 0 = its not
	signal data_in_1, data_in_2				: std_logic_vector(15 downto 0);
	
begin
	
	ALU_inst	: ALU
	port map (
		--Input data and clock
		clk 					=> clk,
		carry_in				=> ALU_status(0),	--forward ALU status register (carry bit) into ALU
		data_in_1 			=> ALU_data_in_1,
		data_in_2 			=> ALU_data_in_2, --for STORES, forward source register data to this input
		value_immediate	=> value_immediate,

		--Control signals
		reset_n			=> reset_n,
		ALU_op			=> ALU_op,
		ALU_inst_sel	=> ALU_inst_sel,

		--Outputs
		ALU_out_1   => ALU_out_1,
		ALU_out_2   => ALU_out_2,	
		ALU_status 	=> ALU_status
	);

	--mux that takes RF, MEM, WB, and ALU data and provides to ALU input 2
	ALU_in_2_mux	: mux_4_new
	port map (
		data0x   => data_in_2, 		--input from A or C bus
		data1x   => WB_data,			--forwarded data from WB stage
		data2x   => MEM_data,		--forwarded data from MEM stage
		data3x   => ALU_out_1, 		--reroute this signal for immediate forwarding
		sel 		=> ALU_d2_mux_sel, --from CU directly. can't compute from IW(1..0) alone. 
		result   => ALU_data_in_2
	);
	
	--mux that takes RF data and memory address directly from LD/ST IWs 
	ALU_in_1_mux	: mux_2_new
	port map (
		data0x  	=> data_in_1, 		--input from A or C bus
		data1x  	=> MEM_address,	--memory address directly from LAB to calculate effective memory address
		sel 		=> LD_ST_op,
		result  	=> ALU_data_in_1
	);
	
	--process required to compute select bit for ALU input 1 mux
	process (ALU_op, ALU_inst_sel) 
	begin
		LD_ST_op <= ALU_op(3) and not(ALU_op(2)) and not(ALU_op(1)) and not(ALU_op(0));
	end process;
	
	process(reset_n, clk, B_bus_out1_en, C_bus_out1_en, B_bus_out2_en, C_bus_out2_en)
	begin
	--if reset_n = '0' then
		if clk'event and clk = '1' then
			ALU_SR <= ALU_status;
			
			if B_bus_in1_sel = '1' then
				data_in_1 <= B_bus;
			elsif C_bus_in1_sel = '1' then
				data_in_1 <= C_bus; 			--this will be the source register used during store operations	
			end if;
								
			if B_bus_in2_sel = '1' then
				data_in_2 <= B_bus;
			elsif C_bus_in2_sel = '1' then
				data_in_2 <= C_bus; 			--this will be the source register used during store operations	
			end if;
			
			if LD_ST_op = '1' then --LD/ST operation
			
				mem_addr_eff <= ALU_out_1; --forward calculated effective memory address directly to MEM

				if ALU_inst_sel(1) = '1' then --ST operation specifically
					if (B_bus_out2_en = '1') then
						B_bus <= data_in_1; --forward source register data to MEM_top
						
					elsif (C_bus_out2_en = '1') then
						C_bus <= data_in_1; --forward source register data to MEM_top
						
					else
						B_bus <= "ZZZZZZZZZZZZZZZZ";
						C_bus <= "ZZZZZZZZZZZZZZZZ";
					end if; -- bus signals
				end if; --ALU_inst_sel(1) = '1'
			
			else
			
				if (B_bus_out1_en = '1') then
					B_bus <= ALU_out_1;
					
				elsif (C_bus_out1_en = '1') then
					C_bus <= ALU_out_1;
					
				elsif (B_bus_out2_en = '1') then
					B_bus <= ALU_out_2;
					
				elsif (C_bus_out2_en = '1') then
					C_bus <= ALU_out_2;
					
				else
					B_bus <= "ZZZZZZZZZZZZZZZZ";
					C_bus <= "ZZZZZZZZZZZZZZZZ";
				end if; -- bus signals
			end if; -- LD_ST_op = '1'
		end if; -- reset_n, clock
	end process;
		
end behavioral;