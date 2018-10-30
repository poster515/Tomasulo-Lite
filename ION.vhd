library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity ION is
  port (
   --Input data and clock
	clk 			: in std_logic;
	digital_in	: in std_logic_vector(15 downto 0);
	 
	--Control signals
	reset_n	: in std_logic; --all registers reset to 0 when this goes low
	wr_en 	: in std_logic; --enables write for a selected register
	A_bus_out_sel, B_bus_out_sel	: in std_logic; --enables A or B bus onto output_buffer
	A_bus_in_sel, B_bus_in_sel		: in std_logic; --enables input_buffer on A or B bus
	 
   --Outputs
   digital_out			: out std_logic_vector(15 downto 0); --needs to be inout to support future reading of outputs
	A_bus, B_bus		: inout std_logic_vector(15 downto 0);
	 
	--Input/Outputs
	I2C_sda, I2C_scl	: inout std_logic
   );
end ION;
 
architecture behavioral of ION is

signal input_buffer, output_buffer	: std_logic_vector(15 downto 0);

begin
		
	--process to constantly check the wr_en signal and B_bus and C_bus inputs selects
	--such that we can buffer the incoming output data and write to the output buffer
	digital_out <= output_buffer;
	
	process(reset_n, clk, wr_en)
	begin
		if reset_n = '0' then
			input_buffer 	<= "0000000000000000";
			
		elsif clk'event and clk = '1' then
			input_buffer <= digital_in; -- read inputs every clock cycle

			if (A_bus_out_sel = '1' and wr_en = '1') then
				output_buffer <= A_bus;
			
			elsif (B_bus_out_sel = '1' and wr_en = '1') then
				output_buffer <= B_bus;
				
			elsif (A_bus_in_sel = '1') then
				A_bus <= input_buffer;
				
			elsif (B_bus_in_sel = '1') then
				B_bus <= input_buffer;
			
			else
				A_bus <= "ZZZZZZZZZZZZZZZZ";
				B_bus <= "ZZZZZZZZZZZZZZZZ";
			end if; --bus select
		end if; -- clock
	end process;
end behavioral;