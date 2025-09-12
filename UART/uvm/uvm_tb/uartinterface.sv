interface uart_if (input PCLK , input PRESETn);

  //Signals Declaration 
    logic           tx;
    logic           rx;

  //clocking blocks
  clocking driver_cb @(posedge PCLK);
    default input #1 output #1;	
	output 	rx;
  endclocking
  
  clocking monitor_cb @(posedge PCLK);
    default input #1 output #1;
	input	tx;  
  endclocking
  
  //modports
  modport DRIVER  (clocking driver_cb , input PCLK,PRESETn);
  modport MONITOR (clocking monitor_cb , input PCLK,PRESETn);

endinterface
