
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--import RF entity
entity RF_top_tb is
end RF_top_tb;

architecture test of RF_top_tb is
--import RF
component RF_top
  port(
   --Input data and clock
		clk 		: in std_logic;

		--Control signals
		reset_n			: in std_logic; --all registers reset to 0 when this goes low
		wr_en 			: in std_logic; --enables write for a selected register
		B_bus_out_mux	: in std_logic_vector(4 downto 0);	--controls first output mux
		C_bus_out_mux	: in std_logic_vector(4 downto 0);	--controls second output mux
		RF_in_demux		: in std_logic_vector(4 downto 0);	--controls which register to write data to
		B_bus_out_en, C_bus_out_en		: in std_logic; --enables RF_out_1 on B and C bus
		B_bus_in_en, C_bus_in_en		: in std_logic; --enables B and C bus data in to RF

		--Outputs
		B_bus, C_bus	: inout std_logic_vector(15 downto 0)
  );
end component;

--time delta for waiting between test inputs
constant TIME_DELTA : time := 10 ns;

-- test signals here, map identically to EUT
signal clk 		  : std_logic := '0'; -- initialize to 0;
signal reset_n	: std_logic := '0'; --all registers reset to 0 when this goes low
signal wr_en 	 : std_logic := '0'; --enables write for a selected register, initialize low
signal B_bus_out_mux	: std_logic_vector(4 downto 0)  := "00000";	--controls first output mux
signal C_bus_out_mux	: std_logic_vector(4 downto 0)  := "00000";	--controls second output mux
signal RF_in_demux	 : std_logic_vector(4 downto 0)  := "00000";	--controls which register to write data to
signal B_bus_out_en, C_bus_out_en : std_logic := '0'; --various output enable controls
signal B_bus_in_en, C_bus_in_en     : std_logic := '0';
signal B_bus, C_bus : std_logic_vector(15 downto 0) := "ZZZZZZZZZZZZZZZZ";


  begin
    
    dut : entity work.RF_top
      port map(
	      clk 		  => clk,
	      
	      --Control signals
	      reset_n	=> reset_n, --all registers reset to 0 when this goes low
	      wr_en 	 => wr_en, --enables write for a selected register
	      B_bus_out_mux	=> B_bus_out_mux,	--controls first output mux
	      C_bus_out_mux	=> C_bus_out_mux,	--controls second output mux
	      RF_in_demux	 => RF_in_demux,	--controls which register to write data to
	      B_bus_out_en => B_bus_out_en, 
	      C_bus_out_en => C_bus_out_en,	
		    B_bus_in_en => B_bus_in_en, 
		    C_bus_in_en => C_bus_in_en,
	 
        --Outputs
        B_bus   => B_bus,
        C_bus 	 => C_bus
      );
      
    clk <=  '1' after TIME_DELTA / 2 when clk = '0' else
            '0' after TIME_DELTA / 2 when clk = '1'; 
        
    simulation : process
    begin
      --initialize all registers, and wait a few clocks
      reset_n <= '0';
      wait for TIME_DELTA * 2;
      
      -- do initial write to R1 with "1111000011110000" from B bus
      reset_n <= '1';
      wr_en <= '1';
      B_bus <= "1111000011110000";
      RF_in_demux <= "00001";
      B_bus_in_en <= '1';
      wait for TIME_DELTA;
      
      -- read R1 onto B bus
      wr_en <= '0';
      B_bus_out_mux <= "00001";
      B_bus_out_en <= '1';
      C_bus_out_en <= '0';
      B_bus <= "ZZZZZZZZZZZZZZZZ";
      C_bus <= "ZZZZZZZZZZZZZZZZ";
      wait for TIME_DELTA;
      
      -- do initial write to R2 with "0101010101010101"
      C_bus_out_en <= '0';
      wr_en <= '1';
      C_bus <= "0101010101010101";
      RF_in_demux <= "00010";
      B_bus_in_en <= '0';
      C_bus_in_en <= '1';
      B_bus_out_en <= '0';
      C_bus_out_en <= '0';
      wait for TIME_DELTA;
      
      -- read R2 onto C bus
      wr_en <= '0';
      C_bus_out_mux <= "00010";
      C_bus_out_en <= '1';
      B_bus <= "ZZZZZZZZZZZZZZZZ";
      C_bus <= "ZZZZZZZZZZZZZZZZ";
      B_bus_out_en <= '0';
      wait for TIME_DELTA;
      
    end process simulation;

end architecture test;


