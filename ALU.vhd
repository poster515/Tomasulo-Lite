library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity ALU is
  port (
    --Input data and clock
	 clk 				: in std_logic;
	 RF_data_in_1 	: in std_logic_vector(15 downto 0);
	 RF_data_in_2 	: in std_logic_vector(15 downto 0);
	 WB_data			: in std_logic_vector(15 downto 0); --this data will be forwarded from the WB stage 
	 Adtl_data_2	: in std_logic_vector(15 downto 0); --currently unused, this is another opportunity to 
																		--forward data to ALU input 2
	 --Control signals
	 reset_n			: in std_logic; --all registers reset to 0 when this goes low
	 ALU_op			: in std_logic_vector(3 downto 0); --dictates ALU operation
	 data_2_mux_sel		: in std_logic(1 downto 0); --used to control which data to send to ALU input 2
	 ALU_out_reg_wr_en 	: in std_logic; --used to enable latching data into ALU output register
	 ALU_OReg_mux_sel		: in std_logic; --used to select which input to latch into ALU output register
													 --0=ALU result 1=data forwarded from RF_data_in_1
    --Outputs
    ALU_out   		: out std_logic_vector(15 downto 0); --latched output register
	 ALU_out_fwd   : out std_logic_vector(15 downto 0); --
    ALU_status 	: out std_logic_vector(3 downto 0)
    );
end ALU;
 
architecture behavioral of ALU is

	--Create wires to connect the input mux outputs to the RF inputs
	--signal RF_in_wire		: RegFile;
	
	--import mux and demux
	component mux_16 is
		port (
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
			
			sig_out  : out std_logic_vector(15 downto 0)
			);
	end component mux_16;

begin
	--First output mux - takes all RF outputs to RF_out_1
	out_1_mux : mux_16
   port map (
      sel  => RF_out_1_mux,
		
      in_0  => RF(0),
		in_1  => RF(1),
		in_2  => RF(2),
		in_3  => RF(3),
		in_4  => RF(4),
		in_5  => RF(5),
		in_6  => RF(6),
		in_7  => RF(7),
		in_8  => RF(8),
		in_9  => RF(9),
		in_10  => RF(10),
		in_11  => RF(11),
		in_12  => RF(12),
		in_13  => RF(13),
		in_14  => RF(14),
		in_15  => RF(15),
		
		sig_out => RF_out_1
      );
	process(reset_n, clk, ALU_op)
	begin
	if reset_n = '0' then
		RF <= (others => (others => '0'));
	elsif clk'event and clk = '1' then

	end if; -- clock
	end process;
		
end behavioral;