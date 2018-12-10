library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity ALU is
  port (
    --Input data and clock
	 clk 					: in std_logic;	
	 carry_in			: in std_logic; --carry in bit from the Control Unit Status Register
	 data_in_1 			: in std_logic_vector(15 downto 0); --data from RF data out 1
	 data_in_2 			: in std_logic_vector(15 downto 0); --data from RF data out 2
	 value_immediate			: in std_logic_vector(15 downto 0);
	 
	 --Control signals
	 reset_n					: in std_logic; --all registers reset to 0 when this goes low
	 ALU_op					: in std_logic_vector(3 downto 0); --dictates ALU operation (i.e., OpCode)
	 ALU_inst_sel			: in std_logic_vector(1 downto 0); --dictates what sub-function to execute
	 
    --Outputs
    ALU_out_1   	: out std_logic_vector(15 downto 0); --output for almost all logic functions
	 ALU_out_2   	: out std_logic_vector(15 downto 0); --use for MULT MSBs and DIV remainder
    ALU_status 	: out std_logic_vector(3 downto 0) --provides | Zero (Z) | Overflow (V) | Negative (N) | Carry (C) |
    );
end ALU;

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
--IO			R/W input/outputs		1101  
--(unused)	N/A						1110
--(unused)	N/A						1111

architecture behavioral of ALU is
	
	--import add_sub unit
	component add_sub is
		port (
			add_sub		: IN STD_LOGIC ;
			dataa			: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			datab			: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			cout			: OUT STD_LOGIC ;
			overflow		: OUT STD_LOGIC ;
			result		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
		);
	end component add_sub;
	
	--import multiplier
	component multiplier is
		port
			(
				dataa		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
				datab		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
				result	: OUT STD_LOGIC_VECTOR (31 DOWNTO 0)
			);
	end component multiplier;
	
	--import divider	
	component divider is
		port
			(
				denom		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
				numer		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
				quotient	: OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
				remain	: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
			);
	end component divider;
	
	--import logic unit
	component ALU_logic is
		port
			(
				A_in 			: in std_logic_vector(15 downto 0);
				B_in 			: in std_logic_vector(15 downto 0);
				logic_func 	: in std_logic_vector(1 downto 0);
				result 		: inout std_logic_vector(15 downto 0);
				zero, negative	: out std_logic
			);
	end component ALU_logic;
	
	--import logic unit
	component rotate is
		port
			(
				data			: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
				direction	: IN STD_LOGIC ;
				distance		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
				result		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
			);
	end component rotate;
	
	component rotate_c is
		port
		(
			data			: IN STD_LOGIC_VECTOR (16 DOWNTO 0);
			direction	: IN STD_LOGIC ;
			distance		: IN STD_LOGIC_VECTOR (4 DOWNTO 0);
			result		: OUT STD_LOGIC_VECTOR (16 DOWNTO 0)
		);
	end component rotate_c;
	
	component shift_logic is
		port 
		(
			data			: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			direction	: IN STD_LOGIC ;
			distance		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
			overflow		: OUT STD_LOGIC ;
			result		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
		);
	end component shift_logic;
	
	component shift_arith IS
		port
		(
			data			: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			direction	: IN STD_LOGIC ;
			distance		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
			overflow		: OUT STD_LOGIC ;
			result		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
		);
	end component shift_arith;
	
	signal ALU_data_in_2	: std_logic_vector(15 downto 0);	-- selected from either data_in_2 or immediate value
																			--used for ADDI, SUBI, MULTI, DIVI
	--Add/Sub signal section
	signal add_sub_c, add_sub_v 	: std_logic;	
	signal add_sub_result			: std_logic_vector(15 downto 0);
	signal add_sub_sel				: std_logic; -- selects whether to perform addition or subtraction
	
	--Multiplier signal section
	signal mult_result				: std_logic_vector(31 downto 0);
	alias  mult_MSB is mult_result(31 downto 16);
	alias  mult_LSB is mult_result(15 downto 0);
	
	--Divider signal section
	signal divide_result, divide_remainder	: std_logic_vector(15 downto 0);
	
	--Logic unit signals
	signal logic_result				: std_logic_vector(15 downto 0);
	signal logic_neg, logic_zero	: std_logic;
	
	--Rotate unit signals
	signal rotate_result				: std_logic_vector(15 downto 0);
	signal rotate_c_result			: std_logic_vector(16 downto 0);
	signal rotate_c_in				: std_logic_vector(16 downto 0);
	
	--Shift logical unit signals
	signal shift_logic_overflow	: std_logic;
	signal shift_logic_result		: std_logic_vector(15 downto 0);
	
	--Shift arithmetic unit signals
	signal shift_arith_overflow	: std_logic;
	signal shift_arith_result		: std_logic_vector(15 downto 0);
	
	--function prototype
	function zero_check (temp_result : in std_logic_vector(15 downto 0))
		return std_logic is variable temp_zero : std_logic := '0';
			begin
				for i in 0 to temp_result'length-1 loop
				temp_zero := temp_zero or temp_result(i);
				end loop;
				return not(temp_zero);
			  
	end function zero_check;

	
begin
	-- Adder/Subtracter
	add_sub_inst	: add_sub
	port map (
		add_sub		=>	add_sub_sel, -- "0000"=A "0001"=S, 1=A, 0=S
		dataa			=> data_in_1,
		datab			=> ALU_data_in_2, --DEBUG DEBUG DEBUG SHOULD BE ALU_DATA_IN_2
		cout			=> add_sub_c,
		overflow		=> add_sub_v,
		result		=> add_sub_result
	);
	
	mult_inst 	: multiplier
	port map (
		dataa		=> data_in_1,
		datab		=> ALU_data_in_2,
		result	=> mult_result
	);
	
	divider_inst	: divider
	port map (
		denom		=> ALU_data_in_2,
		numer		=> data_in_1,
		quotient	=> divide_result,
		remain	=> divide_remainder
	);
	
	logic_unit_inst	: ALU_logic
	port map (
		A_in 			=> data_in_1,
		B_in 			=> data_in_2,
		logic_func 	=> ALU_inst_sel,
		result 		=> logic_result,
		zero			=> logic_zero,
		negative		=> logic_neg
	);	
	
	rotate_inst	: rotate
	port map (
			data			=> data_in_1,
			direction	=> ALU_inst_sel(0), --'0' = left, '1' = right
			distance		=> value_immediate(3 downto 0),
			result		=> rotate_result
		);
		
	rotate_c_inst	: rotate_c
	port map (
			data			=> rotate_c_in, -- carry included at MSB
			direction	=> ALU_inst_sel(0), --'0' = left, '1' = right
			distance		=> value_immediate(4 downto 0),
			result		=> rotate_c_result
		);
	
	shift_logic_inst	: shift_logic 
		port map (
			data			=> data_in_1,
			direction	=> ALU_inst_sel(0), --'0' = left, '1' = right
			distance		=> value_immediate(3 downto 0),
			overflow		=> shift_logic_overflow,
			result		=> shift_logic_result
		);
	
	shift_arith_unit	: shift_arith
		port map (
			data			=> data_in_1,
			direction	=> ALU_inst_sel(0), --'0' = left, '1' = right
			distance		=> value_immediate(3 downto 0),
			overflow		=> shift_arith_overflow,
			result		=> shift_arith_result
		);

	--required signal for add/subtract unit, based on OpCode alone
	add_sub_sel <= not(ALU_op(3)) and not(ALU_op(2)) and not(ALU_op(1)) and not(ALU_op(0));
	
	--this process will assign the immediate value as the input to ALU input 2.
	process(ALU_inst_sel, data_in_2, value_immediate)
	begin
		if (ALU_inst_sel(1) = '0') then
			ALU_data_in_2 <= data_in_2;
		else
			ALU_data_in_2 <= value_immediate;
		end if;
	end process;
	
	rotate_c_in <= carry_in & data_in_1;
	
	-- Latching Logic Assignments
	process(reset_n, clk, ALU_op)
	begin
	if reset_n = '0' then
		--maybe reset an ALU result register?
		--RF <= (others => (others => '0'));
	elsif clk'event and clk = '1' then
	
		--STATUS REGISTER: | Zero (Z) | Overflow (V) | Negative (N) | Carry (C) |
		
		--ADD, ADDI, SUB, SUBI
		if ALU_op = "0000" or ALU_op = "0001" then 
			ALU_out_1 	<= add_sub_result;
			ALU_status	<= zero_check(add_sub_result) & add_sub_v & add_sub_result(15) & add_sub_c;
			
		--MUL
		elsif ALU_op = "0010" then
			ALU_out_1 	<= mult_LSB;
			ALU_out_2	<= mult_MSB;
			ALU_status	<= (zero_check(mult_LSB) and zero_check(mult_MSB))
									& '0' & mult_result(31) & '0';	
		--DIV
		elsif ALU_op = "0011" then
			ALU_out_1 	<= divide_result;
			ALU_out_2	<= divide_remainder;
			ALU_status	<= (zero_check(divide_result) and zero_check(divide_remainder)) & '0' & divide_result(15) & '0';
			
		--LOGIC
		elsif ALU_op = "0100" then
			ALU_out_1 	<= logic_result;
			ALU_status	<= logic_zero & '0' & logic_neg & '0';
			
		--ROTATE
		elsif ALU_op = "0101" and ALU_inst_sel(1) = '0' then --only non-carry rotate
			ALU_out_1	<= rotate_result;
			ALU_status	<= zero_check(rotate_result) & '0' & rotate_result(15) & '0';
			
		--ROTATE WITH CARRY
		elsif ALU_op = "0101" and ALU_inst_sel(1) = '1' then --carry included in rotate
			ALU_out_1	<= rotate_c_result(15 downto 0);
			ALU_status	<= zero_check(rotate_c_result(15 downto 0)) & '0' & rotate_c_result(15) & '0';
			
		--SHIFT LOGICAL
		elsif ALU_op = "0110" then
			ALU_out_1	<= shift_logic_result;
			ALU_status	<= zero_check(shift_logic_result) & shift_logic_overflow & shift_logic_result(15) & '0';
			
		--SHIFT ARITHMETIC
		elsif ALU_op = "0111" then
			ALU_out_1	<= shift_arith_result;
			ALU_status	<= zero_check(shift_arith_result) & shift_arith_overflow & shift_arith_result(15) & '0';			
			
		--LD, ST, BNEZ, BNE, JMP --just forward input data
		else
			ALU_out_1 	<= data_in_1;
			ALU_out_2 	<= data_in_2;
--			ALU_status 	<= "XXXX";
			
		end if; --ALU_op
	end if; -- clock
	end process;
		
end behavioral;