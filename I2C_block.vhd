-- Written by Joe Post

--Credit for a majority of this source goes to Peter Samarin: https://github.com/oetr/FPGA-I2C-Slave/blob/master/I2C_slave.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
------------------------------------------------------------
entity I2C_block is
  generic (
    SLAVE_ADDR : std_logic_vector(6 downto 0)	:= "1111111"); --63 in decimal 
  port (
    scl, sda         : inout std_logic;
    clk, rst      	: in    std_logic;
    -- User interface
    read_req         : out   std_logic;
    data_to_slave   	: in    std_logic_vector(15 downto 0);
    data_valid       : out   std_logic;
    data_from_slave 	: out   std_logic_vector(15 downto 0);
	 slave_addr_OK		: out   std_logic);
end entity I2C_block;

------------------------------------------------------------
architecture arch of I2C_block is
  -- this assumes that system's clock is much faster than SCL
  constant DEBOUNCING_WAIT_CYCLES : integer   := 4;
  
  type state_t is (idle, get_address_and_cmd,
                   answer_ack_start, write,
                   read, read_ack_start,
                   read_ack_got_rising, read_stop);
  -- I2C state management
  signal state_reg          : state_t              	:= idle;
  signal cmd_reg            : std_logic            	:= '0';
  signal bits_processed_reg : integer range 0 to 16 	:= 0;
  signal continue_reg       : std_logic            	:= '0';

  signal scl_reg                  : std_logic := '1';
  signal sda_reg                  : std_logic := '1';
  signal scl_debounced            : std_logic := '1';
  signal sda_debounced            : std_logic := '1';
  

  -- Helpers to figure out next state
  signal start_reg       : std_logic := '0';
  signal stop_reg        : std_logic := '0';
  signal scl_rising_reg  : std_logic := '0';
  signal scl_falling_reg : std_logic := '0';

  -- Address and data received from slave
  signal addr_reg             : std_logic_vector(6 downto 0) := (others => '0');
  signal data_reg             : std_logic_vector(6 downto 0) := (others => '0');
  signal data_from_slave_reg 	: std_logic_vector(7 downto 0) := (others => '0');

  signal scl_prev_reg : std_logic := '1';
  -- Master writes on scl
  signal scl_wen_reg  : std_logic := '0';
  signal scl_o_reg    : std_logic := '0';
  signal sda_prev_reg : std_logic := '1';
  -- Master writes on sda
  signal sda_wen_reg  : std_logic := '0';
  signal sda_o_reg    : std_logic := '0';

  -- User interface
  signal data_valid_reg     : std_logic                    := '0';
  signal read_req_reg       : std_logic                    := '0';
  signal data_to_master_reg : std_logic_vector(7 downto 0) := (others => '0');
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

  process (sys_clock) is
  begin
    if rising_edge(sys_clock) then
      -- save SCL in registers that are used for debouncing
      scl_reg <= scl;
      sda_reg <= sda;

      -- Delay debounced SCL and SDA by 1 clock cycle
      scl_prev_reg   <= scl_debounced;
      sda_prev_reg   <= sda_debounced;
      -- Detect rising and falling SCL
      scl_rising_reg <= '0';
      if scl_prev_reg = '0' and scl_debounced = '1' then
        scl_rising_reg <= '1';
      end if;
      scl_falling_reg <= '0';
      if scl_prev_reg = '1' and scl_debounced = '0' then
        scl_falling_reg <= '1';
      end if;

      -- Detect I2C START condition
      start_reg <= '0';
      stop_reg  <= '0';
      if scl_debounced = '1' and scl_prev_reg = '1' and
        sda_prev_reg = '1' and sda_debounced = '0' then
        start_reg <= '1';
        stop_reg  <= '0';
      end if;

      -- Detect I2C STOP condition
      if scl_prev_reg = '1' and scl_debounced = '1' and
        sda_prev_reg = '0' and sda_debounced = '1' then
        start_reg <= '0';
        stop_reg  <= '1';
      end if;

    end if;
  end process;

  ----------------------------------------------------------
  -- I2C state machine
  ----------------------------------------------------------
  process (sys_clock, rst) is
  begin
    if rising_edge(sys_clock) then
      -- Default assignments
      sda_o_reg      <= '0';
      sda_wen_reg    <= '0';
      -- User interface
--      data_valid_reg <= '0';
      read_req_reg   <= '0';

      case state_reg is

        when idle =>
          if start_reg = '1' then
            state_reg          <= get_address_and_cmd;
            bits_processed_reg <= 0;
				
          end if;

        when get_address_and_cmd =>
          if scl_rising_reg = '1' then
--			 slave_addr_OK <= '1';
            if bits_processed_reg < 7 then
              bits_processed_reg             <= bits_processed_reg + 1;
              addr_reg(6-bits_processed_reg) <= sda_debounced;
            elsif bits_processed_reg = 7 then
              bits_processed_reg <= bits_processed_reg + 1;
              cmd_reg            <= sda_debounced;
            end if;
          end if;

          if bits_processed_reg = 8 and scl_falling_reg = '1' then
            bits_processed_reg <= 0;
            if addr_reg = SLAVE_ADDR then  -- check req address
				  slave_addr_OK <= '1';
              state_reg <= answer_ack_start;
              if cmd_reg = '1' then  -- master trying to read slave device
                read_req_reg       <= '1';
                data_to_master_reg <= data_to_master;
              end if;
            else
				  --slave_addr_OK <= '0';
              assert false
                report ("I2C: target/slave address mismatch (data is being sent to another slave).")
                severity note;
              state_reg <= idle;
            end if;
          end if;

        ----------------------------------------------------
        -- I2C acknowledge to master
        ----------------------------------------------------
        when answer_ack_start =>
          sda_wen_reg <= '1';
          sda_o_reg   <= '0';
          if scl_falling_reg = '1' then
            if cmd_reg = '0' then
              state_reg <= write;
            else
              state_reg <= read;
            end if;
          end if;

        ----------------------------------------------------
        -- MASTER WRITES TO SLAVE
        ----------------------------------------------------
        when write =>
          if scl_rising_reg = '1' then
            bits_processed_reg <= bits_processed_reg + 1;
            if bits_processed_reg < 7 then
              data_reg(6-bits_processed_reg) <= sda_debounced;
            else
              data_from_master_reg <= data_reg & sda_debounced;
              data_valid_reg       <= '1';
            end if;
          end if;

          if scl_falling_reg = '1' and bits_processed_reg = 8 then
            state_reg          <= answer_ack_start;
            bits_processed_reg <= 0;
          end if;

        ----------------------------------------------------
        -- MASTER READS FROM SLAVE
        ----------------------------------------------------
        when read =>
          sda_wen_reg <= '1';
          sda_o_reg   <= data_to_master_reg(7-bits_processed_reg);
          if scl_falling_reg = '1' then
            if bits_processed_reg < 7 then
              bits_processed_reg <= bits_processed_reg + 1;
            elsif bits_processed_reg = 7 then
              state_reg          <= read_ack_start;
              bits_processed_reg <= 0;
            end if;
          end if;

        ----------------------------------------------------
        -- I2C read master acknowledge
        ----------------------------------------------------
        when read_ack_start =>
          if scl_rising_reg = '1' then
            state_reg <= read_ack_got_rising;
            if sda_debounced = '1' then  -- nack = stop read
              continue_reg <= '0';
            else  -- ack = continue read
              continue_reg       <= '1';
              read_req_reg       <= '1';  -- request reg byte
              data_to_master_reg <= data_to_master;
            end if;
          end if;

        when read_ack_got_rising =>
          if scl_falling_reg = '1' then
            if continue_reg = '1' then
              if cmd_reg = '0' then
                state_reg <= write;
              else
                state_reg <= read;
              end if;
            else
              state_reg <= read_stop;
            end if;
          end if;

        -- Wait for START or STOP to get out of this state
        when read_stop =>
          null;

        -- Wait for START or STOP to get out of this state
        when others =>
          assert false
            report ("I2C: error: ended in an impossible state.")
            severity error;
          state_reg <= idle;
      end case;

      --------------------------------------------------------
      -- Reset counter and state on start/stop
      --------------------------------------------------------
      if start_reg = '1' then
        state_reg          <= get_address_and_cmd;
        bits_processed_reg <= 0;
		  data_valid_reg <= '0'; --debug
      end if;

      if stop_reg = '1' then
        state_reg          <= idle;
        bits_processed_reg <= 0;
      end if;

      if rst = '0' then
        state_reg <= idle;
--		  slave_addr_OK <= '0'; -- just a debug variable
--      else
--			slave_addr_OK <= '1'; --just a debug point
		end if;
    end if;
--
  end process;

  ----------------------------------------------------------
  -- I2C interface
  ----------------------------------------------------------
  sda <= sda_o_reg when sda_wen_reg = '1' else
         'Z';
  scl <= scl_o_reg when scl_wen_reg = '1' else
         'Z';
  ----------------------------------------------------------
  -- User interface
  ----------------------------------------------------------
  -- Master writes
  data_valid       <= data_valid_reg;
  data_from_master <= data_from_master_reg;
  -- Master reads
  read_req         <= read_req_reg;
end architecture arch;