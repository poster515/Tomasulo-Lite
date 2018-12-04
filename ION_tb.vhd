library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--import RF entity
entity ION_tb is
end ION_tb;

architecture test of ION_tb is
--import ALU
component ION
  port(
   --Input data and clock
	 clk 			    : in std_logic;
	 digital_in	: in std_logic_vector(15 downto 0);
	 
	 --Control signals
	 reset_n	 : in std_logic; --all registers reset to 0 when this goes low
	 wr_en 	  : in std_logic; --enables write for a selected register
	 A_bus_out_sel, B_bus_out_sel	: in std_logic; --enables A or B bus onto output_buffer
	 A_bus_in_sel, B_bus_in_sel		 : in std_logic; --enables input_buffer on A or B bus
	 
   --Outputs
   digital_out			: out std_logic_vector(15 downto 0); --needs to be inout to support future reading of outputs
	 A_bus, B_bus		 : inout std_logic_vector(15 downto 0);
	 
	 --Input/Outputs
	 I2C_sda, I2C_scl	: inout std_logic
	);
end component;

--time delta for waiting between test inputs
constant TIME_DELTA : time := 100 ns;

-- test signals here, map identically to EUT
signal digital_in, digital_out  : std_logic_vector(15 downto 0); --ALU data inputs
signal A_bus, B_bus             : std_logic_vector(15 downto 0); --ALU data inputs
signal A_bus_out_sel, B_bus_out_sel	: std_logic; --enables A or B bus onto output_buffer
signal A_bus_in_sel, B_bus_in_sel		 : std_logic; --enables input_buffer on A or B bus
signal clk, reset_n, wr_en      : std_logic := '0';               -- initialize to 0;
signal I2C_scl, I2C_sda         : std_logic;	--controls ALU function

  begin
    
    dut : entity work.ION
      port map(
        --Input data and clock
        clk 			       => clk,
        digital_in	   => digital_in,
	 
        --Control signals
        reset_n	      => reset_n,       --all registers reset to 0 when this goes low
        wr_en 	       => wr_en,         --enables write for a selected register
        A_bus_out_sel => A_bus_out_sel, 
        B_bus_out_sel	=> B_bus_out_sel, --enables A or B bus onto output_buffer
        A_bus_in_sel  => A_bus_in_sel, 
        B_bus_in_sel	 => B_bus_in_sel,  --enables input_buffer on A or B bus
	 
        --Outputs
        digital_out   => digital_out, --needs to be inout to support future reading of outputs
        A_bus         => A_bus, 
        B_bus		       => B_bus,
	 
        --Input/Outputs
        I2C_sda       => I2C_sda, 
        I2C_scl	      => I2C_scl
      );
      
    clk <=  '1' after TIME_DELTA / 2 when clk = '0' else
            '0' after TIME_DELTA / 2 when clk = '1'; 
        
    simulation : process
    begin
      --initialize all registers, and wait a few clocks
      reset_n <= '0';
      wr_en   <= '0';
      digital_in <= "0000000000000000";
      wait for TIME_DELTA * 2;
      
      reset_n <= '1';
      
      -- write to digital outputs
      
      wait for TIME_DELTA;
      
      -- read digital inputs
      
      wait for TIME_DELTA;

    end process simulation;

end architecture test;


