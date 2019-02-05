library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity ALU is
  port (
    --Input data 	
	 carry_in			: in std_logic; --carry in bit from the Control Unit Status Register
	 data_in_1 			: in std_logic_vector(15 downto 0); --
	 data_in_2 			: in std_logic_vector(15 downto 0); --
	 
	 --Control signals
	 ALU_op				: in std_logic_vector(3 downto 0); --dictates ALU operation (i.e., OpCode)
	 ALU_inst_sel		: in std_logic_vector(1 downto 0); --dictates what sub-function to execute
	 
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
--SFTL		Shift logical			0110	--shift value is from another register
--SFTA		Shift arithmetic		0111	--shift value is from another register
--LD/ST		Load/Store from DM	1000  --compute address 
--JMP			Jump						1001
--BNE(Z)		Branch if not zero	1010
--IO			R/W input/outputs		1011
--LOGI		Logic w immediate		1100
--(unused)	N/A						1101
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
	end component;
	
	component mux_8_width_4 is
		PORT
		(
			data0x		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
			data1x		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
			data2x		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
			data3x		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
			data4x		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
			data5x		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
			data6x		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
			data7x		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
			sel			: IN STD_LOGIC_VECTOR (2 DOWNTO 0);
			result		: OUT STD_LOGIC_VECTOR (3 DOWNTO 0)
		);
	end component;
	
	component mux_2_new IS
		PORT
		(
			data0x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			data1x		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			sel			: IN STD_LOGIC ;
			result		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
		);
	END component;
	
	component mux_2_width_17 IS
		PORT
		(
			data0x		: IN STD_LOGIC_VECTOR (16 DOWNTO 0);
			data1x		: IN STD_LOGIC_VECTOR (16 DOWNTO 0);
			sel			: IN STD_LOGIC ;
			result		: OUT STD_LOGIC_VECTOR (16 DOWNTO 0)
		);
	END component;
	
	--Add/Sub signal section
	signal add_sub_c, add_sub_v 	: std_logic;	
	signal add_sub_result			: std_logic_vector(15 downto 0);
	signal add_sub_sel				: std_logic; -- selects whether to perform addition or subtraction
	signal add_SR, sub_SR			: std_logic_vector(3 downto 0);
	
	--Multiplier signal section
	signal mult_result				: std_logic_vector(31 downto 0);
	alias  mult_MSB is mult_result(31 downto 16);
	alias  mult_LSB is mult_result(15 downto 0);
	signal mult_SR						: std_logic_vector(3 downto 0);
	
	--Divider signal section
	signal divide_result, divide_remainder	: std_logic_vector(15 downto 0);
	signal div_SR									: std_logic_vector(3 downto 0);
	
	--Logic unit signals
	signal logic_result				: std_logic_vector(15 downto 0);
	signal logic_neg, logic_zero	: std_logic;
	signal log_SR						: std_logic_vector(3 downto 0);
	
	--Rotate unit signals
	signal rotate_result				: std_logic_vector(15 downto 0);
	signal rotate_result_final		: std_logic_vector(15 downto 0); --signal fed from both normal and carry results
	signal rotate_c_result			: std_logic_vector(16 downto 0);
	signal rotate_c_in				: std_logic_vector(16 downto 0);
	--signal rotate_final_sel			: std_logic; --selects final rotate result for ALU_out_1
	signal rot_SR						: std_logic_vector(3 downto 0);
	signal rotate_in_left, rotate_in_right : std_logic_vector(16 downto 0);
	
	--Shift logical unit signals
	signal shift_logic_overflow	: std_logic;
	signal shift_logic_result		: std_logic_vector(15 downto 0);
	signal sftl_SR						: std_logic_vector(3 downto 0);
	
	--Shift arithmetic unit signals
	signal shift_arith_overflow	: std_logic;
	signal shift_arith_result		: std_logic_vector(15 downto 0);
	signal sfta_SR						: std_logic_vector(3 downto 0);
	
	--function prototype
	function zero_check (temp_result : in std_logic_vector(15 downto 0))
		return std_logic is 
		
		variable temp_zero : std_logic := '0';
	begin
		for i in 0 to 15 loop
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
		datab			=> data_in_2, --
		cout			=> add_sub_c,
		overflow		=> add_sub_v,
		result		=> add_sub_result
	);
	
	mult_inst 	: multiplier
	port map (
		dataa		=> data_in_1,
		datab		=> data_in_2,
		result	=> mult_result
	);
	
	divider_inst	: divider
	port map (
		denom		=> data_in_2,
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
			distance		=> data_in_2(3 downto 0),
			result		=> rotate_result
		);
		
	rotate_c_inst	: rotate_c
	port map (
			data			=> rotate_c_in,
			direction	=> ALU_inst_sel(0), --'0' = left, '1' = right
			distance		=> data_in_2(4 downto 0),
			result		=> rotate_c_result
		);
	
	shift_logic_inst	: shift_logic 
		port map (
			data			=> data_in_1,
			direction	=> ALU_inst_sel(0), --'0' = left, '1' = right
			distance		=> data_in_2(3 downto 0),
			overflow		=> shift_logic_overflow,
			result		=> shift_logic_result
		);
	
	shift_arith_unit	: shift_arith
		port map (
			data			=> data_in_1,
			direction	=> ALU_inst_sel(0), --'0' = left, '1' = right
			distance		=> data_in_2(3 downto 0),
			overflow		=> shift_arith_overflow,
			result		=> shift_arith_result
		);
		
	ALU_out_1_mux : mux_8_new
		PORT MAP
		(
			data0x		=> add_sub_result,
			data1x		=> add_sub_result,
			data2x		=> mult_LSB,
			data3x		=> divide_result,
			data4x		=> logic_result,
			data5x		=> rotate_result_final,
			data6x		=> shift_logic_result,
			data7x		=> shift_arith_result,
			sel			=> ALU_op(2 downto 0),
			result		=> ALU_out_1
		);
		
	ALU_out_2_mux : mux_8_new
		PORT MAP
		(
			data0x		=> "0000000000000000",
			data1x		=> "0000000000000000",
			data2x		=> mult_MSB,
			data3x		=> divide_remainder,
			data4x		=> "0000000000000000",
			data5x		=> "0000000000000000",
			data6x		=> "0000000000000000",
			data7x		=> "0000000000000000",
			sel			=> ALU_op(2 downto 0),
			result		=> ALU_out_2
		);
		
		--STATUS REGISTER: | Zero (Z) | Overflow (V) | Negative (N) | Carry (C) |
		status_out_2_mux : mux_8_width_4
		PORT MAP
		(
			data0x		=> add_SR, 	--zero_check(add_sub_result) & add_sub_v & add_sub_result(15) & add_sub_c,
			data1x		=> sub_SR, 	--zero_check(add_sub_result) & add_sub_v & add_sub_result(15) & add_sub_c,
			data2x		=> mult_SR,	--(zero_check(mult_LSB) and zero_check(mult_MSB)) & '0' & mult_result(31) & '0',
			data3x		=> div_SR,	--(zero_check(divide_result) and zero_check(divide_remainder)) & '0' & divide_result(15) & '0',
			data4x		=> log_SR,	--logic_zero & '0' & logic_neg & '0',
			data5x		=> rot_SR,	--zero_check(rotate_result) & '0' & rotate_result(15) & '0',
			data6x		=> sftl_SR,	--zero_check(shift_logic_result) & shift_logic_overflow & shift_logic_result(15) & '0',
			data7x		=> sfta_SR,	--zero_check(shift_arith_result) & shift_arith_overflow & shift_arith_result(15) & '0',
			sel			=> ALU_op(2 downto 0),
			result		=> ALU_status
		);
		
		rotate_final : mux_2_new 
		PORT MAP
		(
			data0x		=> rotate_result,
			data1x		=> rotate_c_result(15 downto 0),
			sel			=> ALU_inst_sel(1), --rotate_final_sel,
			result		=> rotate_result_final
		);
		
		rotate_c_in_mux : mux_2_width_17
		PORT MAP
		(
			data0x		=> rotate_in_right,
			data1x		=> rotate_in_left,
			sel			=> ALU_inst_sel(0),
			result		=> rotate_c_in
		);
		
	process(add_sub_v, add_sub_c, mult_result, shift_logic_overflow, shift_arith_overflow, add_sub_result, mult_LSB, mult_MSB, 
				divide_result, divide_remainder, logic_zero, logic_neg, rotate_result, shift_logic_result, shift_arith_result, data_in_1, carry_in)
	begin
	
		--Status register assignments
		add_SR 	<= zero_check(add_sub_result) & add_sub_v & add_sub_result(15) & add_sub_c;
		sub_SR 	<= zero_check(add_sub_result) & add_sub_v & add_sub_result(15) & add_sub_c;
		mult_SR 	<= (zero_check(mult_LSB) and zero_check(mult_MSB)) & '0' & mult_result(31) & '0';
		div_SR 	<= (zero_check(divide_result) and zero_check(divide_remainder)) & '0' & divide_result(15) & '0';
		log_SR 	<= logic_zero & '0' & logic_neg & '0';
		rot_SR 	<= zero_check(rotate_result) & '0' & rotate_result(15) & '0';
		sftl_SR 	<= zero_check(shift_logic_result) & shift_logic_overflow & shift_logic_result(15) & '0';
		sfta_SR 	<= zero_check(shift_arith_result) & shift_arith_overflow & shift_arith_result(15) & '0';
		
		--Rotate w carry input assignment
		rotate_in_right 	<= data_in_1 & carry_in;
		rotate_in_left 	<= carry_in & data_in_1;
		
	end process;

	--1 = add (add, load, store), 0 = subtract
	add_sub_sel <= not(ALU_op(2)) and not(ALU_op(1)) and not(ALU_op(0));

	--rotate_final select
	--rotate_final_sel <= not(ALU_op(3)) and ALU_op(2) and not(ALU_op(1)) and ALU_op(0) and not(ALU_inst_sel(1));
		
end behavioral;