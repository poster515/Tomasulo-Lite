library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--import demux entity
entity demux_16_tb is
end demux_16_tb;

architecture test of demux_16_tb is
--import demux_16
component mux_16
  port(
    sel 		: in  std_logic_vector(3 downto 0);
		
		in_0   	: in  std_logic_vector(15 downto 0);
		in_1   	: in  std_logic_vector(15 downto 0);
		in_2   	: in  std_logic_vector(15 downto 0);
		in_3   	: in  std_logic_vector(15 downto 0);
		in_4   	: in  std_logic_vector(15 downto 0);
		in_5   	: in  std_logic_vector(15 downto 0);
		in_6   	: in  std_logic_vector(15 downto 0);
		in_7   	: in  std_logic_vector(15 downto 0);
		in_8   	: in  std_logic_vector(15 downto 0);
		in_9   	: in  std_logic_vector(15 downto 0);
		in_10   	: in  std_logic_vector(15 downto 0);
		in_11   	: in  std_logic_vector(15 downto 0);
		in_12   	: in  std_logic_vector(15 downto 0);
		in_13   	: in  std_logic_vector(15 downto 0);
		in_14   	: in  std_logic_vector(15 downto 0);
		in_15   	: in  std_logic_vector(15 downto 0);
		
		sig_out  	: out std_logic_vector(15 downto 0)
  );
end component;
--time delta for waiting between test inputs
constant TIME_DELTA : time := 100 ns;

-- demux PORTS
  signal sel : std_logic_vector(3 downto 0);
  signal sig_out : std_logic_vector(15 downto 0);

  signal in_0 : std_logic_vector(15 downto 0);
  signal in_1 : std_logic_vector(15 downto 0);
  signal in_2 : std_logic_vector(15 downto 0);
  signal in_3 : std_logic_vector(15 downto 0);
  signal in_4 : std_logic_vector(15 downto 0);
  signal in_5 : std_logic_vector(15 downto 0);
  signal in_6 : std_logic_vector(15 downto 0);
  signal in_7 : std_logic_vector(15 downto 0);
  signal in_8 : std_logic_vector(15 downto 0);
  signal in_9 : std_logic_vector(15 downto 0);
  signal in_10 : std_logic_vector(15 downto 0);
  signal in_11 : std_logic_vector(15 downto 0);
  signal in_12 : std_logic_vector(15 downto 0);
  signal in_13 : std_logic_vector(15 downto 0);
  signal in_14 : std_logic_vector(15 downto 0);
  signal in_15 : std_logic_vector(15 downto 0);
  
  begin
    
    dut : entity work.mux_16
      port map(
        sel => sel,
        in_0 => in_0,
        in_1 => in_1,
        in_2 => in_2,
        in_3 => in_3,
        in_4 => in_4,
        in_5 => in_5,
        in_6 => in_6,
        in_7 => in_7,
        in_8 => in_8,
        in_9 => in_9,
        in_10 => in_10,
        in_11 => in_11,
        in_12 => in_12,
        in_13 => in_13,
        in_14 => in_14,
        in_15 => in_15,
        sig_out => sig_out
        );
        
    simulation : process
    begin
    -- 
      sel <= "1100"; -- 
      in_12 <= "0101010101010101"; -- 
      wait for TIME_DELTA;
      
      sel <= "0001"; -- 
      in_1 <= "1111000011110000"; -- 
      wait for TIME_DELTA;
      
      sel <= "0010"; -- 
      in_2 <= "0000000011111111"; -- 
      wait for TIME_DELTA;
      
      sel <= "1110"; -- 
      in_14 <= "0000000000000000"; -- 
      wait for TIME_DELTA;
      
    end process simulation;

end architecture test;

