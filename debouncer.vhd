-- Written by Joe Post
-- this is code is debouncer.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

--------------------------------------------------------------

entity debouncer is

generic(	counter_size:	integer := 4); 
--generic amount of time to wait
--assume 100 MHz system clock and 100 kHz data clock. 

--counter	|			% of 
--bits		|  		data_clock period
--_____________________________________
--4			|			1.6
--5			|			3.2
--6			|			6.4
--7			|			12.8
--8			|			25.6

port(
	data_clock:		in std_logic;	
	sys_clock:		in std_logic;
	
	debounced_clock: 	out std_logic 
);
end debouncer;

--------------------------------------------------------------

ARCHITECTURE logic OF debouncer IS
  SIGNAL flipflops   : STD_LOGIC_VECTOR(1 DOWNTO 0); --input flip flops
  SIGNAL counter_set : STD_LOGIC;                    --sync reset to zero
  SIGNAL counter_out : STD_LOGIC_VECTOR(counter_size DOWNTO 0) := (OTHERS => '0'); --counter output
BEGIN

  counter_set <= flipflops(0) xor flipflops(1);   --determine when to start/reset counter
  
  PROCESS(sys_clock)
  BEGIN
    IF(sys_clock'EVENT and sys_clock = '1') THEN
      flipflops(0) <= data_clock;
      flipflops(1) <= flipflops(0);
      If(counter_set = '1') THEN                  --reset counter because input is changing
        counter_out <= (OTHERS => '0');
      ELSIF(counter_out(counter_size) = '0') THEN --stable input time is not yet met
        counter_out <= counter_out + 1;
      ELSE                                        --stable input time is met
        debounced_clock <= flipflops(1);
      END IF;    
    END IF;
  END PROCESS;
END logic;