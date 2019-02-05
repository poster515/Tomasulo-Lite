library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--import demux entity
entity demux_16_tb is
end demux_16_tb;

architecture test of demux_16_tb is
--import demux_16
component demux_16
  port(
    sel 		: in  std_logic_vector(3 downto 0);
		sig_in  	: in std_logic_vector(15 downto 0);
		
		out_0   	: out  std_logic_vector(15 downto 0);
		out_1   	: out  std_logic_vector(15 downto 0);
		out_2   	: out  std_logic_vector(15 downto 0);
		out_3   	: out  std_logic_vector(15 downto 0);
		out_4   	: out  std_logic_vector(15 downto 0);
		out_5   	: out  std_logic_vector(15 downto 0);
		out_6   	: out  std_logic_vector(15 downto 0);
		out_7   	: out  std_logic_vector(15 downto 0);
		out_8   	: out  std_logic_vector(15 downto 0);
		out_9   	: out  std_logic_vector(15 downto 0);
		out_10   	: out  std_logic_vector(15 downto 0);
		out_11   	: out  std_logic_vector(15 downto 0);
		out_12   	: out  std_logic_vector(15 downto 0);
		out_13   	: out  std_logic_vector(15 downto 0);
		out_14   	: out  std_logic_vector(15 downto 0);
		out_15   	: out  std_logic_vector(15 downto 0)
  );
end component;
--time delta for waiting between test inputs
constant TIME_DELTA : time := 100 ns;

-- demux PORTS
  signal SEL : std_logic_vector(3 downto 0);
  signal data_in : std_logic_vector(15 downto 0);

  signal out_0 : std_logic_vector(15 downto 0);
  signal out_1 : std_logic_vector(15 downto 0);
  signal out_2 : std_logic_vector(15 downto 0);
  signal out_3 : std_logic_vector(15 downto 0);
  signal out_4 : std_logic_vector(15 downto 0);
  signal out_5 : std_logic_vector(15 downto 0);
  signal out_6 : std_logic_vector(15 downto 0);
  signal out_7 : std_logic_vector(15 downto 0);
  signal out_8 : std_logic_vector(15 downto 0);
  signal out_9 : std_logic_vector(15 downto 0);
  signal out_10 : std_logic_vector(15 downto 0);
  signal out_11 : std_logic_vector(15 downto 0);
  signal out_12 : std_logic_vector(15 downto 0);
  signal out_13 : std_logic_vector(15 downto 0);
  signal out_14 : std_logic_vector(15 downto 0);
  signal out_15 : std_logic_vector(15 downto 0);
  
  begin
    
    dut : entity work.demux_16
      port map(
        sel => SEL,
        data_in => data_in,
        out_0 => out_0,
        out_1 => out_1,
        out_2 => out_2,
        out_3 => out_3,
        out_4 => out_4,
        out_5 => out_5,
        out_6 => out_6,
        out_7 => out_7,
        out_8 => out_8,
        out_9 => out_9,
        out_10 => out_10,
        out_11 => out_11,
        out_12 => out_12,
        out_13 => out_13,
        out_14 => out_14,
        out_15 => out_15
        );
        
    simulation : process
    begin
    -- 
      sel <= "0000"; -- 
      data_in <= "0101010101010101"; -- 
      wait for TIME_DELTA;
      
      sel <= "0001"; -- 
      data_in <= "1111000011110000"; -- 
      wait for TIME_DELTA;
      
      sel <= "0010"; -- 
      data_in <= "0000000011111111"; -- 
      wait for TIME_DELTA;
      
      sel <= "1110"; -- 
      data_in <= "0000000000000000"; -- 
      wait for TIME_DELTA;
      
    end process simulation;

end architecture test;
