
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MEM_tb is
end MEM_tb;

architecture test of MEM_tb is
--import MEM
component MEM_top
  port ( 
		--Input data and clock
		reset_n, sys_clock	: in std_logic;	
		mem_addr_in				: in std_logic_vector(10 downto 0);	--data memory address directly from MEM control unit
		
		--Control 
		A_bus_out_en, C_bus_out_en		: in std_logic; --enables data memory output on A and C bus
		A_bus_in_sel, C_bus_in_sel		: in std_logic; --enables A or C bus to data_in
		wr_en									: in std_logic; --write enable for data memory

		--Inouts
		A_bus, C_bus	: inout std_logic_vector(15 downto 0)
	);
end component;

--time delta for waiting between test inputs
constant TIME_DELTA : time := 10 ns;

-- test signals here, map identically to EUT
signal A_bus, C_bus                 : std_logic_vector(15 downto 0) := "ZZZZZZZZZZZZZZZZ"; --
signal mem_addr                     : std_logic_vector(10 downto 0);
signal A_bus_out_en, C_bus_out_en	  : std_logic := '0'; --enables A or B bus onto output_buffer
signal A_bus_in_sel, C_bus_in_sel		 : std_logic := '0'; --enables input_buffer on A or B bus
signal clk, reset_n, wr_en          : std_logic := '0';               -- initialize to 0;

  begin
    
    dut : entity work.MEM_top
      port map(
        --Input data and clock
		    reset_n       => reset_n, 
		    sys_clock	    => clk,	
		    mem_addr_in	  => mem_addr,
		
		    --Control 
		    A_bus_out_en  => A_bus_out_en, 
		    C_bus_out_en	 => C_bus_out_en,	
		    A_bus_in_sel  => A_bus_in_sel, 
		    C_bus_in_sel		=> C_bus_in_sel,
		    wr_en									=> wr_en,

		    --Inouts
		    A_bus     => A_bus, 
		    C_bus     => C_bus	
      );
      
    clk <=  '1' after TIME_DELTA / 2 when clk = '0' else
            '0' after TIME_DELTA / 2 when clk = '1'; 
        
    simulation : process
    begin
      --initialize all registers, and wait a few clocks
      reset_n <= '0';
      mem_addr <= "00000000000";
      wait for TIME_DELTA * 2;
      
      reset_n <= '1';
      wait for TIME_DELTA;
      
      -- select arbitrary DM address and write to A_bus
      mem_addr <= "00000000001";
      --wait for TIME_DELTA;
      A_bus_out_en <= '1';
      wait for TIME_DELTA;
      
      -- clear controls
      A_bus_out_en <= '0';
      
      -- now write to another address
      mem_addr <= "00000000010";
      C_bus <= "1111000011110000";
      C_bus_in_sel <= '1';
      wr_en <= '1';
      wait for TIME_DELTA;
      
      -- clear controls
      C_bus <= "ZZZZZZZZZZZZZZZZ";
      C_bus_in_sel <= '0';
      wr_en <= '0';
      
      -- now read from that same address
      A_bus_out_en <= '1';
      wait for TIME_DELTA;

      -- select another arbitrary DM address and write to C_bus
      mem_addr <= "00000000111";
      A_bus_out_en <= '1';
      wait for TIME_DELTA;
      
      -- clear controls
      A_bus_out_en <= '0';
      wait for TIME_DELTA;
    
    end process simulation;

end architecture test;




