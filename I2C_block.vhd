-- Written by Joe Post

--Credit for a majority of this source goes to Peter Samarin: https://github.com/oetr/FPGA-I2C-Slave/blob/master/I2C_slave.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
------------------------------------------------------------
entity I2C_block is
	generic ( clk_div : integer := 64 ); --this will be clock divider factor i.e., [sys_clock / clk_div]
	port (
		scl, sda         		: inout 	std_logic; --these signals get debounced just in case
		sys_clock, reset_n  : in    	std_logic;
		-- User interface
		slave_reg_en		: in std_logic; --0 = just write/read data to slave, 1 = expect register internal register also
		write_begin			: in 	  	std_logic;
		read_begin			: in 	  	std_logic;
		slave_address		: in 		std_logic_vector(6 downto 0);
		data_to_slave   	: in    	std_logic_vector(7 downto 0); --
		--data_valid       	: out   	std_logic; --may not need this because this is the master
		data_from_slave 	: out   	std_logic_vector(15 downto 0)
	);
end entity I2C_block;

------------------------------------------------------------
architecture arch of I2C_block is
	-- this assumes that system's clock is much faster than SCL
	constant DEBOUNCING_WAIT_CYCLES : integer   := 4;
  
--	type state_t is (idle, get_address_and_cmd,
--                   answer_ack_start, write,
--                   read, read_ack_start,
--                   read_ack_got_rising, read_stop);
						 
	type state_t is (idle, write_slave, write_slave_addr, slave_ack, read_slave);
						 
	-- I2C state management
	signal state_reg          	: state_t              	:= idle;
	signal cmd_reg            	: std_logic            	:= '0';
	signal bits_processed_reg 	: integer range 0 to 8 	:= 0;
	signal clk_divider			: integer range 0 to clk_div - 1	:= clk_div - 1; --register to keep track of clock division
	signal continue_reg       	: std_logic            	:= '0';

	signal scl_reg                  : std_logic := '1';
	signal sda_reg                  : std_logic := '1';
	signal scl_debounced            : std_logic := '1';
	signal sda_debounced            : std_logic := '1';

	-- Helpers to figure out next state
--	signal start_reg       : std_logic := '0';
--	signal stop_reg        : std_logic := '0';
--	signal start_read      : std_logic := '0';
--	signal stop_read       : std_logic := '0';
	signal scl_rising_reg  : std_logic := '0'; --1 if rising edge of scl, 0 otherwise
	signal scl_falling_reg : std_logic := '0';

	-- Address and data received from slave
	signal addr_reg       			: std_logic_vector(6 downto 0) := (others => '0'); --slave addresses only 7 bits long
	signal slave_reg       			: std_logic_vector(7 downto 0) := (others => '0'); --address for slave internal registers
	signal data_reg       			: std_logic_vector(7 downto 0) := (others => '0'); --register for data to slave 
	signal data_from_slave_reg 	: std_logic_vector(7 downto 0) := (others => '0'); --

	signal scl_prev_reg : std_logic := '1';
	  
	-- Master writes on scl
--	signal scl_wen_reg  : std_logic := '0';
	signal scl_o_reg    : std_logic := '0';
--	signal sda_prev_reg : std_logic := '1';
	  
	-- Master writes on sda
--	signal sda_wen_reg  : std_logic := '0';
	signal sda_o_reg    : std_logic := '0';

	-- User interface
--	signal data_valid_reg     : std_logic                    := '0';
--	signal read_req_reg       : std_logic                    := '0';
--	signal data_to_slave_reg : std_logic_vector(7 downto 0) := (others => '0');
  
begin

  -- debounce SCL and SDA
  SCL_debounce : entity work.debouncer
    port map (
      sys_clock        	=> sys_clock,
      data_clock  		=> scl_reg,
      debounced_clock 	=> scl_debounced);

  -- it might not make sense to debounce SDA, since master
  -- and slave can both write to it...
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
		
		if state_reg = write_slave_addr then
			if clk_divider = 0 then
				scl_o_reg <= not(scl_debounced); -- just invert scl to create scl clock
			else 
				clk_divider <= clk_divider - 1;
			end if;
		end if; --not idle
		
      -- save SCL in registers that are used for debouncing
      scl_reg <= scl;
      sda_reg <= sda;

      -- Delay debounced SCL and SDA by 1 clock cycle
      scl_prev_reg   <= scl_debounced;
      --sda_prev_reg   <= sda_debounced;
		
      -- Detect rising and falling SCL
      scl_rising_reg <= '0';
      if scl_prev_reg = '0' and scl_debounced = '1' then
        scl_rising_reg <= '1';
		  --scl_falling_reg <= '0';
      end if;
		
      scl_falling_reg <= '0';
      if scl_prev_reg = '1' and scl_debounced = '0' then
        scl_falling_reg <= '1';
		  --scl_rising_reg <= '0';
      end if;

--      -- Detect I2C START condition
--      start_reg <= '0';
--      stop_reg  <= '0';
--      if scl_debounced = '1' and scl_prev_reg = '1' and sda_prev_reg = '1' and sda_debounced = '0' then
--        start_reg <= '1';
--        stop_reg  <= '0';
--      end if;
--
--      -- Detect I2C STOP condition
--      if scl_prev_reg = '1' and scl_debounced = '1' and sda_prev_reg = '0' and sda_debounced = '1' then
--        start_reg <= '0';
--        stop_reg  <= '1';
--      end if;

    end if; --rising_edge(clk)
  end process;
  
  -------------PROTOTYPE--------------------
  
	process(reset_n, sys_clock, sda, scl)
		begin
			if (reset_n = '0') then
				state_reg <= idle; --place back into idle state
				--start_read <= '0';
				--stop_read  <= '0';
				
			elsif rising_edge(sys_clock) then
				case state_reg is
				
					when idle =>
						
						if write_begin = '1' then
							state_reg <= write_slave_addr;
						elsif read_begin = '1' then
							state_reg <= read_slave;
						end if; --if write_begin
						
					when write_slave_addr =>
						--reset bits_processed
						bits_processed_reg <= 0;
						
						if bits_processed_reg = 0 then --if we haven't started anything yet, send the sda line low to initiate start of transaction
							sda_o_reg <= '0';
						end if; --bits_processed_reg
						
						if(scl_debounced = '0') then --need to output bits when scl is low to ensure setup timing reqs met
							
							if bits_processed_reg < 6 and scl_falling_reg = '1' then --only want to transmit new bit once per scl low cycle
								sda_o_reg <= addr_reg(6-bits_processed_reg);
							elsif bits_processed_reg = 6 and scl_falling_reg = '1' then
								sda_o_reg <= '1'; --because this is a write command
							else
								sda_o_reg 			<= 'Z';
								state_reg 	<= slave_ack;
							end if;
							
							bits_processed_reg <= bits_processed_reg + 1;
							
						end if; --scl_debounce = '0'
					
					when slave_ack =>
						if scl_rising_reg = '1' and scl_debounced = '1' then
							if sda_debounced = '0' then
								state_reg <= write_slave;
							else
								state_reg <= idle; --else, nobody acked the message
							end if;
						end if;					
						
					when write_slave =>
					
						--send data, assume there is no slave register to write to, can implement later with slave_reg_en = '1'
						
						bits_processed_reg <= 0;
						
						if bits_processed_reg = 0 then --if we haven't started anything yet, send the sda line low to initiate start of transaction
							sda_o_reg <= '0';
						end if; --bits_processed_reg
						
						if(scl_debounced = '0') then --need to output bits when scl is low to ensure setup timing reqs met
							
							if bits_processed_reg < 7 and scl_falling_reg = '1' then --only want to transmit new bit once per scl low cycle
								sda_o_reg <= data_reg(7-bits_processed_reg);
							else
								state_reg <= slave_ack;
							end if;
							
							bits_processed_reg <= bits_processed_reg + 1;
							
						end if; --scl_debounce = '0'

					when read_slave => 
						state_reg <= idle;
						--listen to data lines to receive data
						--go to ack_slave_data
--						
--					when ack_slave_data
--						--ack slave data
--						--go to idle
				end case;
			end if; --reset_n, rising_edge(clk)
  end process;
  ---------------------END PROTOTYPE ----------------------------------------
	
  ----------------------------------------------------------
  -- I2C state machine
  ----------------------------------------------------------
--  process (sys_clock, rst) is
--  begin
--    if rising_edge(sys_clock) then
--      -- Default assignments
--      sda_o_reg      <= '0';
--      sda_wen_reg    <= '0';
--      -- User interface
----      data_valid_reg <= '0';
--      read_req_reg   <= '0';
--
--      case state_reg is
--
--		-- EXPECTED CASE STATEMENTS, NEED TO REVISE STATE TYPE
--			when idle =>
--				--if wr_en = '1' then
--				--	initiate write sequence (scl = '1', sda = '0')
--				-- write slave address
--				-- go to wait_for_ack state
--				-- end if;
--				
--			when wait_for_slave_ack =>
--				--wait for slave ack
--				--if received, go to either request data or send data
--				--else, use countdown to timeout and go to idle
--				
--			when send_data =>
--				--send data
--				--go to wait_for_slave_ack
--
--			when receive_data => 
--				--listen to data lines to receive data
--				--go to ack_slave_data
--				
--			when wait_for_slave_ack
--				--initiate timout for slave_ack
--				--go to idle
--				
--			when ack_slave_data
--				--ack slave data
--				--go to idle
--			--EVERYTHING BELOW THIS LINE SHOULD BE OBSOLETE
--		
--		
--			--not sure any of this state is necessary
--			when get_address_and_cmd =>
--          if scl_rising_reg = '1' then
----			 slave_addr_OK <= '1';
--            if bits_processed_reg < 7 then
--              bits_processed_reg             <= bits_processed_reg + 1;
--              addr_reg(6-bits_processed_reg) <= sda_debounced;
--            elsif bits_processed_reg = 7 then
--              bits_processed_reg <= bits_processed_reg + 1;
--              cmd_reg            <= sda_debounced;
--            end if;
--          end if;
--
--          if bits_processed_reg = 8 and scl_falling_reg = '1' then
--            bits_processed_reg <= 0;
--            if addr_reg = SLAVE_ADDR then  -- check req address
--				  slave_addr_OK <= '1';
--              state_reg <= answer_ack_start;
--              if cmd_reg = '1' then  -- master trying to read slave device
--                read_req_reg       <= '1';
--                data_to_master_reg <= data_to_master;
--              end if;
--            else
--				  --slave_addr_OK <= '0';
--              assert false
--                report ("I2C: target/slave address mismatch (data is being sent to another slave).")
--                severity note;
--              state_reg <= idle;
--            end if;
--          end if;
--
--        ----------------------------------------------------
--        -- I2C acknowledge to slave
--        ----------------------------------------------------
--        when answer_ack_start =>
--          sda_wen_reg <= '1';
--          sda_o_reg   <= '0';
--          if scl_falling_reg = '1' then
--            if cmd_reg = '0' then
--              state_reg <= write;
--            else
--              state_reg <= read;
--            end if;
--          end if;
--
--        ----------------------------------------------------
--        -- MASTER WRITES TO SLAVE
--        ----------------------------------------------------
--        when write =>
--          if scl_rising_reg = '1' then
--            bits_processed_reg <= bits_processed_reg + 1;
--            if bits_processed_reg < 7 then
--              data_reg(6-bits_processed_reg) <= sda_debounced;
--            else
--              data_from_master_reg <= data_reg & sda_debounced;
--              data_valid_reg       <= '1';
--            end if;
--          end if;
--
--          if scl_falling_reg = '1' and bits_processed_reg = 8 then
--            state_reg          <= answer_ack_start;
--            bits_processed_reg <= 0;
--          end if;
--
--        ----------------------------------------------------
--        -- MASTER READS FROM SLAVE
--        ----------------------------------------------------
--        when read =>
--          sda_wen_reg <= '1';
--          sda_o_reg   <= data_to_master_reg(15-bits_processed_reg);
--          if scl_falling_reg = '1' then
--            if bits_processed_reg < 15 then
--              bits_processed_reg <= bits_processed_reg + 1;
--            elsif bits_processed_reg = 15 then
--              state_reg          <= read_ack_start;
--              bits_processed_reg <= 0;
--            end if;
--          end if;
--
--        ----------------------------------------------------
--        -- I2C read master acknowledge
--        ----------------------------------------------------
--        when read_ack_start =>
--          if scl_rising_reg = '1' then
--            state_reg <= read_ack_got_rising;
--            if sda_debounced = '1' then  -- nack = stop read
--              continue_reg <= '0';
--            else  -- ack = continue read
--              continue_reg       <= '1';
--              read_req_reg       <= '1';  -- request reg byte
--              data_to_master_reg <= data_to_master;
--            end if;
--          end if;
--
--        when read_ack_got_rising =>
--          if scl_falling_reg = '1' then
--            if continue_reg = '1' then
--              if cmd_reg = '0' then
--                state_reg <= write;
--              else
--                state_reg <= read;
--              end if;
--            else
--              state_reg <= read_stop;
--            end if;
--          end if;
--
--        -- Wait for START or STOP to get out of this state
--        when read_stop =>
--          null;
--
--        -- Wait for START or STOP to get out of this state
--        when others =>
--          assert false
--            report ("I2C: error: ended in an impossible state.")
--            severity error;
--          state_reg <= idle;
--      end case;
--
--      --------------------------------------------------------
--      -- Reset counter and state on start/stop
--      --------------------------------------------------------
--      if start_reg = '1' then
--        state_reg          <= get_address_and_cmd;
--        bits_processed_reg <= 0;
--		  data_valid_reg 		<= '0'; --debug
--      end if;
--
--      if stop_reg = '1' then
--        state_reg          <= idle;
--        bits_processed_reg <= 0;
--      end if;
--
--      if rst = '0' then
--        state_reg <= idle;
----		  slave_addr_OK <= '0'; -- just a debug variable
----      else
----			slave_addr_OK <= '1'; --just a debug point
--		end if;
--    end if;
----
--  end process;

  ----------------------------------------------------------
  -- I2C interface
  ----------------------------------------------------------
  sda <= sda_o_reg when write_begin= '1' else
         'Z';
  scl <= scl_o_reg when write_begin = '1' else
         'Z';
  ----------------------------------------------------------
  -- User interface
  ----------------------------------------------------------
  -- Master writes
--  data_valid       <= data_valid_reg;
--  data_from_slave	 <= data_from_slave_reg;
--  -- Master reads
--  read_req         <= read_req_reg;
end architecture arch;