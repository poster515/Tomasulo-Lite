library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all; 
use work.arrays.all;

-- Package Declaration Section
package WB_functions is 

function bufferIW(
	IWB : in array_10_16; 
	PM_data_in : in std_logic_vector(15 downto 0))
   return array_10_16;

end package WB_functions; 

-- Package Body Section
package body WB_functions is
 
  function bufferIW( 
		IWB : in array_10_16; 
		PM_data_in : in std_logic_vector(15 downto 0)))
   
	return array_10_16 is
	 
  begin
    return ;
  end;
 
end package body WB_functions;
