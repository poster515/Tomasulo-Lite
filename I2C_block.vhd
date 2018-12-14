-- Written by Joe Post

--Credit for a majority of this source goes to Peter Samarin: https://github.com/oetr/FPGA-I2C-Slave/blob/master/I2C_slave.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
------------------------------------------------------------
entity I2C_block is
	generic ( clk_div : integer :=  12); --this will be clock divider factor i.e., [sys_clock / clk_div]
	port (
		scl, sda         		: inout 	std_logic; --these signals get debounced just in case
		sys_clock, reset_n  	: in    	std_logic;
		-- User interface
--		slave_reg_en			: in 		std_logic; --0 = just write/read data to slave, 1 = expect register internal register also
		write_begin				: in 	  	std_logic;
		read_begin				: in 	  	std_logic;
		slave_address			: in 		std_logic_vector(6 downto 0);
		data_to_slave   		: in    	std_logic_vector(7 downto 0); --
		read_error       		: out  	std_logic := '0'; --set high if we can't read from slave after ack, after slave_read_retry_max retries
		data_from_slave 		: out   	std_logic_vector(7 downto 0);
		slave_ack_success		: out 	std_logic_vector(1 downto 0)	:= "01" --00 = no ack success, 10 = successful ack, 01/10 = no result yet
	);
end entity I2C_block;

------------------------------------------------------------
architecture arch of I2C_block is
	-- this assumes that system's clock is much faster than SCL
	constant DEBOUNCING_WAIT_CYCLES : integer   := 4;

	type state_t is (idle, write_slave, write_slave_addr, slave_ack, read_slave, send_stop, ack_slave, start_scl, unknown);
						 
	-- I2C state management
	signal state_reg          	: state_t              	:= idle;
	signal cmd_reg            	: std_logic            	:= '0';
	signal bits_processed_reg 	: integer range 0 to 8 	:= 0;
	signal clk_divider			: integer range 0 to clk_div - 1	:= clk_div - 1; --register to keep track of clock division
	signal continue_reg       	: std_logic            	:= '0';

--	signal scl_reg                  : std_logic := '1';
	signal sda_reg                  : std_logic := '1';
--	signal scl_debounced            : std_logic := '1';
	signal sda_debounced            : std_logic := '1';

	-- Address and data received from slave
	signal addr_reg       			: std_logic_vector(6 downto 0) := (others => '0'); --slave addresses only 7 bits long
	signal slave_reg       			: std_logic_vector(7 downto 0) := (others => '0'); --address for slave internal registers
	signal data_reg       			: std_logic_vector(7 downto 0) := (others => '0'); --register for data to slave 
	signal data_from_slave_reg  	: std_logic_vector(7 downto 0) := (others => '0'); --

--	signal scl_prev_reg : std_logic := '1';
	
	--registers to store next register value
	signal scl_o_reg    	: std_logic		:= 'Z';
	signal sda_o_reg  	: std_logic		:= 'Z';

	--global variable to keep track of scl count
	signal clk_reg 	: integer	:= 0;
	
	--constant to start scl timer
	constant scl_start: std_logic	:= '1';
	
	--constant to stop scl timer
	constant scl_stop	: std_logic := '0';
	
	--number of retries for slave retransmission
	constant	slave_read_retry_max	: integer := 5;
	signal	slave_read_retry		: integer := 0;
	signal 	data_valid				: std_logic := '1'; -- for knowing when a slave has transmitted any invalid bit (e.g., 'X', 'U', 'Z')
	
	signal scl_run, start_stop	: std_logic; --toggle scl_run to run second process below
	signal scl_status : std_logic_vector(1 downto 0);
	
	--signal to track whether address was sent to slave
	signal addr_sent	: std_logic := '0';

begin

  SDA_debounce : entity work.debouncer
    port map (
      sys_clock  			=> sys_clock,
      data_clock  		=> sda_reg,
      debounced_clock 	=> sda_debounced);
		
  process(sys_clock)
  begin
    if rising_edge(sys_clock) then
		if write_begin = '1' or read_begin = '1' then
			data_reg <= data_to_slave;
			addr_reg <= slave_address;
		end if;
		
      sda_reg <= sda;

    end if; --rising_edge(clk)
  end process;
  
  -------------PROTOTYPE--------------------
  
	--process(reset_n, sys_clock, sda, scl)
	process(reset_n, sys_clock)
		begin
			if (reset_n = '0') then
				state_reg <= idle; --place back into idle state
				
			elsif rising_edge(sys_clock) then
				case state_reg is
				
					when idle =>
						
						start_stop <= '0';
						--scl_stopped = '1';
						if write_begin = '1' then
							--reset bits_processed
							bits_processed_reg <= 0;
							clk_reg <= clk_div;
							state_reg <= start_scl;
						elsif read_begin = '1' then
							--reset bits_processed
							data_valid <= '1'; --assume all data is valid until proven otherwise in slave_read state
							bits_processed_reg <= 0;
							clk_reg <= clk_div;
							state_reg <= start_scl;
						end if; --if write_begin
						
					when start_scl =>
					
						if bits_processed_reg = 0 and scl_o_reg = 'Z' then --if we haven't started anything yet, send the sda line low to initiate start of transaction
							sda_o_reg <= '0';
						end if; --bits_processed_reg
						
						if clk_reg = 0 then
							clk_reg <= clk_div;
						elsif clk_reg = clk_div - (clk_div / 4) then
							clk_reg <= clk_div;
							state_reg <= write_slave_addr;
						else
							clk_reg <= clk_reg - 1;
						end if;
						
						
					when write_slave_addr =>
						start_stop <= '1';
						
						if clk_reg = 0 then
							clk_reg <= clk_div;
						else
							clk_reg <= clk_reg - 1;
						end if;

						if(scl_status = "01") then
							if (bits_processed_reg < 7) then
								--report "Still writing slave address, bit: " & Integer'Image(bits_processed_reg);
								sda_o_reg <= addr_reg(6 - bits_processed_reg);
								bits_processed_reg <= bits_processed_reg + 1;
							elsif bits_processed_reg = 7 then
								--report "Writing last slave address, bit 0";
								sda_o_reg <= not(write_begin) or read_begin; -- LSB is '0' for write
								bits_processed_reg <= bits_processed_reg + 1;
							else 
								sda_o_reg <= 'Z'; 		--pull to high impedance so slave can ACK
								addr_sent <= '1';
								state_reg <= slave_ack; --no go wait for the slave to ACK address on 8th low signal
							end if; --bits_processed_reg
						end if; --scl_start
					
					when slave_ack =>
					
						if clk_reg = 0 then
							clk_reg <= clk_div;
						else
							clk_reg <= clk_reg - 1;
						end if;
						
						if(scl_status = "10") then --find rising edge of SCL
							if sda_debounced = '0' then
								
								slave_ack_success <= "11";
								bits_processed_reg <= 0;
								
								if addr_sent = '1' then
									if write_begin = '1' then
										state_reg <= write_slave;
									elsif read_begin = '1' then
										state_reg <= read_slave;
									else 
										state_reg <= unknown;
									end if;
								else
									state_reg <= send_stop;
								end if; --addr_sent
							else
								slave_ack_success <= "01";
								state_reg <= idle;  		--slave did not ack address, slave_ack_success will report failure
							end if; --sda_o_reg
						end if; --scl_start
						
					when write_slave =>
						addr_sent <= '0'; --clear condition that address was sent because we're now sending the data
						
						if clk_reg = 0 then
							clk_reg <= clk_div;
						else
							clk_reg <= clk_reg - 1;
						end if;
						
						if(scl_status = "01") then --find halfway of low cycle
							if (bits_processed_reg < 8) then
								sda_o_reg <= data_reg(7 - bits_processed_reg);
								bits_processed_reg <= bits_processed_reg + 1;
							else 
								sda_o_reg <= 'Z'; 		--pull to high impedance so slave can ACK
								state_reg <= slave_ack; --no go wait for the slave to ACK address on 8th low signal
							end if; --bits_processed_reg
						end if; --scl_start

					when send_stop =>

						if(start_stop = '1') then --scl still running
							if clk_reg = 0 then
								clk_reg <= clk_div;
							else
								clk_reg <= clk_reg - 1;
							end if;

							if(scl_status = "01") then --find halfway of low cycle
								sda_o_reg <= '0'; --pull low to prepare for next rising edge of scl
								
							elsif(scl_status = "10") then --rising edge
								start_stop <= '0'; --stop scl clock
								clk_reg <= clk_div / 2; --scl_o_reg <= 'Z'

							end if; --scl_status
						else --start_stop = 0
							if clk_reg = 0 then
								clk_reg <= clk_div;
							else
								clk_reg <= clk_reg - 1;
							end if;
							
							if(clk_reg = 0) then
								sda_o_reg <= 'Z';
								if(data_valid = '1') then --if the slave didn't transmit valid data, ask for it again
									state_reg <= idle;
								end if;
							end if;
						end if;
						
					when read_slave => 
						
						addr_sent <= '0'; --clear condition that address was sent because we're now reading the data
						
						if clk_reg = 0 then
							clk_reg <= clk_div;
						else
							clk_reg <= clk_reg - 1;
						end if;

						if(scl_status = "10") then --rising edge of scl
							if (bits_processed_reg < 8) then
								--check validity of sda value
								if (sda /= '0' and sda /= '1') then
									data_valid <= '0';
								end if;
								--report "Writing bit " & Integer'Image(7 - bits_processed_reg) & ", which has a value of: " & Std_logic'Image(sda);
								data_from_slave_reg(7 - bits_processed_reg) <= sda;
								bits_processed_reg <= bits_processed_reg + 1;
							else 
								state_reg <= ack_slave; --go nack slave data
							end if; --bits_processed_reg
						elsif (scl_status = "01") then
							sda_o_reg <= 'Z'; 
						end if; --scl_start
						
						if (bits_processed_reg = 8) then
							state_reg <= ack_slave; --go nack slave data
						end if;
						
					when ack_slave =>

						if clk_reg = 0 then
							clk_reg <= clk_div;
						else
							clk_reg <= clk_reg - 1;
						end if;
						
						if(scl_status = "01") then --halfway of low phase
							if data_valid = '1' then
								sda_o_reg <= '1';	--NACK the slave
							else
								sda_o_reg <= '0';	--ACK the slave, want data sent again
							end if;

							data_from_slave <= data_from_slave_reg; --output data to top level block
							
						elsif (scl_status = "10") then
							if data_valid = '1' then
								state_reg <= send_stop;
								
							else
								if (slave_read_retry = slave_read_retry_max - 1) then
									read_error <= '1';
									sda_o_reg <= 'Z';
									state_reg <= idle;
									
								else 
									slave_read_retry <= slave_read_retry + 1;
									bits_processed_reg <= 0; --reset number of bits processed
									data_valid <= '1';			--reset data_valid, assuming all data is valid until demonstrated otherwise
									state_reg <= read_slave;
									
								end if;
							end if;
						end if;
						
					when others =>
						assert false
		            report ("I2C: error: ended in an impossible state.")
							severity error;
						state_reg <= idle;

				end case;
			end if; --reset_n, rising_edge(clk)
  end process;
  
  process (clk_reg)
  begin
	  if(start_stop = '1') then
	  
			if scl_o_reg = 'Z' then
				scl_o_reg <= '0';
			end if;

			if clk_reg = clk_div / 2 and scl_o_reg = '0' then --halfway thru low signal
				scl_status <= "01";
				
			elsif clk_reg = 0 and scl_o_reg = '0' then -- detects rising edge of scl
				scl_o_reg <= not(scl_o_reg); --should I use not(scl_debounced) instead?
				scl_status <= "10";
				
			elsif clk_reg = 0 then --reached end of counter, time to invert scl signal
				scl_o_reg <= not(scl_o_reg); --
				scl_status <= "11";
				
			else
				scl_status <= "00";
				
			end if; --clk_reg
		else
			scl_o_reg <= 'Z'; --not using scl, leave at high impedance
			scl_status <= "00";
		end if; --start_stop
	end process;

  ----------------------------------------------------------
  -- I2C interface
  ----------------------------------------------------------
  sda <= sda_o_reg;
  scl <= scl_o_reg;

end architecture arch;