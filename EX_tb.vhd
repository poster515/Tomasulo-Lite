
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity EX_tb is
end EX_tb;

architecture test of EX_tb is
--import 
component EX
  port ( 
		--Input data and clock
		reset_n, sys_clock	 : in std_logic;	
		IW_in						        : in std_logic_vector(15 downto 0);
		LAB_stall_in			     : in std_logic;
		WB_stall_in				     : in std_logic;		--set high when an upstream CU block needs this 
		MEM_stall_in			     : in std_logic;
		mem_addr_in         : in std_logic_vector(15 downto 0);
		immediate_val_in		  : in std_logic_vector(15 downto 0); --immediate value from ID stage
		
		--Control
		ALU_out1_en, ALU_out2_en	: out std_logic; --enables ALU_out_X on B or C bus
		
		--Outputs
		ALU_op			     : out std_logic_vector(3 downto 0);
		ALU_inst_sel	 : out std_logic_vector(1 downto 0);
		EX_stall_out	 : out std_logic;
		IW_out			     : out std_logic_vector(15 downto 0);	--forwarding to MEM control unit
		immediate_val	: out	std_logic_vector(15 downto 0)--represents various immediate values from various OpCodes
	);
end component;

--component ALU_top
--  port (
--    --Input data and clock
--		clk 					      : in std_logic;
--		MEM_address			  : in std_logic_vector(15 downto 0); --memory address forwarded directly from LAB (i.e., next IW following ST/LD inst)
--		value_immediate	: in std_logic_vector(15 downto 0); --Reg2 data field from IW directly from EX
--																				--used to forward shift/rotate distance and immediate value for addi & subi
--
--		--Control signals
--		reset_n					      : in std_logic; --all registers reset to 0 when this goes low
--		ALU_op					       : in std_logic_vector(3 downto 0); 	--dictates ALU operation (i.e., OpCode)
--		ALU_inst_sel			   : in std_logic_vector(1 downto 0); 	--dictates what sub-function to execute (last two bits of OpCode)
--		
--		ALU_d2_bus_in_sel	: in std_logic_vector(2 downto 0); 	--used to control which bus to send to ALU input 2 (from CSAM)
--		ALU_d2_immed_op	  : in std_logic; 	--1 = need to get value_immediate to ALU_in_2, 0 = just use A, B, or C bus data (using ALU_d2_bus_in_sel) (from EX)
--		ALU_d1_bus_in_sel : in std_logic_vector(2 downto 0); 	--used to control which bus to send to ALU input 1 (from CSAM)
--		ALU_d1_DM_op		    : in std_logic;	--1 = need to get MEM_address to ALU_in_1, 0 = just use A, B, or C bus data (using ALU_d1_bus_in_sel) (from EX)
--		
--		ALU_out_1_mux 		  : in std_logic_vector(1 downto 0); --used to output results on A, B, or C bus
--		ALU_out_2_mux		   : in std_logic_vector(1 downto 0); --used to output results on A, B, or C bus
--												 
--		--Outputs
--		mem_addr_eff		        : out std_logic_vector(10 downto 0);
--		ALU_SR 				           : out std_logic_vector(3 downto 0); --provides | Zero (Z) | Overflow (V) | Negative (N) | Carry (C) |
--		A_bus, B_bus, C_bus		 : inout std_logic_vector(15 downto 0)
--  );
--end component;

--time delta for waiting between test inputs
constant TIME_DELTA : time := 10 ns;

-- EX signals
  --Input data and clock
	signal reset_n, sys_clock	   : std_logic := '0';	--common
	signal IW_in						           : std_logic_vector(15 downto 0) := "0000000000000000";
	signal LAB_stall_in			       : std_logic := '0'; --common
	signal WB_stall_in				       : std_logic := '0'; --common
	signal MEM_stall_in				      : std_logic := '0';		
	signal immediate_val_in		    : std_logic_vector(15 downto 0) := "0000000000000000";
	signal mem_addr_in           : std_logic_vector(15 downto 0) := "0000000000000000";
	
	--EX Control Outputs
	signal ALU_out1_en, ALU_out2_en	: std_logic := '0'; 
	
	--Outputs
	signal ALU_op			     : std_logic_vector(3 downto 0) := "0000"; --common
	signal ALU_inst_sel	 : std_logic_vector(1 downto 0) := "00";   --common
	signal EX_stall_out	 : std_logic := '0';
	signal IW_out			     : std_logic_vector(15 downto 0) := "0000000000000000";	
	signal immediate_val	:	std_logic_vector(15 downto 0) := "0000000000000000";
	----------------------------------------------------------------------------------
	
  ----ALU_top signals (non-redundant signals)
--	signal MEM_address			  : std_logic_vector(15 downto 0) := "0000000000000000"; 
--	
--	--ALU Control and Data Inputs
--	signal ALU_d2_bus_in_sel	: std_logic_vector(2 downto 0) := "000"; 	
--	signal ALU_d2_immed_op	  : std_logic := '0'; 	 
--	signal ALU_d1_bus_in_sel : std_logic_vector(2 downto 0) := "000"; 
--	signal ALU_d1_DM_op		    : std_logic := '0';	
--		
--	signal ALU_out_1_mux 		  : std_logic_vector(1 downto 0) := "00"; 
--	signal ALU_out_2_mux		   : std_logic_vector(1 downto 0) := "00"; 
--	
--  signal mem_addr_eff		    : std_logic_vector(10 downto 0) := "00000000000";
--  signal value_immediate   : std_logic_vector(15 downto 0) := "0000000000000000"; 
--  signal ALU_SR            : std_logic_vector(3 downto 0) := "0000"; 
--  
--  signal A_bus, B_bus, C_bus  : std_logic_vector(15 downto 0) := "ZZZZZZZZZZZZZZZZ"; 
  
  begin
    
    EX_CU : entity work.EX
      port map(
        --Input data and clock
		    reset_n       => reset_n, 
		    sys_clock	    => sys_clock,
		    IW_in						   => IW_in,
		    LAB_stall_in		=> LAB_stall_in,
		    WB_stall_in			=> WB_stall_in,
		    MEM_stall_in  => MEM_stall_in,
		    mem_addr_in   => mem_addr_in,
		    immediate_val_in => immediate_val_in,
		
		    --Control Outputs
		    ALU_out1_en => ALU_out1_en, 
		    ALU_out2_en => ALU_out2_en,

		    --Outputs
		    ALU_op			     => ALU_op,
		    ALU_inst_sel	 => ALU_inst_sel,
		    EX_stall_out	 => EX_stall_out,
		    IW_out			     => IW_out,
		    immediate_val	=> immediate_val
      );
      
    --ALU_test : entity work.ALU_top
--      port map(
--        --Input data and clock
--		    clk 					       => sys_clock,
--		    MEM_address		   => MEM_address,
--      		value_immediate	=> value_immediate,
--
--		    --Control signals
--		    reset_n					    => reset_n,
--      		ALU_op				      => ALU_op,
--      		ALU_inst_sel			 => ALU_inst_sel,
--      		ALU_d2_mux_sel		=> ALU_d2_mux_sel,
--	
--		    in1_sel         => in1_sel,
--		    in2_sel         => in2_sel,
--		    
--		    out1_en         => out1_en, 
--      		out2_en         => out2_en, 
--												 
--		    --Outputs
--		    mem_addr_eff  => mem_addr_eff,
--		    ALU_SR        => ALU_SR,
--		    A_bus         => A_bus,
--		    B_bus         => B_bus,
--		    C_bus		       => C_bus
--      );
      
    sys_clock <=  '1' after TIME_DELTA / 2 when sys_clock = '0' else
                  '0' after TIME_DELTA / 2 when sys_clock = '1'; 
        
    simulation : process
    begin
      --initialize all registers, and wait a few clocks
      reset_n <= '0';
      wait for TIME_DELTA * 2;
      
      reset_n <= '1';
      
      -- first try some non-memory/ION operation
      IW_in <= "0000000100001000"; --ADD R2, R2
      wait for TIME_DELTA;
      
      -- try some non-memory/ION operation
      IW_in <= "0001000100001000"; --SUB R2, R2
      wait for TIME_DELTA;
      
      -- try some non-memory/ION operation
      IW_in <= "1100000100001000"; --ANDI R2, #2
      wait for TIME_DELTA;
      
      -- now try some a memory operation
      IW_in <= "1000000100001000"; --LD R2, 0x08(R2)
      wait for TIME_DELTA;
      
      -- now try some an GPIO write operation
      IW_in <= "1011000100000001"; --WR R2
      wait for TIME_DELTA;
      
      -- now try some an GPIO read operation
      IW_in <= "1011001010000000"; --RD R5
      wait for TIME_DELTA;
      
      -- now try some an I2C read operation
      IW_in <= "1011001010000010"; --RD 0x00000, R5
      wait for TIME_DELTA;
      
      -- now try some another immediate I2C write operation
      IW_in <= "1011001110000011"; --WR 0x00000, R7
      wait for TIME_DELTA;
     
      IW_in <= "1000000100001000"; --LD R2, 0x08(R2)
      wait for 1000 ns;
      
    end process simulation;

end architecture test;






