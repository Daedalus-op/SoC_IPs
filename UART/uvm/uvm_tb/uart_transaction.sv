`include "uvm_macros.svh"
import uvm_pkg::*;

class uart_transaction extends uvm_sequence_item;
  	// Input Signals of DUT for APB UART's transaction
  	rand 	logic 	[31 : 0]   	payload; 												// 32-bit data that need to be sent on DUT RX pin serially in UART_DRIVER
  	rand 	logic 	[31 : 0]    transmitter_reg; 									// 32-data monitored from DUT TX pin...sent to scoreboard from UART_MONITOR
		rand 	logic 			 				bad_parity;
		rand 	logic 	[6:0]				bad_parity_frame;
		rand 	logic 							sb_corr;
		rand 	logic 	[6:0]				sb_corr_frame;
		rand 	logic 	[1:0]				sb_corr_bit;
		rand 	bit 								start_bit;
		rand 	bit 		[1:0] 			stop_bits;
  	
		logic 				[35:0]			payld_func;
	
    // Constructor Define Method
    function  new (string name = "uart_transaction");
        super.new(name);
    endfunction
    
    // Registering our transaction with the UVM Object Utils
    // these signals are going to exchange with between DUT and testbench 
    `uvm_object_utils_begin (uart_transaction)
      	`uvm_field_int (start_bit,UVM_ALL_ON)
				`uvm_field_int (stop_bits,UVM_ALL_ON)
				`uvm_field_int (payload,UVM_ALL_ON)
      	`uvm_field_int (bad_parity,UVM_ALL_ON)
				`uvm_field_int (sb_corr,UVM_ALL_ON)
      	`uvm_field_int (transmitter_reg,UVM_ALL_ON)
    `uvm_object_utils_end
	
	constraint default_start_bit 		{ start_bit 				== 1'b0;}
	constraint default_stop_bits 		{ stop_bits 				== 2'b11;}
	constraint corrupt_parity_frame	{ bad_parity_frame 	[3:0] 	>'b0;}
	constraint corrupt_sb_frame 		{ sb_corr_frame 	[3:0]	>'b0;}
	constraint corrupt_sb_bit 			{ sb_corr_bit 				!= 2'b0;}
  
	function bit [6:0] calc_parity 	(
										logic [31:0] payload,			
										logic bad_parity,
										logic ev_odd,
										logic [6:0] bad_parity_frame
									);
		payld_func={{4{1'b0}},payload[31:0]}; 
		for(int i=0;i<4;i++)  begin
			calc_parity[i] = ev_odd?(^( payld_func[i*(8) +: 8] )) : (~^( payld_func[i*(8) +: 8] ));		
			if(bad_parity && bad_parity_frame[i])
				calc_parity[i] = ~calc_parity[i];
		end
	endfunction
endclass
