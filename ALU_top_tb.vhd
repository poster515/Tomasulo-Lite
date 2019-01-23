
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
		clk 					        : in std_logic;
		RF_in_1, RF_in_2	 : in std_logic_vector(15 downto 0);
		MEM_address			    : in std_logic_vector(15 downto 0); --memory address forwarded directly from LAB
		value_immediate	  : in std_logic_vector(15 downto 0); --Reg2 data field from IW directly from EX
																				--used to forward shift/rotate distance and immediate value for addi & subi

		--Control signals
		reset_n				   : in std_logic; --all registers reset to 0 when this goes low
		ALU_op				    : in std_logic_vector(3 downto 0); 	--dictates ALU operation (i.e., OpCode)
		ALU_inst_sel		: in std_logic_vector(1 downto 0); 	--dictates what sub-function to execute (last two bits of OpCode)
		
		ALU_d2_in_sel	      : in std_logic_vector(1 downto 0); 	--used to control which bus to send to ALU input 2 (from CSAM)
		ALU_d1_in_sel       : in std_logic_vector(1 downto 0); 	--used to control which bus to send to ALU input 1 (from CSAM)
		ALU_out_1_mux 		    : in std_logic_vector(1 downto 0); --used to output results on A, B, or C bus
		ALU_out_2_mux		     : in std_logic_vector(1 downto 0); --used to output results on A, B, or C bus
		ALU_fwd_data_in_en  : in std_logic_vector(1 downto 0); --(CSAM)
		ALU_fwd_data_out_en	: in std_logic; --selects fwd reg to output data onto A, B, or C bus (EX)
		
		--Outputs
		ALU_SR 				: out std_logic_vector(3 downto 0); --provides | Zero (Z) | Overflow (V) | Negative (N) | Carry (C) |
		A_bus, B_bus, C_bus		: inout std_logic_vector(15 downto 0)
    );
end component;

--time delta for waiting between test inputs
constant TIME_DELTA : time := 10 ns;

-- test signals here, map identically to EUT
signal RF_data_in_1, RF_data_in_2	        : std_logic_vector(15 downto 0) := "0000000000000000";
signal MEM_address, value_immediate       : std_logic_vector(15 downto 0) := "0000000000000000";
signal ALU_out_1_mux, ALU_out_2_mux       : std_logic_vector(1 downto 0) := "00";
signal clk, reset_n, ALU_fwd_data_out_en  : std_logic := '0'; -- initialize to 0;
signal ALU_op, ALU_SR                     : std_logic_vector(3 downto 0) := "0000";	--controls ALU function
signal ALU_inst_sel                       : std_logic_vector(1 downto 0) := "00";	
signal ALU_fwd_data_in_en                 : std_logic := '0';
signal ALU_d2_in_sel, ALU_d1_in_sel       : std_logic_vector(1 downto 0) := "00";	--sub function
signal A_bus, B_bus, C_bus                : std_logic_vector(15 downto 0) := "ZZZZZZZZZZZZZZZZ";

  begin
    
    dut : entity work.ALU_top
      port map(
        --Input data and clock
		    clk 					       => clk,
		    RF_in_1        => RF_data_in_1,
		    RF_in_2        => RF_data_in_2,
      		MEM_address		   => MEM_address,
      		value_immediate	=> value_immediate,
 		    
 		    --Control signals
      		reset_n					    => reset_n,
      		ALU_op				      => ALU_op,
      		ALU_inst_sel			 => ALU_inst_sel,
      		
      		ALU_d2_in_sel		 => ALU_d2_in_sel,
      		ALU_d1_in_sel		 => ALU_d1_in_sel,
      		ALU_out_1_mux		 =>	ALU_out_1_mux,		
      		ALU_out_2_mux		 => ALU_out_2_mux,				 
				ALU_fwd_data_in_en   => ALU_fwd_data_in_en,
				ALU_fwd_data_out_en  => ALU_fwd_data_out_en,
												 
      		--Outputs
      		ALU_SR  => ALU_SR,
      		A_bus   => A_bus,
      		B_bus   => B_bus, 
      		C_bus		 => C_bus

      );
      
    clk <=  '1' after TIME_DELTA / 2 when clk = '0' else
            '0' after TIME_DELTA / 2 when clk = '1'; 
        
    simulation : process
    begin
      --initialize all registers, and wait a few clocks
      reset_n <= '0';
      MEM_address     <= "0000000000000000";  
      value_immediate <= "0000000000000000";
      RF_data_in_1 <= "0000000000000000";
      RF_data_in_2 <= "0000000000000000";
      ALU_op <= "0000";
      ALU_inst_sel <= "00";
      
      wait for TIME_DELTA * 2;
      
      reset_n <= '1';
      
      wait for TIME_DELTA;
      
      -- Add
      ALU_op        <= "0000";
      ALU_inst_sel  <= "00";
      ALU_d1_in_sel <= "01";
      ALU_d2_in_sel <= "01";
      RF_data_in_1  <= "0000000000000001";
      RF_data_in_2  <= "0000000000001111";
      ALU_fwd_data_in_en <= '0';
      wait for TIME_DELTA;
      
      -- Add Immediate
      ALU_op        <= "0000";
      ALU_inst_sel  <= "10"; --
      ALU_d1_in_sel <= "01";
      ALU_d2_in_sel <= "10";
      value_immediate <= "0000000000000010";
      RF_data_in_1  <= "0000000000000001";
      RF_data_in_2  <= "0000000000001111";
      
      --enable previous result on B bus
      ALU_out_1_mux <= "10";
      wait for TIME_DELTA;
      
      -- Subtract
      ALU_op        <= "0001";
      ALU_inst_sel  <= "00";
      ALU_d1_in_sel <= "01";
      ALU_d2_in_sel <= "01";
      RF_data_in_1  <= "0000000000000001";
      RF_data_in_2  <= "0000000000001111";
      
      --enable previous result on C bus
      ALU_out_1_mux <= "11";
      wait for TIME_DELTA;
      
      -- Subtract Immediate
      ALU_op        <= "0001";
      ALU_inst_sel  <= "10"; --
      ALU_d1_in_sel <= "01";
      ALU_d2_in_sel <= "10";
      RF_data_in_1  <= "0000000000000001";
      RF_data_in_2  <= "0000000000001111";
      value_immediate <= "0000000000000010";
      
      --enable previous result on C bus
      ALU_out_1_mux <= "11";
      wait for TIME_DELTA;
      
      -- Multiply
      ALU_op        <= "0010";
      ALU_inst_sel  <= "00";
      ALU_d1_in_sel <= "01";
      ALU_d2_in_sel <= "01";
      RF_data_in_1  <= "0000000000000001";
      RF_data_in_2  <= "0000000000001111";
      
      --enable previous result on A bus
      ALU_out_1_mux <= "01";
      wait for TIME_DELTA;
    
      -- Mult Immediate -- 
      ALU_op        <= "0010";
      ALU_inst_sel  <= "01";
      ALU_d1_in_sel <= "01";
      ALU_d2_in_sel <= "10";
      RF_data_in_1  <= "0000000000000001";
      RF_data_in_2  <= "0000000000001111";
      
      --enable previous result on C bus
      ALU_out_1_mux <= "11";
      wait for TIME_DELTA;
      
      -- Divide
      ALU_op        <= "0011";
      ALU_inst_sel  <= "00";
      ALU_d1_in_sel <= "01";
      ALU_d2_in_sel <= "01";
      RF_data_in_1  <= "0000000000000001";
      RF_data_in_2  <= "0000000000001111";
      
      --enable previous result on A bus
      ALU_out_1_mux <= "01";
      wait for TIME_DELTA;
      
      -- Divide Immediate -- 
      ALU_op        <= "0011";
      ALU_inst_sel  <= "01";
      ALU_d1_in_sel <= "01";
      ALU_d2_in_sel <= "10";
      RF_data_in_1  <= "0000000000001000";
      RF_data_in_2  <= "0000000000001111";
      value_immediate <= "0000000000000010";
      
      --enable previous result on B bus
      ALU_out_1_mux <= "10";
      wait for TIME_DELTA;
      
      -- AND
      ALU_op        <= "0100";
      ALU_inst_sel  <= "00";
      ALU_d1_in_sel <= "01";
      ALU_d2_in_sel <= "01";
      RF_data_in_1  <= "0000000000000001";
      RF_data_in_2  <= "0000000000001111";
      
      --enable previous result on C bus
      ALU_out_1_mux <= "11";
      wait for TIME_DELTA;
      
      -- OR 
      ALU_op        <= "0100";
      ALU_inst_sel  <= "01";
      ALU_d1_in_sel <= "01";
      ALU_d2_in_sel <= "01";
      RF_data_in_1  <= "0000000000100001";
      RF_data_in_2  <= "0000000000001111";
      
      --enable previous result on A bus
      ALU_out_1_mux <= "01";
      wait for TIME_DELTA;
      
      -- XOR
      ALU_op        <= "0100";
      ALU_inst_sel  <= "10";
      ALU_d1_in_sel <= "01";
      ALU_d2_in_sel <= "01";
      RF_data_in_1  <= "0000000000001001";
      RF_data_in_2  <= "0000000000001111";
      
      --enable previous result on B bus
      ALU_out_1_mux <= "10";
      wait for TIME_DELTA;
      
      -- NOT 
      ALU_op        <= "0100";
      ALU_inst_sel  <= "11";
      ALU_d1_in_sel <= "01";
      ALU_d2_in_sel <= "01";
      RF_data_in_1  <= "0000000000000001";
      RF_data_in_2  <= "0000000000001111";
      
      --enable previous result on A bus
      ALU_out_1_mux <= "01";
      wait for TIME_DELTA;
      
      -- Rotate (left) -- 
      ALU_op        <= "0101";
      ALU_inst_sel  <= "00"; --don't use carry
      ALU_d1_in_sel <= "01";
      ALU_d2_in_sel <= "01";
      RF_data_in_1  <= "0000000000000001";
      RF_data_in_2  <= "0000000000001111";
      
      --enable previous result on B bus
      ALU_out_1_mux <= "10";
      wait for TIME_DELTA;
      
      -- Rotate with Carry (right) -- 
      ALU_op        <= "0101";
      ALU_inst_sel  <= "11"; 
      ALU_d1_in_sel <= "01";
      ALU_d2_in_sel <= "01";
      RF_data_in_1  <= "0000000000000001";
      RF_data_in_2  <= "0000000000001111";
      
      --enable previous result on C bus
      ALU_out_1_mux <= "11";
      wait for TIME_DELTA;
      
      -- Shift Logical (right)-- 
      ALU_op        <= "0110";
      ALU_inst_sel  <= "01"; 
      ALU_d1_in_sel <= "01";
      ALU_d2_in_sel <= "01";
      RF_data_in_1  <= "0000000000000001";
      RF_data_in_2  <= "0000000000001111";
      
      --enable previous result on C bus
      ALU_out_1_mux <= "11";
      wait for TIME_DELTA;
      
      -- Shift Arithmetic (left)-- 
      ALU_op        <= "0111";
      ALU_inst_sel  <= "00"; 
      ALU_d1_in_sel <= "01";
      ALU_d2_in_sel <= "01";
      RF_data_in_1  <= "0000000000000001";
      RF_data_in_2  <= "0000000000001111";
      
      --enable previous result on B bus
      ALU_out_1_mux <= "10";
      wait for TIME_DELTA;
      
      -- Shift Logical (left)-- 
      ALU_op        <= "0110";
      ALU_inst_sel  <= "00"; 
      ALU_d1_in_sel <= "01";
      ALU_d2_in_sel <= "01";
      RF_data_in_1  <= "0000000000000001";
      RF_data_in_2  <= "0000000000001111";
      
      --enable previous result on A bus
      ALU_out_1_mux <= "01";
      wait for TIME_DELTA;
      
      -- Shift Arithmetic (right)
      ALU_op        <= "0111";
      ALU_inst_sel  <= "01"; 
      ALU_d1_in_sel <= "01";
      ALU_d2_in_sel <= "01";
      RF_data_in_1  <= "0000000000000001";
      RF_data_in_2  <= "0000000000001111";
      wait for TIME_DELTA;
      
      -- Load
      ALU_op        <= "1000";
      ALU_inst_sel  <= "00";
      ALU_d1_in_sel <= "10";
      ALU_d2_in_sel <= "10";
      RF_data_in_1  <= "0000000000000001";
      RF_data_in_2  <= "0000000000001111";
      value_immediate <= "0000000000101111";
      MEM_address     <= "0000000000000001";
      
      --enable previous result on A bus
      ALU_out_1_mux <= "01";
      wait for TIME_DELTA;
      
      -- Store (register addressing)
      ALU_op        <= "1000";
      ALU_inst_sel  <= "10";
      ALU_d1_in_sel <= "10";
      ALU_d2_in_sel <= "01";
      RF_data_in_1  <= "0000000000000001";
      RF_data_in_2  <= "0000000000001111";
      value_immediate     <= "0000000000101111";
      MEM_address         <= "0000000001000001";
      ALU_fwd_data_in_en  <= '1';
      
      --enable previous result on B bus
      ALU_out_1_mux <= "10";
      wait for TIME_DELTA;
      
      -- Store (immediate addressing)
      ALU_op        <= "1000";
      ALU_inst_sel  <= "11";
      ALU_d1_in_sel <= "10";
      ALU_d2_in_sel <= "10";
      RF_data_in_1  <= "0000000000111111";
      RF_data_in_2  <= "0000000000001111";
      value_immediate     <= "0000000000101111";
      MEM_address         <= "0000000000000001";
      ALU_fwd_data_in_en  <= '1';
      ALU_fwd_data_out_en <= '1';
      
      --enable effective memory address on B bus
      ALU_out_1_mux <= "10";
      
      --enable register information on A bus
      ALU_out_2_mux <= "01";
      wait for TIME_DELTA;
      
      -- GPIO read
      ALU_op        <= "1011";
      ALU_inst_sel  <= "00";
      ALU_d1_in_sel <= "10";
      ALU_d2_in_sel <= "10";
      RF_data_in_1  <= "0000000000111111";
      RF_data_in_2  <= "0000000000001111";
      value_immediate     <= "0000000000101111";
      MEM_address         <= "0100000000000001";
      ALU_fwd_data_out_en <= '1';
      
      --enable effective memory address on B bus
      ALU_out_1_mux <= "10";
      
      --enable register information on A bus
      ALU_out_2_mux <= "01";
      wait for TIME_DELTA;
      
      -- GPIO write
      ALU_op        <= "1011";
      ALU_inst_sel  <= "01";
      ALU_d1_in_sel <= "10";
      ALU_d2_in_sel <= "10";
      RF_data_in_1  <= "0000000000111111";
      RF_data_in_2  <= "0000000000001111";
      value_immediate     <= "0000000000101111";
      MEM_address         <= "0000000000000001";
      ALU_fwd_data_in_en  <= '1';
      ALU_fwd_data_out_en <= '0';
      
      --don't need to output anything from previous inst (GPIO read)
      ALU_out_1_mux <= "00";
      
      --not forwarding anything for previous inst (GPIO read)
      ALU_out_2_mux <= "00";
      wait for TIME_DELTA;
      
      -- I2C read
      ALU_op        <= "1011";
      ALU_inst_sel  <= "10";
      ALU_d1_in_sel <= "10";
      ALU_d2_in_sel <= "10";
      RF_data_in_1  <= "0000000000111111";
      RF_data_in_2  <= "0000000000001111";
      value_immediate     <= "0000000000000000";
      MEM_address         <= "0000000000000001";
      ALU_fwd_data_in_en  <= '1';
      ALU_fwd_data_out_en <= '0';
      
      --enable previous result on A bus
      ALU_out_1_mux <= "01";
      
      --not forwarding anything for previous inst 
      ALU_out_2_mux <= "00";
      wait for TIME_DELTA;
      
      -- I2C write
      ALU_op        <= "1011";
      ALU_inst_sel  <= "11";
      ALU_d1_in_sel <= "10";
      ALU_d2_in_sel <= "10";
      RF_data_in_1  <= "0000000000111111";
      RF_data_in_2  <= "0000000000001111";
      value_immediate     <= "0000000000000000";
      MEM_address         <= "0000000000000011";
      ALU_fwd_data_in_en  <= '1';
      ALU_fwd_data_out_en <= '0';
      
      --enable previous result on A bus
      ALU_out_1_mux <= "01";
      
      --not forwarding anything for previous inst (I2C read)
      ALU_out_2_mux <= "00";
      wait for TIME_DELTA;
      
    end process simulation;

end architecture test;



