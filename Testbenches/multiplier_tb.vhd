

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--import RF entity
entity multipler_tb is
end multipler_tb;

architecture test of multipler_tb is
--import ALU
component multiplier
  PORT
	(
		dataa		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		datab		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		result		: OUT STD_LOGIC_VECTOR (31 DOWNTO 0)
	);
end component;

--time delta for waiting between test inputs
constant TIME_DELTA : time := 100 ns;

-- test signals here, map identically to EUT
signal dataa, datab 	 : std_logic_vector(15 downto 0); --ALU data inputs
signal result 	        : std_logic_vector(31 downto 0); --ALU data inputs

  begin
    
    dut : entity work.multiplier
      port map(
		    dataa     => dataa,
		    datab		   => datab,
		    result		  => result
      );
      
    simulation : process
    begin

      dataa  <= "0000000000000001";
      datab  <= "0000000000001111";
      wait for TIME_DELTA;
      
      dataa  <= "0000000000000011";
      datab  <= "1000000000001111";
      wait for TIME_DELTA;
      
      dataa  <= "0000000000000010";
      datab  <= "0000000010000000";
      wait for TIME_DELTA;
      
    end process simulation;

end architecture test;





