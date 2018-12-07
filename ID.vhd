--Written by: Joe Post

--This file receives an IW from the IF stage and decodes it and retrieves the operands from the RF
--This file will not contain the RF however. That is located in the highest level Control Unit block.


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ID is
   port ( 
		--Input data and clock
		reset_n, sys_clock	: in std_logic;	
		IW							: in std_logic_vector(15 downto 0);
		stall_in					: in std_logic;		--set high when an upstream CU block needs this 
		
		--Control
		wr_en 			: out std_logic; 							--enables write for a selected register
		RF_out_1_mux	: out std_logic_vector(4 downto 0);	--controls first output mux
		RF_out_2_mux	: out std_logic_vector(4 downto 0);	--controls second output mux
		B_bus_out1_en, C_bus_out1_en		: out std_logic; --enables RF_out_1 on B and C bus
		B_bus_out2_en, C_bus_out2_en		: out std_logic; --enables RF_out_2 on B and C bus
		
		--Outputs
		stall_out		: out std_logic;
		immediate_val	: out	std_logic_vector(15 downto 0)--represents various immediate values from various OpCodes
	);
end ID;

architecture behavioral of ID is

	signal RF_out_1_mux_reg, RF_out_2_mux_reg	: std_logic_vector(4 downto 0)	:= "00000";
	signal immediate_val_reg	: std_logic_vector(15 downto 0);
	
begin
	process(reset_n, sys_clock)
	begin
		if reset_n = '0' then
			wr_en <= '0';
			RF_out_1_mux_reg <= "00000";	--arbitrarily select RF(0), which is a reserved all-zero register
			RF_out_2_mux_reg <= "00000";
			
		elsif rising_edge(sys_clock) then
		
			if stall_in = '0' then
				RF_out_1_mux_reg <= IW(11 downto 7);	--assert reg1 address if there's no stall
				RF_out_2_mux_reg <= IW(6 downto 2);		--
				
			elsif stall_in = '1' then
				RF_out_1_mux_reg <= RF_out_1_mux_reg;	--if we get a stall signal, latch current value
				RF_out_2_mux_reg <= RF_out_2_mux_reg;	--
				
			end if; --stall_in
		
			--calculate immediate value, based on IW(15 downto 12), only for LD, ST, JMP
			--LD/ST
			if IW(15 downto 12) = "100X" and IW(1 downto 0) = "1X" then
				immediate_val_reg <= "00000000000" & IW(6 downto 2);
				
			--JMP
			elsif IW(15 downto 12) = "1100" and IW(1 downto 0) = "1X" then
				immediate_val_reg <= "000000" & IW(11 downto 2);
				
			end if; --IW
		end if; --reset_n
	end process;
	
	--latch inputs
	
	--latch outputs
	RF_out_1_mux 	<= RF_out_1_mux_reg;		--
	RF_out_2_mux 	<= RF_out_2_mux_reg;
	immediate_val 	<= immediate_val_reg;
	
end behavioral;