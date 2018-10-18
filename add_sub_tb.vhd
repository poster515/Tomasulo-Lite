
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--import RF entity
entity add_sub_tb is
end add_sub_tb;

architecture test of add_sub_tb is
--import ALU
component add_sub
  PORT
	(
		add_sub		: IN STD_LOGIC ;
		dataa		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		datab		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		cout		: OUT STD_LOGIC ;
		overflow		: OUT STD_LOGIC ;
		result		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
end component;

--time delta for waiting between test inputs
constant TIME_DELTA : time := 100 ns;

-- test signals here, map identically to EUT
signal dataa, datab 	 : std_logic_vector(15 downto 0); --ALU data inputs
signal result 	        : std_logic_vector(15 downto 0); --ALU data inputs
signal cout, overflow : std_logic;
signal add_sub_sel : std_logic := '0'; -- initialize to 0;



  begin
    
    dut : entity work.add_sub
      port map(
        add_sub		 => add_sub_sel,
		    dataa     => dataa,
		    datab		   => datab,
		    cout		    => cout,
		    overflow		=> overflow,
		    result		  => result
      );
      
    simulation : process
    begin
      -- Add
      add_sub_sel    <= '1';
      dataa  <= "0000000000000001";
      datab  <= "0000000000001111";
      wait for TIME_DELTA;
      
      -- Add
      add_sub_sel    <= '1';
      dataa  <= "0000000000000001";
      datab  <= "1000000000001111";
      wait for TIME_DELTA;
      
      -- Add
      add_sub_sel    <= '1';
      dataa  <= "0000000000000000";
      datab  <= "0000000000000000";
      wait for TIME_DELTA;
      
      -- Add
      add_sub_sel    <= '0';
      dataa  <= "0000000000010001";
      datab  <= "0000000000001111";
      wait for TIME_DELTA;
      
      -- Add
      add_sub_sel    <= '0';
      dataa  <= "0000000000000001";
      datab  <= "0000000000001111";
      wait for TIME_DELTA;
      
    end process simulation;

end architecture test;



