library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity RF is
  port (
    --Input data and clock
	 RF_in 	: in std_logic_vector(15 downto 0);
	 clk 		: in std_logic;
	 
	 --Control signals
	 reset_n	: in std_logic; --all registers reset to 0 when this goes low
	 wr_en 	: in std_logic; --enables write for a selected register
	 RF_out_1_mux	: in std_logic_vector(3 downto 0);	--controls first output mux
	 RF_out_2_mux	: in std_logic_vector(3 downto 0);	--controls second output mux
	 RF_in_demux	: in std_logic_vector(3 downto 0);	--controls which register to write data to
	 
    --Outputs
    RF_out_1   : out std_logic_vector(15 downto 0);
    RF_out_2 	: out std_logic_vector(15 downto 0)
    );
end RF;
 
architecture behavioral of RF is
	--Actual Register File register type declaration:
	type RegFile is array (31 downto 0) of std_logic_vector(15 downto 0);
	
	--create variable of type RegFile, this is the actual register file
	signal RF 	:	RegFile := (others => (others => '0'));
	
	--Create wires to connect the input mux outputs to the RF inputs
	signal RF_in_wire		: RegFile;
	
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
	
	component demux_16 is
	port ( 
		sel 		: in  std_logic_vector(3 downto 0);
		data_in  : in std_logic_vector(15 downto 0);
		
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
		out_10   : out  std_logic_vector(15 downto 0);
		out_11   : out  std_logic_vector(15 downto 0);
		out_12   : out  std_logic_vector(15 downto 0);
		out_13   : out  std_logic_vector(15 downto 0);
		out_14   : out  std_logic_vector(15 downto 0);
		out_15   : out  std_logic_vector(15 downto 0)
		);
	end component demux_16;

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
	--Second output mux - takes all RF outputs to RF_out_2	
	out_2_mux : mux_16
   port map (
      sel  => RF_out_2_mux,
		
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
		
		sig_out => RF_out_2
      );

	--Input demux - takes all RF block inputs to RF
	
	input_demux	: demux_16
	port map (
		sel 		=> RF_in_demux,
		data_in  => RF_in,
		
		out_0   	=> RF_in_wire(0),
		out_1   	=> RF_in_wire(1),
		out_2   	=> RF_in_wire(2),
		out_3   	=> RF_in_wire(3),
		out_4   	=> RF_in_wire(4),
		out_5   	=> RF_in_wire(5),
		out_6   	=> RF_in_wire(6),
		out_7   	=> RF_in_wire(7),
		out_8   	=> RF_in_wire(8),
		out_9   	=> RF_in_wire(9),
		out_10   => RF_in_wire(10),
		out_11   => RF_in_wire(11),
		out_12   => RF_in_wire(12),
		out_13   => RF_in_wire(13),
		out_14   => RF_in_wire(14),
		out_15   => RF_in_wire(15)
	);
		
	process(reset_n, clk, RF_in_demux, RF_in, wr_en)
	begin
	if reset_n = '0' then
		RF <= (others => (others => '0'));
	elsif clk'event and clk = '1' then
		if RF_in_demux = "0000" and wr_en = '1' then
			RF(0) <= RF_in_wire(0);
		elsif RF_in_demux = "0001" and wr_en = '1' then
			RF(1) <= RF_in_wire(1);
		elsif RF_in_demux = "0010" and wr_en = '1' then
			RF(2) <= RF_in_wire(2);
		elsif RF_in_demux = "0011" and wr_en = '1' then
			RF(3) <= RF_in_wire(3);
		elsif RF_in_demux = "0100" and wr_en = '1' then
			RF(4) <= RF_in_wire(4);
		elsif RF_in_demux = "0101" and wr_en = '1' then
			RF(5) <= RF_in_wire(5);
		elsif RF_in_demux = "0110" and wr_en = '1' then
			RF(6) <= RF_in_wire(6);
		elsif RF_in_demux = "0111" and wr_en = '1' then
			RF(7) <= RF_in_wire(7);
		elsif RF_in_demux = "1000" and wr_en = '1' then
			RF(8) <= RF_in_wire(8);
		elsif RF_in_demux = "1001" and wr_en = '1' then
			RF(9) <= RF_in_wire(9);
		elsif RF_in_demux = "1010" and wr_en = '1' then
			RF(10) <= RF_in_wire(10);
		elsif RF_in_demux = "1011" and wr_en = '1' then
			RF(11) <= RF_in_wire(11);
		elsif RF_in_demux = "1100" and wr_en = '1' then
			RF(12) <= RF_in_wire(12);
		elsif RF_in_demux = "1101" and wr_en = '1' then
			RF(13) <= RF_in_wire(13);
		elsif RF_in_demux = "1110" and wr_en = '1' then
			RF(14) <= RF_in_wire(14);
		elsif RF_in_demux = "1111" and wr_en = '1' then
			RF(15) <= RF_in_wire(15);
		else --so if wr_en is 0 basically, then we don't want to write to RF
			RF <= RF;
		end if; -- RF select statements
	end if; -- clock
	end process;
		
end behavioral;