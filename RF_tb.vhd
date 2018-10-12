library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--import RF entity
entity RF_tb is
end RF_tb;

architecture test of RF_tb is
--import RF
component RF
  port(
    --Input data and clock
	 RF_in 	 : in std_logic_vector(15 downto 0);
	 clk 		  : in std_logic;
	 
	 --Control signals
	 reset_n	: in std_logic; --all registers reset to 0 when this goes low
	 wr_en 	 : in std_logic; --enables write for a selected register
	 RF_out_1_mux	: in std_logic_vector(3 downto 0);	--controls first output mux
	 RF_out_2_mux	: in std_logic_vector(3 downto 0);	--controls second output mux
	 RF_in_demux	 : in std_logic_vector(3 downto 0);	--controls which register to write data to
	 
    --Outputs
    RF_out_1   : out std_logic_vector(15 downto 0);
    RF_out_2 	 : out std_logic_vector(15 downto 0)
  );
end component;

--time delta for waiting between test inputs
constant TIME_DELTA : time := 100 ns;

-- test signals here, map identically to EUT
signal RF_in 	 : std_logic_vector(15 downto 0);
signal clk 		  : std_logic := '0'; -- initialize to 0;
signal reset_n	: std_logic; --all registers reset to 0 when this goes low
signal wr_en 	 : std_logic := '0'; --enables write for a selected register, initialize low
signal RF_out_1_mux	: std_logic_vector(3 downto 0);	--controls first output mux
signal RF_out_2_mux	: std_logic_vector(3 downto 0);	--controls second output mux
signal RF_in_demux	 : std_logic_vector(3 downto 0);	--controls which register to write data to
signal RF_out_1   : std_logic_vector(15 downto 0);
signal RF_out_2 	 : std_logic_vector(15 downto 0);

  begin
    
    dut : entity work.RF
      port map(
        RF_in 	 => RF_in,
	      clk 		  => clk,
	      
	      --Control signals
	      reset_n	=> reset_n, --all registers reset to 0 when this goes low
	      wr_en 	 => wr_en, --enables write for a selected register
	      RF_out_1_mux	=> RF_out_1_mux,	--controls first output mux
	      RF_out_2_mux	=> RF_out_2_mux,	--controls second output mux
	      RF_in_demux	 => RF_in_demux,	--controls which register to write data to
	 
        --Outputs
        RF_out_1   => RF_out_1,
        RF_out_2 	 => RF_out_2
      );
      
    clk <=  '1' after TIME_DELTA / 2 when clk = '0' else
            '0' after TIME_DELTA / 2 when clk = '1'; 
        
    simulation : process
    begin
      --initialize all registers, and wait a few clocks
      reset_n <= '0';
      wait for TIME_DELTA * 2;
      
      -- do initial write to R1 with "1111000011110000"
      reset_n <= '1';
      wr_en <= '1';
      RF_in <= "1111000011110000";
      RF_in_demux <= "0001";
      wait for TIME_DELTA;
      
      -- read R1
      wr_en <= '0';
      RF_out_1_mux <= "0001";
      wait for TIME_DELTA;
      
      -- do initial write to R2 with "0101010101010101"
      wr_en <= '1';
      RF_in <= "0101010101010101";
      RF_in_demux <= "0010";
      wait for TIME_DELTA;
      
      -- read R1
      wr_en <= '0';
      RF_out_2_mux <= "0010";
      wait for TIME_DELTA;
      
      -- do second write to R1 with "1111111111111111"
      reset_n <= '1';
      wr_en <= '1';
      RF_in <= "1111111111111111";
      RF_in_demux <= "0001";
      wait for TIME_DELTA;
      
      -- read R1
      wr_en <= '0';
      RF_out_1_mux <= "0001";
      wait for TIME_DELTA;
      
    end process simulation;

end architecture test;

