library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--import RF entity
entity ALU_tb is
end ALU_tb;

architecture test of ALU_tb is
--import ALU
component ALU
  port(
    --Input data and clock
    clk 					     : in std_logic;	
    carry_in			   : in std_logic; --carry in bit from the Control Unit Status Register
    data_in_1 			 : in std_logic_vector(15 downto 0); --data from RF data out 1
    data_in_2 			 : in std_logic_vector(15 downto 0); --data from RF data out 2

    --Control signals
    reset_n	      : in std_logic; --all registers reset to 0 when this goes low
    ALU_op					   : in std_logic_vector(3 downto 0); --dictates ALU operation (i.e., OpCode)
    ALU_inst_sel  : in std_logic_vector(1 downto 0); --dictates what sub-function to execute
	 
    --Outputs
    ALU_out_1   	 : out std_logic_vector(15 downto 0); --output for almost all logic functions
	  ALU_out_2     : out std_logic_vector(15 downto 0); --use for MULT MSBs and DIV remainder
    ALU_status    : out std_logic_vector(3 downto 0) --provides | Zero (Z) | Overflow (V) | Negative (N) | Carry (C) |
    );
end component;

--time delta for waiting between test inputs
constant TIME_DELTA : time := 10 ns;

-- test signals here, map identically to EUT
signal data_in_1, data_in_2 	 : std_logic_vector(15 downto 0); --ALU data inputs
signal ALU_out_1, ALU_out_2 	 : std_logic_vector(15 downto 0); --ALU data inputs
signal carry_in               : std_logic := '0'; -- initialize to 0;
signal ALU_op, ALU_status     : std_logic_vector(3 downto 0);	--controls ALU function
signal ALU_inst_sel	          : std_logic_vector(1 downto 0);	--sub function

  begin
    
    dut : entity work.ALU
      port map(
        --Input data and clock
	      carry_in  => carry_in,
	      data_in_1 => data_in_1,
	      data_in_2 => data_in_2, 
	 
	      --Control signals
	      ALU_op	       => ALU_op,
	      ALU_inst_sel  => ALU_inst_sel,
	 
        --Outputs
        ALU_out_1   => ALU_out_1,
        ALU_out_2   => ALU_out_2, 
        ALU_status  => ALU_status
      );
      
    simulation : process
    begin
      --initialize all registers, and wait a few clocks
      carry_in <= '0';
      data_in_1 <= "0000000000000000";
      data_in_2 <= "0000000000000000";
      ALU_op <= "0000";
      ALU_inst_sel <= "00";
      wait for TIME_DELTA * 2;
      
      -- Add
      ALU_op    <= "0000";
      ALU_inst_sel  <= "00";
      data_in_1  <= "0000000000000001";
      data_in_2  <= "0000000000001111";
      wait for TIME_DELTA;
      
      -- Add Immediate
      ALU_op    <= "0000";
      ALU_inst_sel  <= "10"; --
      data_in_1  <= "0000000000000001";
      data_in_2  <= "0000000000001111";
      wait for TIME_DELTA;
      
      -- Subtract
      ALU_op    <= "0001";
      ALU_inst_sel  <= "00";
      data_in_1  <= "0000000000000001";
      data_in_2  <= "0000000000001111";
      wait for TIME_DELTA;
      
      -- Subtract Immediate
      ALU_op    <= "0001";
      ALU_inst_sel  <= "10"; --
      data_in_1  <= "0000000000000001";
      data_in_2  <= "0000000000001111";
      wait for TIME_DELTA;
      
      -- Multiply
      ALU_op    <= "0010";
      ALU_inst_sel  <= "00";
      data_in_1  <= "0000000000000010";
      data_in_2  <= "0000000000001111";
      wait for TIME_DELTA;
      
      -- Multiply
      ALU_op    <= "0010";
      ALU_inst_sel  <= "00";
      data_in_1  <= "0000000000000010";
      data_in_2  <= "0000000010000000";
      wait for TIME_DELTA;
      
      -- Mult Immediate -- 
      ALU_op    <= "0010";
      ALU_inst_sel  <= "10"; 
      data_in_1  <= "0000000000000010";
      wait for TIME_DELTA;
      
      -- Divide
      ALU_op    <= "0011";
      ALU_inst_sel  <= "00";
      data_in_1  <= "0000000010000000";
      data_in_2  <= "0000000000000010";
      wait for TIME_DELTA;
      
      -- Divide
      ALU_op    <= "0011";
      ALU_inst_sel  <= "00";
      data_in_1  <= "0000000010000000";
      data_in_2  <= "0000000000011111";
      wait for TIME_DELTA;
      
      -- Divide Immediate -- 
      ALU_op    <= "0011";
      ALU_inst_sel  <= "10"; 
      data_in_1  <= "0000000000001010";
      wait for TIME_DELTA;
      
      -- AND
      ALU_op    <= "0100";
      ALU_inst_sel  <= "00";
      data_in_1  <= "0000000011111000";
      data_in_2  <= "0000000000011111";
      wait for TIME_DELTA;
      
      -- OR --13 clock cycles total
      ALU_op    <= "0100";
      ALU_inst_sel  <= "01";
      data_in_1  <= "0000000011111000";
      data_in_2  <= "0000000000011111";
      wait for TIME_DELTA;
      
      -- XOR
      ALU_op    <= "0100";
      ALU_inst_sel  <= "10";
      data_in_1  <= "0000000011111000";
      data_in_2  <= "0000000000011111";
      wait for TIME_DELTA;
      
      -- AND -- 15 clock cycles total
      ALU_op    <= "0100";
      ALU_inst_sel  <= "11";
      data_in_1  <= "0000000011111000";
      data_in_2  <= "0000000000011111";
      wait for TIME_DELTA;
      
      -- Rotate (left) -- 
      ALU_op    <= "0101";
      ALU_inst_sel  <= "00"; --don't use carry
      data_in_1  <= "0000000000000001";
      wait for TIME_DELTA;
      
      -- Rotate with Carry (right) -- 
      ALU_op    <= "0101";
      ALU_inst_sel  <= "11"; 
      data_in_1  <= "0000000000000001";
      carry_in <= '1';
      wait for TIME_DELTA;
      
      -- Shift Logical (right)-- 
      ALU_op    <= "0110";
      ALU_inst_sel  <= "01"; 
      data_in_1  <= "1111000000000000";
      carry_in <= '1';
      wait for TIME_DELTA;
      
      -- Shift Arithmetic (left)-- 
      ALU_op    <= "0111";
      ALU_inst_sel  <= "00"; 
      data_in_1  <= "1000000000001111";
      wait for TIME_DELTA;
      
      -- Shift Logical (left)-- 
      ALU_op    <= "0110";
      ALU_inst_sel  <= "00"; 
      data_in_1  <= "0000000000001111";
      carry_in <= '1';
      wait for TIME_DELTA;
      
      -- Shift Arithmetic (right)-- 21 clock cycles
      ALU_op    <= "0111";
      ALU_inst_sel  <= "01"; 
      data_in_1  <= "1000000000000001";
      wait for TIME_DELTA;
      
      --testing outputs with non-ALU opcodes
      ALU_op    <= "1000";
      wait for TIME_DELTA;
      
      --testing outputs with non-ALU opcodes
      ALU_op    <= "1010";
      wait for TIME_DELTA;
      
      --testing outputs with non-ALU opcodes
      ALU_op    <= "1100";
      wait for TIME_DELTA;
      
    end process simulation;

end architecture test;


