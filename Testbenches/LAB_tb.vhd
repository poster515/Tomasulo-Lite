
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--
entity LAB_tb is
end LAB_tb;

architecture test of LAB_tb is
--
component LAB is
	generic ( LAB_MAX	: integer	:= 5 	);
	port (
		sys_clock, reset_n  	: in std_logic;
		stall_pipeline			: in std_logic; --needed when waiting for certain commands, should be formulated in top level CU module
		ID_tag			: in std_logic_vector(4 downto 0); --source registers for instruction in ID stage
		EX_tag			: in std_logic_vector(4 downto 0); --source registers for instruction in EX stage (results available)
		MEM_tag			: in std_logic_vector(4 downto 0); --source registers for instruction in MEM stage (results available)
		WB_tag			: in std_logic_vector(4 downto 0); --source registers for instruction in WB stage (results available)
		tag_to_commit	: in integer;	--input from WB stage, which denotes the tag of the instruction that has been written back, only valid for single clock
		PM_data_in		: in 	std_logic_vector(15 downto 0);
		PC					: out std_logic_vector(10 downto 0);
		IW					: out std_logic_vector(15 downto 0);
		MEM				: out std_logic_vector(15 downto 0)

	);
end component;

--time delta for waiting between test inputs
constant TIME_DELTA : time := 10 ns;

-- test signals here, map identically to EUT
signal sys_clock		: std_logic := '1'; 
signal reset_n   		: std_logic  := '0';
signal stall_pipeline	: std_logic := '0'; --needed when waiting for certain commands, should be formulated in top level CU module
signal ID_tag			: std_logic_vector(4 downto 0); --source registers for instruction in ID stage
signal EX_tag			: std_logic_vector(4 downto 0); --source registers for instruction in EX stage (results available)
signal MEM_tag			: std_logic_vector(4 downto 0); --source registers for instruction in MEM stage (results available)
signal WB_tag			: std_logic_vector(4 downto 0); --source registers for instruction in WB stage (results available)
signal tag_to_commit	: integer;	--input from WB stage, which denotes the tag of the instruction that has been written back, only valid for single clock
signal PM_data_in		: std_logic_vector(15 downto 0);
signal PC				: std_logic_vector(10 downto 0);
signal IW				: std_logic_vector(15 downto 0);
signal MEM				: std_logic_vector(15 downto 0);

-- User interface

  begin
    
    dut : entity work.LAB
      port map(
        sys_clock       => sys_clock, 
        reset_n  	      => reset_n,
		    stall_pipeline		=>	stall_pipeline,
		    ID_tag			       => ID_tag,
		    EX_tag			       => EX_tag,
		    MEM_tag			      => MEM_tag,
		    WB_tag		        => WB_tag,
		    tag_to_commit	  => tag_to_commit,
		    PM_data_in		    => PM_data_in,
		    PC					         => PC,
		    IW					         => IW,
		    MEM				         => MEM
      );
      
    sys_clock <=  '1' after TIME_DELTA / 2 when sys_clock = '0' else
                  '0' after TIME_DELTA / 2 when sys_clock = '1'; 

    --NOTE: clk_div is 12 for this simulation
    simulation : process
    begin
      
      --sys_clock <=  '1' after TIME_DELTA / 2 when sys_clock = '0' else
      --              	'0' after TIME_DELTA / 2 when sys_clock = '1'; 

      --initialize all registers, and wait a few clock
      --reset_n <= '0';
	    --sys_clock <= '0';
      wait for TIME_DELTA * 2;
      
      reset_n <= '1';
      wait for TIME_DELTA / 2; --half clock cycle allows input data to be stable from PM
      
      --stall and saturate LAB, memory address for LD falls just outside LAB  
      --ADD R1, R2
      PM_data_in <= "0000000010001000";
      wait for TIME_DELTA;
            --stall and saturate LAB, memory address for LD falls just outside LAB  
      --ADD R1, R2
      PM_data_in <= "0000000010001000";
      wait for TIME_DELTA;
      
      --ADDI R2, #2
      PM_data_in <= "0000000100001010";
      wait for TIME_DELTA;
  
      --SUBI R3, #2
      stall_pipeline <= '1';
      PM_data_in <= "0001000110001010";
      wait for TIME_DELTA;
      
      --AND R4, R5
      PM_data_in <= "0100001000010110";
      wait for TIME_DELTA;
      
      --ROTLC R6, #5
      PM_data_in <= "0101001010010110";
      wait for TIME_DELTA;
      
      --LD R8, #5
      PM_data_in <= "1000010000010110";
      wait for TIME_DELTA;
      
      --0x0002 (memory address for LD)
      PM_data_in <= "0000000000000010";
      wait for TIME_DELTA * 2;
      
      stall_pipeline <= '0';
      wait for TIME_DELTA;
      
      --ADD R15, R12
      PM_data_in <= "0000011110110000";
      wait for TIME_DELTA;
      
      --ADD R1, R2
      PM_data_in <= "0000000010001000";
      wait for TIME_DELTA;
      
      --ADDI R2, #2
      tag_to_commit <= 0;
      PM_data_in <= "0000000100001010";
      wait for TIME_DELTA;
  
      --SUBI R3, #2
      tag_to_commit <= 5;
      stall_pipeline <= '1';
      PM_data_in <= "0001000110001010";
      wait for TIME_DELTA;
      
      --AND R4, R5
      PM_data_in <= "0100001000010110";
      wait for TIME_DELTA;
      
      --ROTLC R6, #5
      PM_data_in <= "0101001010010110";
      wait for TIME_DELTA;
      
      --LD R8, #5
      PM_data_in <= "1000010000010110";
      wait for TIME_DELTA;
      
      --0x0002 (memory address for LD)
      PM_data_in <= "0000000000000010";
      wait for TIME_DELTA * 2;
      
      stall_pipeline <= '0';
      wait for TIME_DELTA;
      
      --ADD R15, R12
      PM_data_in <= "0000011110110000";
      wait for TIME_DELTA;
      
      --ADD R1, R2
      PM_data_in <= "0000000010001000";
      wait for TIME_DELTA;

      ------------------------------------------------------------------------------
      --stall and saturate LAB, memory address for LD comes in during last LAB spot  
      --ADD R1, R2
      PM_data_in <= "0000000010001000";
      wait for TIME_DELTA;
      
      --ADDI R2, #2
      PM_data_in <= "0000000100001010";
      wait for TIME_DELTA;
  
      --SUBI R3, #2
      stall_pipeline <= '1';
      PM_data_in <= "0001000110001010";
      wait for TIME_DELTA;
      
      --AND R4, R5
      PM_data_in <= "0100001000010110";
      wait for TIME_DELTA;
      
      --LD R8, #5
      PM_data_in <= "1000010000010110";
      wait for TIME_DELTA;
      
      --0x0002 (memory address for LD)
      PM_data_in <= "0000000000000010";
      wait for TIME_DELTA * 2;
      
      stall_pipeline <= '0';
      wait for TIME_DELTA;
      
      --ADD R15, R12
      PM_data_in <= "0000011110110000";
      wait for TIME_DELTA;
      
      --ADD R1, R2
      PM_data_in <= "0000000010001000";
      wait for TIME_DELTA;

      --ROTLC R6, #5
      PM_data_in <= "0101001010010110";
      wait for TIME_DELTA;
      
      stall_pipeline <= '0';
      
    end process simulation;

end architecture test;





