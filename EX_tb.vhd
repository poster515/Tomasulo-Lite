
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity EX_tb is
end EX_tb;

architecture test of EX_tb is
--import MEM_CU
component EX
  port ( 
		--Input data and clock
		reset_n, sys_clock	 : in std_logic;	
		IW_in						        : in std_logic_vector(15 downto 0);
		LAB_stall_in			     : in std_logic;
		WB_stall_in				     : in std_logic;		--set high when an upstream CU block needs this 
		MEM_stall_in			     : in std_logic;
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

component ALU_top
  port (
    --Input data and clock
		clk 					      : in std_logic;
		WB_data				     : in std_logic_vector(15 downto 0); --data forwarded from the WB stage 
		MEM_data				    : in std_logic_vector(15 downto 0); --data forwarded from memory stage
		MEM_address			  : in std_logic_vector(15 downto 0); --memory address forwarded directly from LAB (i.e., next IW following ST/LD inst)
		value_immediate	: in std_logic_vector(15 downto 0); --Reg2 data field from IW directly from EX
																				--used to forward shift/rotate distance and immediate value for addi & subi

		--Control signals
		reset_n					    : in std_logic; --all registers reset to 0 when this goes low
		ALU_op					     : in std_logic_vector(3 downto 0); 	--dictates ALU operation (i.e., OpCode)
		ALU_inst_sel			 : in std_logic_vector(1 downto 0); 	--dictates what sub-function to execute (last two bits of OpCode)
		ALU_d2_mux_sel		: in std_logic_vector(1 downto 0); 	--used to control which data to send to ALU input 2
	
		B_bus_out1_en, C_bus_out1_en		: in std_logic; --enables ALU_out_1 on B and C bus
		B_bus_out2_en, C_bus_out2_en		: in std_logic; --enables ALU_out_2 on B and C bus	
		B_bus_in1_sel, C_bus_in1_sel		: in std_logic; --enables B or C bus into ALU input 1
		B_bus_in2_sel, C_bus_in2_sel		: in std_logic; --enables B or C bus into ALU input 2 
												 
		--Outputs
		mem_addr_eff		: out std_logic_vector(10 downto 0);
		ALU_SR 				   : out std_logic_vector(3 downto 0); --provides | Zero (Z) | Overflow (V) | Negative (N) | Carry (C) |
		B_bus, C_bus		: inout std_logic_vector(15 downto 0)
  );
end component;

--time delta for waiting between test inputs
constant TIME_DELTA : time := 10 ns;

-- EX signals
--Input data and clock
	signal reset_n, sys_clock	   : std_logic := '0';	
	signal IW_in						           : std_logic_vector(15 downto 0) := "0000000000000000";
	signal LAB_stall_in			       : std_logic := '0';
	signal WB_stall_in				       : std_logic := '0';
	signal MEM_stall_in				      : std_logic := '0';		
	signal immediate_val_in		    : std_logic_vector(15 downto 0) := "0000000000000000";
	
	--EX Control
	signal ALU_out1_en, ALU_out2_en	: std_logic := '0'; 
	
	--Outputs
	signal ALU_op			     : std_logic_vector(3 downto 0) := "0000"; --common
	signal ALU_inst_sel	 : std_logic_vector(1 downto 0) := "00";   --common
	signal EX_stall_out	 : std_logic := '0';
	signal IW_out			     : std_logic_vector(15 downto 0) := "0000000000000000";	
	signal immediate_val	:	std_logic_vector(15 downto 0) := "0000000000000000";
	
-- ALU_top signals (non-redundant signals)
  signal WB_data				     : std_logic_vector(15 downto 0) := "0000000000000000"; 
	signal MEM_data				    : std_logic_vector(15 downto 0) := "0000000000000000"; 
	signal MEM_address			  : std_logic_vector(15 downto 0) := "0000000000000000"; 
	
	
  
  begin
    
    entity work.EX
      port map(
        --Input data and clock
		    reset_n       => reset_n, 
		    sys_clock	    => sys_clock,
		    IW_in						   => IW_in,
		    LAB_stall_in		=> LAB_stall_in,
		    WB_stall_in			=> WB_stall_in,
		    I2C_error				 => I2C_error,
		    I2C_op_run				=> I2C_op_run,
		
		    --MEM Control Outputs
		    MEM_in_sel		  => MEM_in_sel,
		    MEM_out_en		  => MEM_out_en,
		    MEM_wr_en		   => MEM_wr_en,
		    MEM_op			     => MEM_op,
		
		    --ION Control Outputs
		    GPIO_r_en     => GPIO_r_en, 
		    GPIO_wr_en 	  => GPIO_wr_en,
		    I2C_r_en      => I2C_r_en, 
		    I2C_wr_en		   => I2C_wr_en,
		    ION_out_en				=> ION_out_en,
		    ION_in_sel				=> ION_in_sel,
	
		    --Outputs
		    I2C_error_out	=> I2C_error_out,
		    IW_out			     => IW_out,
		    stall_out		   => stall_out
      );
      
    entity work.ALU_top
      port map(
        --Input data and clock
		    reset_n       => reset_n, 
		    sys_clock	    => sys_clock,
		    IW_in						   => IW_in,
		    LAB_stall_in		=> LAB_stall_in,
		    WB_stall_in			=> WB_stall_in,
		    I2C_error				 => I2C_error,
		    I2C_op_run				=> I2C_op_run,
		
		    --MEM Control Outputs
		    MEM_in_sel		  => MEM_in_sel,
		    MEM_out_en		  => MEM_out_en,
		    MEM_wr_en		   => MEM_wr_en,
		    MEM_op			     => MEM_op,
		
		    --ION Control Outputs
		    GPIO_r_en     => GPIO_r_en, 
		    GPIO_wr_en 	  => GPIO_wr_en,
		    I2C_r_en      => I2C_r_en, 
		    I2C_wr_en		   => I2C_wr_en,
		    ION_out_en				=> ION_out_en,
		    ION_in_sel				=> ION_in_sel,
	
		    --Outputs
		    I2C_error_out	=> I2C_error_out,
		    IW_out			     => IW_out,
		    stall_out		   => stall_out
      );
      
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
      I2C_op_run <= '1';
      IW_in <= "1011001110000011"; --WR 0x00000, R7
      wait for 5 * TIME_DELTA;
      
      I2C_op_run <= '0';
      wait for TIME_DELTA;
      
      IW_in <= "1000000100001000"; --LD R2, 0x08(R2)
      I2C_op_run <= '1';
      wait for 1000 ns;
      
    end process simulation;

end architecture test;






