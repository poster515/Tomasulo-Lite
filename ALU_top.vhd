library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity ALU_top is
	port (
		--Input data and clock
		clk 					: in std_logic;
		--status_reg			: in std_logic_vector(3 downto 0);	--status register from CU
		RF_data_in_1 		: in std_logic_vector(15 downto 0); --data from RF data out 1
		RF_data_in_2 		: in std_logic_vector(15 downto 0); --data from RF data out 2
		WB_data				: in std_logic_vector(15 downto 0); --data forwarded from the WB stage 
		MEM_data			: in std_logic_vector(15 downto 0); --data forwarded from memory stage
		MEM_address		: in std_logic_vector(15 downto 0); --memory address forwarded directly from IF stage
		value_immediate	: in std_logic_vector(15 downto 0); --Reg2 data field from IW forwarded through RF block
																		--used to forward shift/rotate distance and immediate value for addi & subi

		--Control signals
		reset_n					: in std_logic; --all registers reset to 0 when this goes low
		ALU_op					: in std_logic_vector(3 downto 0); --dictates ALU operation (i.e., OpCode)
		ALU_inst_sel			: in std_logic_vector(1 downto 0); --dictates what sub-function to execute (last two bits of OpCode)
		ALU_d2_mux_sel			: in std_logic_vector(1 downto 0); --used to control which data to send to ALU input 2
												 --0=ALU result 1=data forwarded from ALU_data_in_1
		B_bus_out1_en, C_bus_out1_en		: in std_logic; --enables RF_out_1 on B and C bus
		B_bus_out2_en, C_bus_out2_en		: in std_logic; --enables RF_out_2 on B and C bus													 
												 
		--Outputs
		ALU_SR 						: out std_logic_vector(3 downto 0); --provides | Zero (Z) | Overflow (V) | Negative (N) | Carry (C) |
		B_bus, C_bus		: inout std_logic_vector(15 downto 0)
   );
end ALU_top; 

	--Instruction Set Architecture--
	
--ADD(I)		Add (immediate) 		0000	
--SUB(I)		Subtract (immediate)	0001	--immediate value will be direct input from CU
--MULT(I)	Multiply (immediate)	0010	
--DIV(I)		Divide (immediate)	0011	
--LOG			Logical ops				0100	
--ROT(C)		Rotate (with carry)	0101	
--SFTL		Shift logical			0110	--shift value is from immediate value
--SFTA		Shift arithmetic		0111	--shift value is from immediate value
--LD			Load from DM			1000  --compute address if needed
--ST			Store to DM				1001  --compute address if needed
--BNEZ		Branch if not zero	1010
--BNE			Branch if not equal	1011
--JMP			Jump						1100
--IO			R/W from IO unit		1101
--(unused)	N/A						1110
--(unused)	N/A						1111

architecture behavioral of ALU_top is
	
	--import mux
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
			ALU_out_1   	: out std_logic_vector(15 downto 0); --output for almost all logic functions
			ALU_out_2   	: out std_logic_vector(15 downto 0); --use for MULT MSBs and DIV remainder
			ALU_status 		: out std_logic_vector(3 downto 0) --provides | Zero (Z) | Overflow (V) | Negative (N) | Carry (C) |
		);
	end component ALU;
	
	component mux_4 is
	port ( 
		sel 		: in  std_logic_vector(1 downto 0);
		--
		in_0   	: in  std_logic_vector(15 downto 0);
		in_1   	: in  std_logic_vector(15 downto 0);
		in_2   	: in  std_logic_vector(15 downto 0);
		in_3   	: in  std_logic_vector(15 downto 0);
		--
		data_out  : out std_logic_vector(15 downto 0)
		);
	end component mux_4;
	
	component mux_2 is
	port ( 
		sel 		: in  std_logic;
		--
		in_0   	: in  std_logic_vector(15 downto 0);
		in_1   	: in  std_logic_vector(15 downto 0);
		--
		sig_out  : out std_logic_vector(15 downto 0)
		);
	end component mux_2;
	
	--signal list
	signal ALU_out_1, ALU_out_2			 	: std_logic_vector(15 downto 0); --output signals from the ALU
	signal ALU_data_in_1, ALU_data_in_2		: std_logic_vector(15 downto 0); --signal between data_in_2_mux and data_in_2 input of ALU
	signal ALU_status, ALU_TSR					: std_logic_vector(3 downto 0);	--ALU temporary status register
	signal ALU_in1_mux_sel						: std_logic;
begin
	
	ALU_inst	: ALU
	port map (
		--Input data and clock
		clk 					=> clk,
		carry_in				=> ALU_status(0),	--forward ALU status register (carry bit) into ALU
		data_in_1 			=> ALU_data_in_1,
		data_in_2 			=> ALU_data_in_2,
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
	ALU_data_2_mux	: mux_4
	port map (
		sel 		=> ALU_d2_mux_sel, --from CU directly. can't compute from IW(1..0) alone. 
		--
		in_0   	=> RF_data_in_2, 	--input from RF
		in_1   	=> WB_data,			--forwarded data from WB stage
		in_2   	=> MEM_data,		--forwarded data from MEM stage
		in_3   	=> ALU_out_1, 		--reroute this signal for immediate forwarding
		--
		data_out  => ALU_data_in_2
	);
	
	--mux that takes RF data and memory address directly from LD/ST IWs 
	ALU_data_1_mux	: mux_2
	port map (
		sel 		=> ALU_in1_mux_sel,
		--
		in_0   	=> RF_data_in_1, 	--input from RF
		in_1   	=> MEM_address,	--memory address from second IW to calculate effective memory address
		--
		sig_out  => ALU_data_in_1
	);
	
	ALU_in1_mux_sel <= ALU_op(3) and not(ALU_op(2)) and not(ALU_op(1)) and not(ALU_inst_sel(0));
	ALU_SR <= ALU_TSR;
	-- Latching Logic Assignments
	process(reset_n, clk, B_bus_out1_en, C_bus_out1_en, B_bus_out2_en, C_bus_out2_en)
	begin
	--if reset_n = '0' then
		if clk'event and clk = '1' then
			ALU_TSR <= ALU_status;
			
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
		end if; -- clock
	end process;
		
end behavioral;