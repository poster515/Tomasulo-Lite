
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--import RF entity
entity ALU_top_tb is
end ALU_top_tb;

architecture test of ALU_top_tb is
--import ALU
component ALU_top
  port(
    --Input data and clock
		clk 					: in std_logic;
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
end component;

--time delta for waiting between test inputs
constant TIME_DELTA : time := 10 ns;

-- test signals here, map identically to EUT
signal RF_data_in_1, RF_data_in_2 	   : std_logic_vector(15 downto 0); --ALU data inputs
signal WB_data, MEM_data, MEM_address : std_logic_vector(15 downto 0) := "0000000000000000";
signal value_immediate                : std_logic_vector(15 downto 0);
signal B_bus_out1_en, B_bus_out2_en   : std_logic := '0';
signal C_bus_out1_en, C_bus_out2_en   : std_logic := '0';
signal clk, reset_n, carry_in         : std_logic := '0'; -- initialize to 0;
signal ALU_op, ALU_SR                 : std_logic_vector(3 downto 0) := "0000";	--controls ALU function
signal ALU_inst_sel, ALU_d2_mux_sel   : std_logic_vector(1 downto 0) := "00";	--sub function
signal B_bus, C_bus                   : std_logic_vector(15 downto 0) := "ZZZZZZZZZZZZZZZZ";

  begin
    
    dut : entity work.ALU_top
      port map(
        --Input data and clock
		    clk 					=> clk,
		    RF_data_in_1    => RF_data_in_1,
		    RF_data_in_2    =>	RF_data_in_2,
      		WB_data			  	   => WB_data,
		    MEM_data			     => MEM_data,
      		MEM_address		   => MEM_address,
      		value_immediate	=> value_immediate,
 		    
 		    --Control signals
      		reset_n					    => reset_n,
      		ALU_op				      => ALU_op,
      		ALU_inst_sel			 => ALU_inst_sel,
      		ALU_d2_mux_sel		=> ALU_d2_mux_sel,
      		B_bus_out1_en   => B_bus_out1_en, 
      		C_bus_out1_en		 => C_bus_out1_en,
      		B_bus_out2_en   => B_bus_out2_en, 
      		C_bus_out2_en		 =>	C_bus_out2_en,								 
												 
      		--Outputs
      		ALU_SR  => ALU_SR,
      		B_bus   => B_bus, 
      		C_bus		 => C_bus
      );
      
    clk <=  '1' after TIME_DELTA / 2 when clk = '0' else
            '0' after TIME_DELTA / 2 when clk = '1'; 
        
    simulation : process
    begin
      --initialize all registers, and wait a few clocks
      reset_n <= '0';
      carry_in <= '0';
      value_immediate <= "0000000000000000";
      RF_data_in_1 <= "0000000000000000";
      RF_data_in_2 <= "0000000000000000";
      ALU_op <= "0000";
      ALU_inst_sel <= "00";
      
      wait for TIME_DELTA * 2;
      
      reset_n <= '1';
      
      wait for TIME_DELTA;
      
      -- Add
      ALU_op    <= "0000";
      ALU_inst_sel  <= "00";
      RF_data_in_1  <= "0000000000000001";
      RF_data_in_2  <= "0000000000001111";
      wait for TIME_DELTA;
      
      -- Add Immediate
      ALU_d2_mux_sel <= "01";
      value_immediate <= "0000000000000010";
      ALU_op    <= "0000";
      ALU_inst_sel  <= "10"; --
      RF_data_in_1  <= "0000000000000001";
      RF_data_in_2  <= "0000000000001111";
      
      --enable previous result on B bus
      B_bus_out1_en <= '1';
      wait for TIME_DELTA;
      
      -- Subtract
      ALU_d2_mux_sel <= "11";
      ALU_op    <= "0001";
      ALU_inst_sel  <= "00";
      RF_data_in_1  <= "0000000000000001";
      RF_data_in_2  <= "0000000000001111";
      
      --enable previous result on C bus
      B_bus_out1_en <= '0';
      C_bus_out1_en <= '1';
      wait for TIME_DELTA;
      
      -- Subtract Immediate
      value_immediate <= "0000000000000010";
      ALU_op    <= "0001";
      ALU_inst_sel  <= "10"; --
      RF_data_in_1  <= "0000000000000001";
      RF_data_in_2  <= "0000000000001111";
      
      --enable previous result on C bus
      B_bus_out1_en <= '1';
      C_bus_out1_en <= '0';
      wait for TIME_DELTA;
      
      -- Multiply
      ALU_op    <= "0010";
      ALU_inst_sel  <= "00";
      RF_data_in_1  <= "0000000000000010";
      RF_data_in_2  <= "0000000000001111";
      
      --enable previous result on C bus
      B_bus_out1_en <= '1';
      C_bus_out1_en <= '0';
      wait for TIME_DELTA;
      
      -- Multiply
      ALU_op    <= "0010";
      ALU_inst_sel  <= "00";
      RF_data_in_1  <= "0000000000000010";
      RF_data_in_2  <= "0000000010000000";
      
      --enable previous result on C bus
      B_bus_out1_en <= '1';
      C_bus_out1_en <= '0';
      wait for TIME_DELTA;
      
      -- Mult Immediate -- 
      ALU_op    <= "0010";
      ALU_inst_sel  <= "10"; 
      RF_data_in_1  <= "0000000000000010";
      value_immediate <= "0000000000000101";
      
      --enable previous result on C bus
      B_bus_out1_en <= '1';
      C_bus_out1_en <= '0';
      wait for TIME_DELTA;
      
      -- Divide
      ALU_op    <= "0011";
      ALU_inst_sel  <= "00";
      RF_data_in_1  <= "0000000010000000";
      RF_data_in_2  <= "0000000000000010";
      
      --enable previous result on C bus
      B_bus_out1_en <= '1';
      C_bus_out1_en <= '0';
      wait for TIME_DELTA;
      
      -- Divide
      ALU_op    <= "0011";
      ALU_inst_sel  <= "00";
      RF_data_in_1  <= "0000000010000000";
      RF_data_in_2  <= "0000000000011111";
      
      --enable previous result on C bus
      B_bus_out1_en <= '0';
      C_bus_out1_en <= '1';
      wait for TIME_DELTA;
      
      -- Divide Immediate -- 
      ALU_op    <= "0011";
      ALU_inst_sel  <= "10"; 
      RF_data_in_1  <= "0000000000001010";
      value_immediate <= "0000000000000010";
      
      --enable previous result on C bus
      B_bus_out1_en <= '0';
      C_bus_out1_en <= '1';
      wait for TIME_DELTA;
      
      -- AND
      ALU_op    <= "0100";
      ALU_inst_sel  <= "00";
      RF_data_in_1  <= "0000000011111000";
      RF_data_in_2  <= "0000000000011111";
      
      --enable previous result on C bus
      B_bus_out1_en <= '1';
      C_bus_out1_en <= '0';
      wait for TIME_DELTA;
      
      -- OR --13 clock cycles total
      ALU_op    <= "0100";
      ALU_inst_sel  <= "01";
      RF_data_in_1  <= "0000000011111000";
      RF_data_in_2  <= "0000000000011111";
      
      --enable previous result on C bus
      B_bus_out1_en <= '0';
      C_bus_out1_en <= '1';
      wait for TIME_DELTA;
      
      -- XOR
      ALU_op    <= "0100";
      ALU_inst_sel  <= "10";
      RF_data_in_1  <= "0000000011111000";
      RF_data_in_2  <= "0000000000011111";
      
      --enable previous result on C bus
      B_bus_out1_en <= '1';
      C_bus_out1_en <= '0';
      wait for TIME_DELTA;
      
      -- AND -- 15 clock cycles total
      ALU_op    <= "0100";
      ALU_inst_sel  <= "11";
      RF_data_in_1  <= "0000000011111000";
      RF_data_in_2  <= "0000000000011111";
      
      --enable previous result on C bus
      B_bus_out1_en <= '1';
      C_bus_out1_en <= '0';
      wait for TIME_DELTA;
      
      -- Rotate (left) -- 
      ALU_op    <= "0101";
      ALU_inst_sel  <= "00"; --don't use carry
      RF_data_in_1  <= "0000000000000001";
      value_immediate <= "0000000000000111";
      
      --enable previous result on C bus
      B_bus_out1_en <= '0';
      C_bus_out1_en <= '1';
      wait for TIME_DELTA;
      
      -- Rotate with Carry (right) -- 
      ALU_op    <= "0101";
      ALU_inst_sel  <= "11"; 
      RF_data_in_1  <= "0000000000000001";
      carry_in <= '1';
      value_immediate <= "0000000000000011";
      
       --enable previous result on C bus
      B_bus_out1_en <= '1';
      C_bus_out1_en <= '0';
      wait for TIME_DELTA;
      
      -- Shift Logical (right)-- 
      ALU_op    <= "0110";
      ALU_inst_sel  <= "01"; 
      RF_data_in_1  <= "1111000000000000";
      carry_in <= '1';
      
       --enable previous result on C bus
      B_bus_out1_en <= '0';
      C_bus_out1_en <= '1';
      wait for TIME_DELTA;
      
      -- Shift Arithmetic (left)-- 
      ALU_op    <= "0111";
      ALU_inst_sel  <= "00"; 
      RF_data_in_1  <= "1000000000001111";
      value_immediate <= "0000000000000101";
      
       --enable previous result on C bus
      B_bus_out1_en <= '0';
      C_bus_out1_en <= '1';
      wait for TIME_DELTA;
      
      -- Shift Logical (left)-- 
      ALU_op    <= "0110";
      ALU_inst_sel  <= "00"; 
      RF_data_in_1  <= "0000000000001111";
      carry_in <= '1';
      
       --enable previous result on C bus
      B_bus_out1_en <= '1';
      C_bus_out1_en <= '0';
      wait for TIME_DELTA;
      
      -- Shift Arithmetic (right)-- 21 clock cycles
      ALU_op    <= "0111";
      ALU_inst_sel  <= "01"; 
      RF_data_in_1  <= "1000000000000001";
      value_immediate <= "0000000000000101";
      
       --enable previous result on C bus
      B_bus_out1_en <= '0';
      C_bus_out1_en <= '1';
      wait for TIME_DELTA;
      
       --enable previous result on C bus
      B_bus_out1_en <= '0';
      C_bus_out1_en <= '1';
      
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



