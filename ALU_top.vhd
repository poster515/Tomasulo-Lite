library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity ALU_top is
  port (
    --Input data and clock
	 clk 					: in std_logic;
	 RF_data_in_1 		: in std_logic_vector(15 downto 0); --data from RF data out 1
	 RF_data_in_2 		: in std_logic_vector(15 downto 0); --data from RF data out 2
	 WB_data				: in std_logic_vector(15 downto 0); --data forwarded from the WB stage 
	 MEM_data			: in std_logic_vector(15 downto 0); --data forwarded from memory stage
	 MEM_address		: in std_logic_vector(15 downto 0); --memory address forwarded directly from IF stage
	 Value_immediate	: in std_logic_vector(15 downto 0); --immediate operand value forwarded through RF block
																			--used to forward LD register value, shift value, and immediate value for addi & subi
	 
	 --Control signals
	 reset_n					: in std_logic; --all registers reset to 0 when this goes low
	 ALU_op					: in std_logic_vector(3 downto 0); --dictates ALU operation (i.e., OpCode)
	 ALU_inst_sel			: in std_logic_vector(1 downto 0); --dictates what sub-function to execute
	 ALU_data_2_mux		: in std_logic_vector(1 downto 0); --used to control which data to send to ALU input 2
	 ALU_out_reg_wr_en 	: in std_logic; --used to enable latching data into ALU output register
	 ALU_OReg_mux_sel		: in std_logic; --used to select which input to latch into ALU output register
													 --0=ALU result 1=data forwarded from ALU_data_in_1
													 
    --Outputs
    ALU_out   		: inout std_logic_vector(15 downto 0); --combinational output
	 ALU_out_fwd   : out std_logic_vector(15 downto 0); --
    ALU_status 	: out std_logic_vector(3 downto 0); --provides | Zero (Z) | Overflow (V) | Negative (N) | ??? |
	 MEM_effective	: out std_logic_vector(15 downto 0)
    );
end ALU_top;

--ADD		Add 						0000	
--ADDI	Add immediate			0001	--immediate value will be direct input from CU
--SUB		Subtract					0010	
--SUBI	Subtract immediate	0011	
--MULT	Multiply					0100	
--DIV		Divide					0101	
--SLA		Shift left arith		0110	--shift value is from immediate value
--SRA		Shift right arith		0111	--shift value is from immediate value
--LD		Load from DM			1000  --compute address if needed
--ST		Store to DM				1001  --compute address if needed
--BNEZ	Branch if not zero	1010
--BNE		Branch if not equal	1011
--JMP		Jump						1100
--(unused)	N/A					1101  --potential floating point operation?
--(unused)	N/A					1110
--(unused)	N/A					1111

architecture behavioral of ALU_top is
	
	--import mux
--	component ALU is
--		port (
--			
--		);
--	end component ALU;
	
begin

	-- Latching Logic Assignments
	process(reset_n, clk, ALU_op)
	begin
	if reset_n = '0' then
		--maybe reset an ALU result register?
		--RF <= (others => (others => '0'));
	elsif clk'event and clk = '1' then
		
	end if; -- clock
	end process;
		
end behavioral;