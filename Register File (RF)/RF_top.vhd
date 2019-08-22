library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.arrays.ALL;
use work.control_unit_types.all;
use work.RF_top_functions.all;

entity RF_top is
   port ( 
		--Input data and clock
		clk 			: in std_logic;
		WB_data_in	: in std_logic_vector(15 downto 0);
		IW_in			: in std_logic_vector(15 downto 0);
		ROB_in		: in ROB;

		--Control signals
		reset_n			: in std_logic; --all registers reset to 0 when this goes low
		wr_en 			: in std_logic; --(WB) enables write for the selected register
		RF_out_1_mux, RF_out_2_mux		: in std_logic_vector(4 downto 0);	--controls first output mux
		RF_out_3_mux, RF_out_4_mux		: in std_logic_vector(4 downto 0);	--muxes used by LAB in CU for branch determination
		RF_out_1_en, RF_out_2_en		: in std_logic;
		RF_out_3_en, RF_out_4_en		: in std_logic;
		RF_in_demux		: in std_logic_vector(4 downto 0);	--(WB) controls which register to write data to
		RF_revalidate	: in std_logic_vector(31 downto 0);

		--Outputs
		RF_out_1, RF_out_2	: out std_logic_vector(15 downto 0);
		RF_out_3, RF_out_4	: out std_logic_vector(15 downto 0);
		RF_out_3_valid			: out std_logic;
		RF_out_4_valid			: out std_logic
	);
end RF_top;

architecture behavioral of RF_top is

	signal RF							: array_32_16;
	signal RF_valid					: std_logic_vector(31 downto 0);			
	signal in_index					: integer range 0 to 31;
	signal out1_index, out2_index	: integer range 0 to 31;
	signal out3_index, out4_index	: integer range 0 to 31;
	signal store_inst					: std_logic;

begin
	store_inst		<= IW_in(15) and not(IW_in(14)) and not(IW_in(13)) and not(IW_in(12)) and IW_in(1);
	
	--process to write back results to RF
	--process(reset_n, clk, wr_en, RF_in_demux, RF_out_1_en, RF_out_2_en, RF_out_3_en, RF_out_4_en, RF_out_1_mux, RF_out_2_mux, RF_out_3_mux, RF_out_4_mux)
	process(reset_n, clk)
	begin
	
		--type conversion for RF index
		in_index <= to_integer(unsigned(RF_in_demux));
		
		if reset_n = '0' then
			RF 			<= (others => (others => '0'));
			RF_valid 	<= (others => '1');
			
		elsif rising_edge(clk) then
		
			if wr_en = '1' then
				--have a write back event from WB block
				RF(in_index) 	<= WB_data_in;
			end if;
			
			for i in 0 to 31 loop
				--only declare a register "valid" if it is written back and no instruction is requesting that register concurrently
				
				if RF_revalidate /= "00000000000000000000000000000000" then
				--then we had a failed branch - this signal will re-validate all necessary registers that were incorrectly fetched
					RF_valid <= RF_valid or RF_revalidate;
					RF_valid(to_integer(unsigned(RF_in_demux))) 	<= '1';
				
				elsif RF_out_1_en = '1' and to_integer(unsigned(RF_out_1_mux)) = i and store_inst = '0' then
					RF_valid(i) 	<= '0';
					--report "RF: setting RF(" & Integer'image(i) & ").valid to '0'";
				
				--Not sure what this case was intended for.
--				elsif RF_out_2_en = '1' and to_integer(unsigned(RF_out_2_mux)) = i and store_inst = '0' then
--					RF_valid(i) 	<= '0';
--					--report "RF: setting RF(" & Integer'image(i) & ").valid to '0'";

				elsif wr_en = '1' then
					if to_integer(unsigned(RF_in_demux)) = i and to_integer(unsigned(RF_out_1_mux)) = i and RF_out_1_en = '1' then
						RF_valid(i) 	<= '0';
						--report "RF: setting RF(" & Integer'image(i) & ").valid to '0'";
					elsif to_integer(unsigned(RF_in_demux)) = i and to_integer(unsigned(RF_out_2_mux)) = i  and RF_out_2_en = '1' then
						RF_valid(i) 	<= '0';
						--report "RF: setting RF(" & Integer'image(i) & ").valid to '0'";
					elsif to_integer(unsigned(RF_in_demux)) = i then 
						--report "RF: setting RF(" & Integer'image(i) & ").valid to '1'";
						RF_valid(i) 	<= '1';
					else
						RF_valid(i)		<= RF_valid(i);
						--report "RF: setting RF(" & Integer'image(i) & ").valid to RF(" & Integer'image(i) & ").valid";
					end if;
				
				end if;
			end loop;
			
		end if;
	end process;
	
	--DO NOT MERGE THIS WITH THE LATCHING PROCESS BELOW THESE PERFORM TWO DIFFERENT FUNCTIONS
	--combinational process to read RF outputs for LAB
	process(reset_n, clk, RF_out_3_en, RF_out_4_en, RF_out_3_mux, RF_out_4_mux, RF_in_demux, wr_en, WB_data_in, RF, out3_index, out4_index, RF_valid)
	begin
	
		--type conversion for RF index
		out3_index <= to_integer(unsigned(RF_out_3_mux));
		out4_index <= to_integer(unsigned(RF_out_4_mux));
		
		if reset_n = '0' then
			RF_out_3 <= "0000000000000000";
			RF_out_4 <= "0000000000000000";
			RF_out_3_valid 	<= '1';
			RF_out_4_valid 	<= '1';
			
		--TEST CONDITION
		elsif rising_edge(clk) then
		--else
		
			--latch outputs
			if RF_in_demux = RF_out_3_mux and wr_en = '1' then
			
				RF_out_3_valid 	<= '1';
				
				if (RF_out_3_en = '1') then
					RF_out_3 		<= WB_data_in;
				end if;
			else
				if (RF_out_3_en = '1') then
					RF_out_3 			<= RF(out3_index);
					RF_out_3_valid 	<= RF_valid(out3_index);
				end if;
			end if;
			
			if RF_in_demux = RF_out_4_mux and wr_en = '1' then
			
				RF_out_4_valid 	<= '1';
				
				if (RF_out_4_en = '1') then
					RF_out_4 		<= WB_data_in;
				end if;
			else
				if (RF_out_4_en = '1') then
					RF_out_4 		<= RF(out4_index);
					RF_out_4_valid 	<= RF_valid(out4_index);
				end if;
			end if;
			
		end if; --reset_n
	end process;
	
	--DO NOT MERGE THIS WITH THE COMBINATIONAL PROCESS ABOVE, THESE PERFORM TWO DIFFERENT FUNCTIONS
	--latching process to read RF outputs for ALU
	process(reset_n, clk, RF_out_1_en, RF_out_2_en, RF_out_1_mux, RF_out_2_mux)
	begin
	
		--type conversion for RF index
		out1_index 	<= to_integer(unsigned(RF_out_1_mux));
		out2_index 	<= to_integer(unsigned(RF_out_2_mux));
		
		if reset_n = '0' then
			RF_out_1 <= "0000000000000000";
			RF_out_2 <= "0000000000000000";
			
		elsif rising_edge(clk) then
		
			--latch outputs
			if RF_complete_in_ROB(ROB_in, RF_out_1_mux) = '0' then
				report "RF_top: reg1 found/found complete in ROB.";
				--ORIGINAL CODE----------------
				if RF_in_demux = RF_out_1_mux and wr_en = '1' then
					if (RF_out_1_en = '1') then
						RF_out_1 	<= WB_data_in;
					end if;
				else
					if (RF_out_1_en = '1') then
						RF_out_1 	<= RF(out1_index);
					end if;
				end if;
				--END ORIGINAL CODE----------------
			else
				report "RF_top: reg1 found complete in ROB.";
				RF_out_1 	<= get_RF_data_from_ROB(ROB_in, RF_out_1_mux);
			end if;
			
			if RF_complete_in_ROB(ROB_in, RF_out_2_mux) = '0' then
				report "RF_top: reg2 not found/found complete in ROB.";
				--ORIGINAL CODE----------------
				if RF_in_demux = RF_out_2_mux and wr_en = '1' then
					if (RF_out_2_en = '1') then
						RF_out_2 	<= WB_data_in;
					end if;
				else
					if (RF_out_2_en = '1') then
						RF_out_2 	<= RF(out2_index);
					end if;
				end if;
				--END ORIGINAL CODE----------------
			else
				report "RF_top: reg2 found complete in ROB.";
				RF_out_2 	<= get_RF_data_from_ROB(ROB_in, RF_out_2_mux);
			end if;
			
		end if; --reset_n
	end process;
	
end behavioral;