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
	 RF_out_1_mux	: in std_logic_vector(4 downto 0);	--controls first output mux
	 RF_out_2_mux	: in std_logic_vector(4 downto 0);	--controls second output mux
	 RF_in_demux	: in std_logic_vector(4 downto 0);	--controls which register to write data to
	 
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
	component mux_32 is
		port (
			sel 		: in  std_logic_vector(4 downto 0);
			
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
			in_16   	: in  std_logic_vector(15 downto 0);
			in_17   	: in  std_logic_vector(15 downto 0);
			in_18   	: in  std_logic_vector(15 downto 0);
			in_19   	: in  std_logic_vector(15 downto 0);
			in_20   	: in  std_logic_vector(15 downto 0);
			in_21   	: in  std_logic_vector(15 downto 0);
			in_22   	: in  std_logic_vector(15 downto 0);
			in_23   	: in  std_logic_vector(15 downto 0);
			in_24   	: in  std_logic_vector(15 downto 0);
			in_25   	: in  std_logic_vector(15 downto 0);
			in_26   	: in  std_logic_vector(15 downto 0);
			in_27   	: in  std_logic_vector(15 downto 0);
			in_28   	: in  std_logic_vector(15 downto 0);
			in_29   	: in  std_logic_vector(15 downto 0);
			in_30   	: in  std_logic_vector(15 downto 0);
			in_31   	: in  std_logic_vector(15 downto 0);
			
			sig_out  : out std_logic_vector(15 downto 0)
			);
	end component mux_32;
	
	component demux_32 is
	port ( 
		sel 		: in  std_logic_vector(4 downto 0);
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
		out_15   : out  std_logic_vector(15 downto 0);
		out_16   : out  std_logic_vector(15 downto 0);
		out_17   : out  std_logic_vector(15 downto 0);
		out_18   : out  std_logic_vector(15 downto 0);
		out_19   : out  std_logic_vector(15 downto 0);
		out_20   : out  std_logic_vector(15 downto 0);
		out_21   : out  std_logic_vector(15 downto 0);
		out_22   : out  std_logic_vector(15 downto 0);
		out_23   : out  std_logic_vector(15 downto 0);
		out_24   : out  std_logic_vector(15 downto 0);
		out_25   : out  std_logic_vector(15 downto 0);
		out_26   : out  std_logic_vector(15 downto 0);
		out_27   : out  std_logic_vector(15 downto 0);
		out_28   : out  std_logic_vector(15 downto 0);
		out_29   : out  std_logic_vector(15 downto 0);
		out_30   : out  std_logic_vector(15 downto 0);
		out_31   : out  std_logic_vector(15 downto 0)
		);
	end component demux_32;

begin
	--First output mux - takes all RF outputs to RF_out_1
	out_1_mux : mux_32
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
		in_16  => RF(16),
		in_17  => RF(17),
		in_18  => RF(18),
		in_19  => RF(19),
		in_20  => RF(20),
		in_21  => RF(21),
		in_22  => RF(22),
		in_23  => RF(23),
		in_24  => RF(24),
		in_25  => RF(25),
		in_26  => RF(26),
		in_27  => RF(27),
		in_28  => RF(28),
		in_29  => RF(29),
		in_30  => RF(30),
		in_31  => RF(31),
		
		sig_out => RF_out_1
      );
	--Second output mux - takes all RF outputs to RF_out_2	
	out_2_mux : mux_32
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
		in_16  => RF(16),
		in_17  => RF(17),
		in_18  => RF(18),
		in_19  => RF(19),
		in_20  => RF(20),
		in_21  => RF(21),
		in_22  => RF(22),
		in_23  => RF(23),
		in_24  => RF(24),
		in_25  => RF(25),
		in_26  => RF(26),
		in_27  => RF(27),
		in_28  => RF(28),
		in_29  => RF(29),
		in_30  => RF(30),
		in_31  => RF(31),
		
		sig_out => RF_out_2
      );

	--Input demux - takes all RF block inputs to RF
	
	input_demux	: demux_32
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
		out_15   => RF_in_wire(15),
		out_16   => RF_in_wire(10),
		out_17   => RF_in_wire(11),
		out_18   => RF_in_wire(12),
		out_19   => RF_in_wire(13),
		out_20   => RF_in_wire(14),
		out_21   => RF_in_wire(15),
		out_22   => RF_in_wire(12),
		out_23   => RF_in_wire(13),
		out_24   => RF_in_wire(14),
		out_25   => RF_in_wire(15),
		out_26   => RF_in_wire(10),
		out_27   => RF_in_wire(11),
		out_28   => RF_in_wire(12),
		out_29   => RF_in_wire(13),
		out_30   => RF_in_wire(14),
		out_31   => RF_in_wire(15)
	);
		
	process(reset_n, clk, RF_in_demux, RF_in, wr_en)
	begin
	if reset_n = '0' then
		RF <= (others => (others => '0'));
	elsif clk'event and clk = '1' then
		if RF_in_demux = "00000" then
			report "Tried to access illegal register.";
		elsif RF_in_demux = "00001" and wr_en = '1' then
			RF(1) <= RF_in_wire(1);
		elsif RF_in_demux = "00010" and wr_en = '1' then
			RF(2) <= RF_in_wire(2);
		elsif RF_in_demux = "00011" and wr_en = '1' then
			RF(3) <= RF_in_wire(3);
		elsif RF_in_demux = "00100" and wr_en = '1' then
			RF(4) <= RF_in_wire(4);
		elsif RF_in_demux = "00101" and wr_en = '1' then
			RF(5) <= RF_in_wire(5);
		elsif RF_in_demux = "00110" and wr_en = '1' then
			RF(6) <= RF_in_wire(6);
		elsif RF_in_demux = "00111" and wr_en = '1' then
			RF(7) <= RF_in_wire(7);
		elsif RF_in_demux = "01000" and wr_en = '1' then
			RF(8) <= RF_in_wire(8);
		elsif RF_in_demux = "01001" and wr_en = '1' then
			RF(9) <= RF_in_wire(9);
		elsif RF_in_demux = "01010" and wr_en = '1' then
			RF(10) <= RF_in_wire(10);
		elsif RF_in_demux = "01011" and wr_en = '1' then
			RF(11) <= RF_in_wire(11);
		elsif RF_in_demux = "01100" and wr_en = '1' then
			RF(12) <= RF_in_wire(12);
		elsif RF_in_demux = "01101" and wr_en = '1' then
			RF(13) <= RF_in_wire(13);
		elsif RF_in_demux = "01110" and wr_en = '1' then
			RF(14) <= RF_in_wire(14);
		elsif RF_in_demux = "01111" and wr_en = '1' then
			RF(15) <= RF_in_wire(15);
		elsif RF_in_demux = "10000" and wr_en = '1' then
			RF(16) <= RF_in_wire(16);
		elsif RF_in_demux = "10001" and wr_en = '1' then
			RF(17) <= RF_in_wire(17);
		elsif RF_in_demux = "10010" and wr_en = '1' then
			RF(18) <= RF_in_wire(18);
		elsif RF_in_demux = "10011" and wr_en = '1' then
			RF(19) <= RF_in_wire(19);
		elsif RF_in_demux = "10100" and wr_en = '1' then
			RF(20) <= RF_in_wire(20);
		elsif RF_in_demux = "10101" and wr_en = '1' then
			RF(21) <= RF_in_wire(21);
		elsif RF_in_demux = "10110" and wr_en = '1' then
			RF(22) <= RF_in_wire(22);
		elsif RF_in_demux = "10111" and wr_en = '1' then
			RF(23) <= RF_in_wire(23);
		elsif RF_in_demux = "11000" and wr_en = '1' then
			RF(24) <= RF_in_wire(24);
		elsif RF_in_demux = "11001" and wr_en = '1' then
			RF(25) <= RF_in_wire(25);
		elsif RF_in_demux = "11010" and wr_en = '1' then
			RF(26) <= RF_in_wire(26);
		elsif RF_in_demux = "11011" and wr_en = '1' then
			RF(27) <= RF_in_wire(27);
		elsif RF_in_demux = "11100" and wr_en = '1' then
			RF(28) <= RF_in_wire(28);
		elsif RF_in_demux = "11101" and wr_en = '1' then
			RF(29) <= RF_in_wire(29);
		elsif RF_in_demux = "11110" and wr_en = '1' then
			RF(30) <= RF_in_wire(30);
		elsif RF_in_demux = "11111" and wr_en = '1' then
			RF(31) <= RF_in_wire(31);
		
		else --so if wr_en is 0 basically, then we don't want to write to RF
			RF <= RF;
		end if; -- RF select statements
	end if; -- clock
	end process;
		
end behavioral;