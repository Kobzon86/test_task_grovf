`timescale 100ps / 100ps	
module Task_ip_TB
();
// --------------------------------------------------
parameter DATA_WIDTH=512;

//////Clock
reg input_clk_ST_sig;initial  input_clk_ST_sig = 1'b0;
always #40 input_clk_ST_sig = !input_clk_ST_sig;
// --------------------------------------------------

	reg [DATA_WIDTH-1:0]i_AXI_slave_data='0;
	reg i_AXI_slave_valid_p=1'b0;
	reg [DATA_WIDTH/8-1:0]i_AXI_slave_tkeep='0;
	
	reg [DATA_WIDTH/8-1:0]shift_val = '0;
	
	wire [DATA_WIDTH-1:0]o_AXI_master_data;
	wire o_AXI_master_valid_p;
	wire [DATA_WIDTH/8-1:0]o_AXI_master_tkeep;
	
	reg  i_AXI_master_ready = 1'b1;
	wire o_AXI_slave_ready;
	reg reset_n = 1'b0;
	reg i_AXI_slave_tlast = 1'b0;
	wire o_AXI_master_tlast;

Task_ip Task_ip_inst (
	.clk                 (input_clk_ST_sig    ), // input  clk_sig
	.reset_n             (reset_n             ), // input  reset_n_sig
	.shift_val           (shift_val           ), // input [DATA_WIDTH/8-1:0] shift_val_sig
	.i_AXI_slave_data    (i_AXI_slave_data    ), // input [DATA_WIDTH-1:0] i_AXI_slave_data_sig
	.i_AXI_slave_valid_p (i_AXI_slave_valid_p ), // input  i_AXI_slave_valid_p_sig
	.i_AXI_slave_tkeep   (i_AXI_slave_tkeep   ), // input [DATA_WIDTH/8-1:0] i_AXI_slave_byte_en_sig
	.o_AXI_master_data   (o_AXI_master_data   ), // output [DATA_WIDTH-1:0] o_AXI_master_data_sig
	.o_AXI_master_valid_p(o_AXI_master_valid_p), // output  o_AXI_master_valid_p_sig
	.o_AXI_master_tkeep  (o_AXI_master_tkeep  ), // output [DATA_WIDTH/8-1:0] o_AXI_master_byte_en_sig
	.i_AXI_master_ready  (i_AXI_master_ready  ),
	.o_AXI_slave_ready   (o_AXI_slave_ready   ),
	.i_AXI_slave_tlast   (i_AXI_slave_tlast   ),
	.o_AXI_master_tlast  (o_AXI_master_tlast  )
);

defparam Task_ip_inst.DATA_WIDTH = DATA_WIDTH;


wire [7:0]shifted_bytes[DATA_WIDTH/8-1:0];
genvar i;
generate for(i=0;i<DATA_WIDTH/8;++i)begin:gen_ffbytes
		assign shifted_bytes[i] = o_AXI_master_data[(8*(i+1)-1)-:8];
	end
endgenerate

integer incr =0;
task stream_WR(input integer WORD_NUM, input int packet_len = 0, input reg [DATA_WIDTH/8-1:0]FIRST_TKEEP = '1, input reg [DATA_WIDTH/8-1:0]SEC_TKEEP = '1);
begin
	@ (posedge input_clk_ST_sig)begin 
			i_AXI_slave_valid_p = 1'b1;
			for(int i =0; i<DATA_WIDTH/8;++i)begin
				i_AXI_slave_data[((i+1)*8-1) -:8] = i+incr;				
			end
			i_AXI_slave_tkeep = FIRST_TKEEP;
			++incr;
			i_AXI_slave_tlast  = 1'b0;
	end	 
	for(int i=0;i<WORD_NUM;++i)begin		  
			@ (posedge input_clk_ST_sig)begin 
				i_AXI_slave_valid_p = 1'b1;
				for(int i =0; i<DATA_WIDTH/8;++i)begin
					i_AXI_slave_data[((i+1)*8-1) -:8] = i+incr;				
				end
				i_AXI_slave_tkeep = SEC_TKEEP;
				++incr;
				i_AXI_slave_tlast = 1'b0;
				if(packet_len && (incr%packet_len == 0))i_AXI_slave_tlast = 1'b1;
		  end	
		  
	end

	if(packet_len == 0)i_AXI_slave_tlast = 1'b1;
	
	@ (posedge input_clk_ST_sig)begin
				i_AXI_slave_valid_p = 1'b0;
				i_AXI_slave_tkeep = '0;
				i_AXI_slave_tlast  = 1'b0;
	end
	incr =0;
end
endtask

int errors_counter=0;
initial  
forever begin  
	@ (posedge input_clk_ST_sig)begin  
		if(o_AXI_master_valid_p)begin
			if ( shift_val != 0 )
				assert ( ( shifted_bytes[0] == shifted_bytes[DATA_WIDTH/8-1] ) || ( ( shifted_bytes[0] == 2 ) && o_AXI_master_tkeep[DATA_WIDTH/8-1] ) ) $display("Packet is ok..");
				else begin 
					$error ("WRONG PACKET");
					++errors_counter;					
				end
			else 
				assert ( ( shifted_bytes[0] == (shifted_bytes[DATA_WIDTH/8-1] - (DATA_WIDTH/8-1)) ) ) $display("Packet is ok..");
				else begin
					$error ("WRONG PACKET WITHOUT SHIFT");
					++errors_counter;					
				end					
		end
	end
end

initial  
begin  
// Case from task
 #200 reset_n = 1'b1;
 #1000;
     shift_val = 2;
	 stream_WR(1,0,'1,1);
	 
//////PACKETS WITHOUT SHIFTING
 #2000;
     shift_val = 0; 
	 stream_WR(1);	

//////TOO SHORT PACKET
 #2000;
     shift_val = 2; 
	 @ (posedge input_clk_ST_sig)begin 
			i_AXI_slave_valid_p = 1'b1;
			for(int i =0; i<DATA_WIDTH/8;++i)begin
				i_AXI_slave_data[((i+1)*8-1) -:8] = i+incr;				
			end
			i_AXI_slave_tkeep = '1;
			++incr;
			i_AXI_slave_tlast  = 1'b1;
	end		  
			@ (posedge input_clk_ST_sig)begin 
				i_AXI_slave_valid_p = 1'b0;
				i_AXI_slave_tlast = 1'b0;
				incr = 0;
		  end	

//////FEW PACKETS 
 #1700;
     shift_val = 28;
 #100;
	 stream_WR(12,2);	
 #1700;
     shift_val = 22;
 #100;
	 stream_WR(6);
///////CHANGE SHIFT DINAMICALY
 #1700;
     shift_val = 1;
 #100;
	 fork
	 	begin
	 		stream_WR(10);	
	 	end
	 	begin
	 		@ (posedge input_clk_ST_sig)
			 	shift_val = 2; 
			 @ (posedge input_clk_ST_sig)begin
			  
			  end
			 @ (posedge input_clk_ST_sig)
			 	shift_val = 3;
			 @ (posedge input_clk_ST_sig)begin
			  
			  end
			 @ (posedge input_clk_ST_sig)begin
			  
			  end 
			@ (posedge input_clk_ST_sig)
			 	shift_val = 22;
	 	end
	 join
	 
	 
//////ALL SHIFTS 
 for(int i=0;i <DATA_WIDTH/8;++i)begin 
	 #1700;
		 shift_val = i;
	 #100;
		 stream_WR(2);
 end	
 
 #2000;
 $display("TEST IS OVER. ERRORS: ");
 $display(errors_counter);
end
endmodule