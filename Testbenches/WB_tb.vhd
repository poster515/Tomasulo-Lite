
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity WB_tb is
end WB_tb;

architecture test of WB_tb is
--import MEM_CU
component WB
  port ( 
		--Input data and clock
		reset_n, sys_clock	: in std_logic;	
		IW_in, PM_data_in		: in std_logic_vector(15 downto 0); --IW from MEM and from PM, via LAB, respectively
		LAB_stall_in			: in std_logic;		--set high when an upstream CU block needs this 
		
		--Control
		RF_in_demux			: out std_logic_vector(4 downto 0); -- selects which 
		RF_in_en, wr_en	: out std_logic;	-- RF_in_en sent to CSAM for arbitration. wr_en also sent to CSAM, although it's passed through. 
		A_bus_in_sel		: in std_logic; 	-- from CSAM, selects data from memory stage to buffer in ROB
		C_bus_in_sel		: in std_logic; 	-- from CSAM, selects data from memory stage to buffer in ROB
		B_bus_out_en		: in std_logic;	-- from CSAM, if '1', we can write result on B_bus
		C_bus_out_en		: in std_logic;	-- from CSAM, if '1', we can write result on C_bus
					
		--Outputs
		stall_out		: out std_logic;

		--Inouts
		A_bus, B_bus, C_bus	: inout std_logic_vector(15 downto 0) --A/C bus because we need access to memory stage outputs, B/C bus because RF has access to them
	);
end component;

--time delta for waiting between test inputs
constant TIME_DELTA : time := 10 ns;

-- test signals here, map identically to EUT
signal A_bus, B_bus, C_bus          : std_logic_vector(15 downto 0) := "ZZZZZZZZZZZZZZZZ"; --
signal IW_in, PM_data_in		          : std_logic_vector(15 downto 0) := "0000000000000000";
signal LAB_stall_in, stall_out      : std_logic := '0';		--set high when an upstream CU block needs this 
signal B_bus_out_en, C_bus_out_en	  : std_logic := '0'; --enables A or B bus onto output_buffer
signal A_bus_in_sel, C_bus_in_sel		 : std_logic := '0'; --enables input_buffer on A or B bus
signal clk, reset_n                 : std_logic := '0';               -- initialize to 0;
signal wr_en, RF_in_en              : std_logic := '0';               -- initialize to 0;
signal RF_in_demux			               : std_logic_vector(4 downto 0) := "00000"; -- selects which 


  begin
    
    dut : entity work.WB
      port map(
        --Input data and clock
		    reset_n         => reset_n, 
		    sys_clock	      => clk,	
      		IW_in           => IW_in, 
      		PM_data_in		    => PM_data_in,
		    LAB_stall_in			 => LAB_stall_in,
		
		    --Control
		    RF_in_demux			=> RF_in_demux,
		    RF_in_en      => RF_in_en, 
		    wr_en	        => wr_en,
		    A_bus_in_sel		=> A_bus_in_sel,
	 	    C_bus_in_sel		=> C_bus_in_sel,
		    B_bus_out_en		=> B_bus_out_en,
		    C_bus_out_en		=> C_bus_out_en,
					
		    --Outputs
		    stall_out		   => stall_out,

		    --Inouts
		    A_bus         => A_bus, 
		    B_bus         => B_bus, 
		    C_bus         => C_bus 
      );
      
    clk <=  '1' after TIME_DELTA / 2 when clk = '0' else
            '0' after TIME_DELTA / 2 when clk = '1'; 
        
    simulation : process
    begin
      --initialize all registers, and wait a few clocks
      reset_n <= '0';
      wait for TIME_DELTA * 2;
      
      reset_n <= '1';
      wait for TIME_DELTA;
      
      --saturate pipeline, similar to startup of CPU
      PM_data_in <= "0000001000001000"; -- ADD R4, R2
      wait for TIME_DELTA;
      
      PM_data_in <= "0000000100001000"; -- ADD R2, R2
      wait for TIME_DELTA;
      
      PM_data_in <= "0000000010001000"; -- ADD R1, R2
      wait for TIME_DELTA;
      
      PM_data_in <= "0000000110001000"; -- ADD R3, R2
      wait for TIME_DELTA;
      
      PM_data_in <= "0000001100001000"; -- ADD R6, R2
      wait for TIME_DELTA;
      
      --now the first instruction should have been received by the WB stage, also repeat instruction set (i.e., loop)
      PM_data_in <= "0000001000001000"; -- ADD R4, R2
      IW_in      <= "0000001000001000"; -- ADD R4, R2
      A_bus_in_sel <= '1'; --select result from A bus
      A_bus <= "0000111100011111";
      C_bus_out_en <= '1';
      wait for TIME_DELTA;
      
      PM_data_in <= "0000000100001000"; -- ADD R2, R2
      IW_in      <= "0000000100001000"; -- ADD R2, R2
      A_bus_in_sel <= '0'; --
      A_bus <= "ZZZZZZZZZZZZZZZZ";
      C_bus_in_sel <= '1'; --select result from C bus
      C_bus <= "1111000000001010";
      C_bus_out_en <= '0';
      B_bus_out_en <= '1'; --output result on B bus
      wait for TIME_DELTA;
      
      PM_data_in <= "0000000010001000"; -- ADD R1, R2
      IW_in      <= "0000000010001000"; -- ADD R1, R2
      A_bus_in_sel <= '1'; --select result from A bus
      A_bus <= "0101010101010101";
      C_bus_in_sel <= '0'; --
      C_bus <= "ZZZZZZZZZZZZZZZZ";
      C_bus_out_en <= '1'; --output result on C bus
      B_bus_out_en <= '0'; 
      wait for TIME_DELTA;
      
      PM_data_in <= "0000000110001000"; -- ADD R3, R2
      IW_in      <= "0000000110001000"; -- ADD R3, R2
      A_bus_in_sel <= '1'; --select result from A bus
      A_bus <= "0000000011111111";
      C_bus_in_sel <= '0'; --
      C_bus <= "ZZZZZZZZZZZZZZZZ";
      C_bus_out_en <= '1'; --output result on C bus
      B_bus_out_en <= '0'; 
      wait for TIME_DELTA;
      
      PM_data_in <= "0000001100001000"; -- ADD R6, R2
      IW_in      <= "0000001100001000"; -- ADD R6, R2
      A_bus_in_sel <= '0'; --
      A_bus <= "ZZZZZZZZZZZZZZZZ";
      C_bus_in_sel <= '1'; --select result from C bus
      C_bus <= "1111000000001010";
      C_bus_out_en <= '0';
      B_bus_out_en <= '1'; --output result on B bus
      wait for TIME_DELTA;
    
    end process simulation;

end architecture test;






