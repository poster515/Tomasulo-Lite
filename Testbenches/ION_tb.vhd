library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--import RF entity
entity ION_tb is
end ION_tb;

architecture test of ION_tb is
--import ALU
component ION
  port(
   --Input data and clock
	clk 				: in std_logic;
	digital_in		: in std_logic_vector(15 downto 0);	--reading digital inputs on chip
	slave_addr		: in std_logic_vector(6 downto 0); --dedicated signal from CU, data comes from 
	 
	--Control signals
	reset_n								: in std_logic; --all registers reset to 0 when this goes low
	GPIO_r_en, GPIO_wr_en 			: in std_logic; --enables read/write for GPIO (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
	I2C_r_en, I2C_wr_en				: in std_logic; --initiates reads/writes for I2C (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
	A_bus_out_sel, B_bus_out_sel	: in std_logic; --enables A or B bus onto output_buffer (ONLY SET HIGH WHEN RESULTS ARE READY)
	A_bus_in_sel, B_bus_in_sel		: in std_logic; --enables input_buffer from A or B bus
	 
   --Outputs
   digital_out			: out std_logic_vector(15 downto 0); --
	I2C_error			: out	std_logic;	--in case we can't write to slave after three attempts
	I2C_op_run			: out std_logic;	--when high, lets CU know that there is a CU operation occurring
	
	--Input/Outputs
	I2C_sda, I2C_scl	: inout std_logic; --high level chip inputs/outputs
	A_bus, B_bus		: inout std_logic_vector(15 downto 0)
	);
end component;

--time delta for waiting between test inputs
constant TIME_DELTA : time := 10 ns;

-- test signals here, map identically to EUT
signal A_bus, B_bus             : std_logic_vector(15 downto 0) := "ZZZZZZZZZZZZZZZZ"; --
signal digital_in, digital_out  : std_logic_vector(15 downto 0); --
signal slave_addr               : std_logic_vector(6 downto 0);
signal A_bus_out_sel, B_bus_out_sel	: std_logic; --enables A or B bus onto output_buffer
signal A_bus_in_sel, B_bus_in_sel		 : std_logic; --enables input_buffer on A or B bus
signal clk, reset_n, wr_en      : std_logic := '0';               -- initialize to 0;
signal I2C_scl, I2C_sda         : std_logic := 'Z';
signal GPIO_r_en, GPIO_wr_en    : std_logic := '0'; --enables read/write for GPIO (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
signal I2C_r_en, I2C_wr_en				  : std_logic := '0'; --initiates reads/writes for I2C (NEEDS TO BE HIGH UNTIL RESULTS ARE RECEIVED AT CU)
signal I2C_error, I2C_op_run			 :	std_logic;	--in case we can't write to slave after three attempts

  begin
    
    dut : entity work.ION
      port map(
        --Input data and clock
        clk 			       => clk,
        digital_in	   => digital_in,
        slave_addr    => slave_addr,
	 
        --Control signals
        reset_n	      => reset_n,       
        GPIO_r_en 	   => GPIO_r_en,         
        GPIO_wr_en    => GPIO_wr_en,
        I2C_r_en      => I2C_r_en,
        I2C_wr_en     => I2C_wr_en,
        A_bus_out_sel => A_bus_out_sel, 
        B_bus_out_sel	=> B_bus_out_sel, --enables A or B bus onto output_buffer
        A_bus_in_sel  => A_bus_in_sel, 
        B_bus_in_sel	 => B_bus_in_sel,  --enables input_buffer on A or B bus
	 
        --Outputs
        digital_out   => digital_out, --needs to be inout to support future reading of outputs
        I2C_error     => I2C_error,
        I2C_op_run     => I2C_op_run,
        
	 
        --Input/Outputs
        I2C_sda       => I2C_sda, 
        I2C_scl	      => I2C_scl,
        A_bus         => A_bus, 
        B_bus		       => B_bus
      );
      
    clk <=  '1' after TIME_DELTA / 2 when clk = '0' else
            '0' after TIME_DELTA / 2 when clk = '1'; 
        
    simulation : process
    begin
      --initialize all registers, and wait a few clocks
      reset_n <= '0';
      digital_in <= "0000000000000000";
      A_bus <= "ZZZZZZZZZZZZZZZZ";
      B_bus <= "ZZZZZZZZZZZZZZZZ";
      wait for TIME_DELTA * 2;
      
      reset_n <= '1';
      
      -- write to digital outputs
      A_bus <= "0101010101010101";
      
      wait for TIME_DELTA;
      A_bus_in_sel <= '1';
      GPIO_wr_en <= '1';
      
      wait for TIME_DELTA;
      
      -- reset GPIO write signals
      A_bus <= "ZZZZZZZZZZZZZZZZ";
      A_bus_in_sel <= '0';
      GPIO_wr_en <= '0';
      
      -- read digital inputs
      digital_in <= "1111000011110000";
      GPIO_r_en <= '1';
      B_bus_out_sel <= '1';
      
      wait for TIME_DELTA;
      
      -- reset GPIO read signals
      B_bus_out_sel <= '0';
      GPIO_r_en <= '0';
  
      ---------------------------------------------------------------------------
      --I2C MASTER WRITE CODE--
      --Write to I2C 
      slave_addr <= "1010101";
      A_bus <= "0000000011110000";
      A_bus_in_sel <= '1';
      I2C_wr_en   <= '1';
      wait for TIME_DELTA;
      
      A_bus_in_sel <= '0';
      A_bus <= "ZZZZZZZZZZZZZZZZ";
      --60 ns
      
      --ACK slave address
      wait for (2135 ns - (TIME_DELTA * 3));
      I2C_sda <= '0';
      wait for (TIME_DELTA * 30); --2405 ns
      I2C_sda <= 'Z'; 
      
      --ACK receipt of data from master
      wait for 2070 ns; --4475 ns - 2405 ns = 2070 ns
      I2C_sda <= '0';
      wait for (TIME_DELTA * 12); --4595 ns 
      I2C_sda <= 'Z';
      
      wait for TIME_DELTA;
      
      -- reset I2C write
      I2C_wr_en <= '0';

      --I2C MASTER READ CODE--
      -- Write to I2C 
      slave_addr <= "1010101";
      I2C_r_en   <= '1';
      wait for TIME_DELTA;
      
      -- slave ACKs address
      wait for (2135 ns - (TIME_DELTA * 3));
      I2C_sda <= '0';
      wait for (TIME_DELTA * 12); --2255 ns
      I2C_sda <= 'Z'; 
      
      -- --Pseudo data from 'slave'
      wait for 170 ns; --2390 ns - 2255 ns = 170 ns, low phase of slave read cycle
      I2C_sda <= '0';
      wait for (TIME_DELTA * 26); --takes us to next low phase 
      I2C_sda <= '1';
      wait for (TIME_DELTA * 26); --
      I2C_sda <= '0';
      wait for (TIME_DELTA * 26); --takes us to next low phase 
      I2C_sda <= '1';
      wait for (TIME_DELTA * 26); --takes us to next low phase 
      I2C_sda <= '1';
      wait for (TIME_DELTA * 26); --
      I2C_sda <= 'X';
      wait for (TIME_DELTA * 26); --takes us to next low phase 
      I2C_sda <= '1';
      wait for (TIME_DELTA * 26); --takes us to next low phase 
      I2C_sda <= '1';
      
      --Slave Relinquishes SDA line
      wait for (TIME_DELTA * 12); --takes us to next low phase
      I2C_sda <= 'Z';
      
      --retransmit data
      wait for 450 ns; --(7 * 26 * 10)
      I2C_sda <= '0';
      wait for (TIME_DELTA * 26); --takes us to next low phase 
      I2C_sda <= '1';
      wait for (TIME_DELTA * 26); --
      I2C_sda <= '0';
      wait for (TIME_DELTA * 26); --takes us to next low phase 
      I2C_sda <= '1';
      wait for (TIME_DELTA * 26); --takes us to next low phase 
      I2C_sda <= '1';
      wait for (TIME_DELTA * 26); --
      I2C_sda <= '1';
      wait for (TIME_DELTA * 26); --takes us to next low phase 
      I2C_sda <= '1';
      wait for (TIME_DELTA * 26); --takes us to next low phase 
      I2C_sda <= '1';
      
      --Slave Relinquishes SDA line
      wait for (TIME_DELTA * 12); --takes us to next low phase
      I2C_sda <= 'Z';
      
      wait for TIME_DELTA;
      
      --output result on B_bus and stop read
      B_bus_out_sel <= '1';
      I2C_r_en <= '0';
      wait for TIME_DELTA;
      
      --reset system
      B_bus_out_sel <= '1';
      
    end process simulation;

end architecture test;



