--Written by: Joe Post

--This file receives an IW from the IF stage and decodes it and retrieves the operands from the RF
--This file will not contain the RF however. 


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ID is
   port ( 
		--Input data and clock
		reset_n, sys_clock	: in std_logic;	
		IW_in						: in std_logic_vector(15 downto 0);
		LAB_stall_in			: in std_logic;
		WB_stall_in				: in std_logic;		--set high when an upstream CU block needs this 
		MEM_stall_in			: in std_logic;
		EX_stall_in				: in std_logic;
		mem_addr_in				: in std_logic_vector(15 downto 0);
		ALU_fwd_reg_1_in		: in std_logic;		--input to tell EX stage to forward MEM_out data in to ALU_in_1
		ALU_fwd_reg_2_in		: in std_logic;		--input to tell EX stage to forward MEM_out data in to ALU_in_2
		
		--Control							
		RF_out_1_mux	: out std_logic_vector(4 downto 0);	--controls first output mux
		RF_out_2_mux	: out std_logic_vector(4 downto 0);	--controls second output mux
		RF_out1_en, RF_out2_en		: out std_logic; --enables RF_out_X on B and C bus
		
		--Outputs
		IW_out			: out std_logic_vector(15 downto 0); --goes to EX control unit
		stall_out		: out std_logic;
		immediate_val	: out	std_logic_vector(15 downto 0); --represents various immediate values from various OpCodes
		mem_addr_out	: out std_logic_vector(15 downto 0);  --
		reset_out		: out std_logic;
		ALU_fwd_reg_1_out	: out std_logic;
		ALU_fwd_reg_2_out	: out std_logic
	);
end ID;

architecture behavioral of ID is

	signal RF_out_1_mux_reg, RF_out_2_mux_reg	: std_logic_vector(4 downto 0)	:= "00000";
	signal mem_addr_reg, immediate_val_reg		: std_logic_vector(15 downto 0);
	signal stall_in									: std_logic := '0'; --combinationally calculated stall signal
	signal reset_reg									: std_logic := '0';
	
begin

	stall_in <= LAB_stall_in or WB_stall_in or MEM_stall_in or EX_stall_in; --'1' if any stall signal is '1', '0' if all stalls are '0'

	process(reset_n, sys_clock)
	begin
		if reset_n = '0' then
			RF_out_1_mux_reg <= "00000";	--arbitrarily select RF(0), which is a reserved all-zero register
			RF_out_2_mux_reg <= "00000";
			IW_out <= "0000000000000000";
			RF_out1_en <= '0'; 
			RF_out2_en <= '0';
			mem_addr_reg <= "0000000000000000";
			immediate_val_reg <= "0000000000000000";
			reset_reg <= '0';
			stall_out <= '0';
			ALU_fwd_reg_1_out <= '0';	
			ALU_fwd_reg_2_out <= '0';
			
		elsif rising_edge(sys_clock) then
		
			reset_reg <= '1';
			
			if stall_in = '0' then
			
				stall_out <= '0';
				
				ALU_fwd_reg_1_out <= ALU_fwd_reg_1_in;	--just forward these inputs
				ALU_fwd_reg_2_out <= ALU_fwd_reg_2_in;	
				
				RF_out_1_mux_reg <= IW_in(11 downto 7);	--assert reg1 address if there's no stall
				RF_out_2_mux_reg <= IW_in(6 downto 2);		--assert reg2 address if there's no stall
				
				--for all rotates (0101), shifts (0110, 0111), jumps (1001), loads (1000...01), and GPIO/I2C reads (1011..X0) don't need any RF output
				if IW_in(15 downto 12) = "1001" or 
					(IW_in(15 downto 12) = "1000" and IW_in(1 downto 0) = "01") or
					(IW_in(15 downto 12) = "1011" and IW_in(1 downto 0) = "X0") or 
					IW_in(15 downto 12) = "0101" or IW_in(15 downto 12) = "0110" or 
						IW_in(15 downto 12) = "0111" then 
					
					RF_out1_en <= '0'; 
					RF_out2_en <= '0';
				
				--for BNEZ (1010...00), loads (1000...00), stores (1000...11), GPIO/I2C writes (1011..X1), LOGI (1100) only need 1 RF output
				elsif (IW_in(15 downto 12) = "1010" and IW_in(1 downto 0) = "00") or
						(IW_in(15 downto 12) = "1000" and (IW_in(1 downto 0) = "00" or IW_in(1 downto 0) = "11")) or
						(IW_in(15 downto 12) = "1011" and IW_in(1 downto 0) = "X1") or IW_in(15 downto 12) = "1100" then
					RF_out1_en <= '1'; 
					RF_out2_en <= '0';
					
				--for all other instructions, need both RF outputs
				else
					RF_out1_en <= '1'; 
					RF_out2_en <= '1';
					
				end if;
				
				--calculate immediate value, based on IW(15 downto 12), only for LD/ST (1000), JMP (1001)
				--not sure need to use inst_sel since calculating this immediate value doesn't impact anything else
				--LD/ST
				if IW_in(15 downto 12) = "1000" and IW_in(0) = '1' then
					immediate_val_reg <= "00000000000" & IW_in(6 downto 2);
					mem_addr_reg 		<= mem_addr_in;
					
				--JMP
				elsif IW_in(15 downto 12) = "1001" then
					immediate_val_reg <= "000000" & IW_in(11 downto 2);
					
				--ADDI (0000..10), SUBI (0001..10), MULTI (0010..10), DIVI (0011..10), LOGI (1100)
				elsif (IW_in(15 downto 14) = "00" and IW_in(1 downto 0) = "10") or IW_in(15 downto 12) = "1100" then
						
					immediate_val_reg <= "00000000000" & IW_in(6 downto 2);
					
				end if; --IW_in
				
				IW_out <= IW_in;	--forward IW to EX stage
				
			elsif stall_in = '1' then
				RF_out_1_mux_reg <= RF_out_1_mux_reg;	--if we get a stall signal, latch current value
				RF_out_2_mux_reg <= RF_out_2_mux_reg;	--
				
				RF_out1_en <= '0'; 
				RF_out2_en <= '0'; 
				
				stall_out <= '1';
				
			end if; --stall_in
		end if; --reset_n
	end process;
	
	--latch inputs
	
	--latch outputs
	RF_out_1_mux 	<= RF_out_1_mux_reg;		--
	RF_out_2_mux 	<= RF_out_2_mux_reg;
	immediate_val 	<= immediate_val_reg;
	mem_addr_out	<= mem_addr_reg;
	reset_out		<= reset_reg;
	
end behavioral;