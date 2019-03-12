
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity CPU_tb_RF is
end CPU_tb_RF;

architecture test of CPU_tb_RF is
--import 
component CPU
  port ( 
		reset_n, sys_clock	: in std_logic;	
		digital_in				: in std_logic_vector(15 downto 0); --top level General Purpose inputs
		digital_out				: out std_logic_vector(15 downto 0); --top level General Purpose outputs, driven by ION
		I2C_sda, I2C_scl		: inout std_logic; --top level chip inputs/outputs
		--TEST OUTPUTS ONLY, REMOVE AFTER LAB INSTANTIATED (signal goes to LAB for arbitration)
		I2C_error_out						: out std_logic
		--END TEST INPUTS/OUTPUTS
  );
end component;

--time delta for waiting between test inputs
constant TIME_DELTA : time := 10 ns;

  --TEST INPUTS ONLY, REMOVE AFTER LAB INSTANTIATED (signal goes to LAB for arbitration)
	signal	I2C_error_out						 : std_logic := '0';
  --END TEST INPUTS
		
	--Input data and clock
	signal	reset_n, sys_clock				: std_logic := '0';	
	signal digital_in, digital_out : std_logic_vector(15 downto 0);

	--MEM Feedback Signals
	signal	I2C_sda, I2C_scl 			: std_logic := '0';	
	
  begin
    
    CPU_top : entity work.CPU
      port map(
        --Input data and clock
		    reset_n       => reset_n, 
		    sys_clock	    => sys_clock,
		    digital_in    => digital_in,
		    digital_out   => digital_out,
		    I2C_sda       => I2C_sda,
		    I2C_scl       => I2C_scl,
		    
		    --TEST OUTPUT ONLY, REMOVE AFTER LAB INSTANTIATED (signal goes to LAB for arbitration)
		    I2C_error_out   => I2C_error_out
      );
      
      
    sys_clock <=  '1' after TIME_DELTA / 2 when sys_clock = '0' else
                  '0' after TIME_DELTA / 2 when sys_clock = '1'; 
        
    simulation : process
    begin
      
      reset_n <= '0';
      wait for TIME_DELTA * 2;
      
      reset_n <= '1';
      wait for TIME_DELTA * 75; --allow the program to run
      
    end process simulation;

end architecture test;








