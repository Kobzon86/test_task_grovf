
module Task_ip#(
parameter DATA_WIDTH=512

) (
	input clk,
	input reset_n,
	
	input [$clog2(DATA_WIDTH/8)-1:0]shift_val,
	
	input [DATA_WIDTH-1:0]i_AXI_slave_data,
	input i_AXI_slave_valid_p,
	input [DATA_WIDTH/8-1:0]i_AXI_slave_tkeep,
	input i_AXI_slave_tlast,
	output o_AXI_slave_ready,
	
	output logic [DATA_WIDTH-1:0]o_AXI_master_data,
	output logic o_AXI_master_valid_p,
	output logic [DATA_WIDTH/8-1:0]o_AXI_master_tkeep,
	output logic o_AXI_master_tlast,
	input i_AXI_master_ready
);
localparam PIPELINE =  (DATA_WIDTH==512) ? 6:5; 
// available pipeline for 512: 1,2,3,6 

localparam SHIFT_RANGE = $clog2(DATA_WIDTH/8)-1;
localparam BYTE_NUM = DATA_WIDTH/8;

logic [SHIFT_RANGE+1:0]shift_val_buf[PIPELINE:0];
logic [SHIFT_RANGE+3:0]shift_val_clcltd[PIPELINE-1:0];
logic [2*DATA_WIDTH-1:0]data_buf;
logic [2*DATA_WIDTH-1:0]data_shift_buf[PIPELINE-1:0];
wire [2*DATA_WIDTH-1:0] data_inv = {data_buf[DATA_WIDTH-1:0],data_buf[2*DATA_WIDTH-1:DATA_WIDTH]};
logic [PIPELINE:0]valid_buf;
logic [2*BYTE_NUM-1:0]tkeep_buf;
logic [BYTE_NUM-1:0]tkeep_shift_buf[PIPELINE-1:0];
logic [PIPELINE:0]tlast_buf;
logic master_tlast;

always@(posedge clk  or negedge reset_n) 
	if(!reset_n) begin
		o_AXI_master_valid_p <= 1'b0;
		shift_val_buf[0] <= '0;
		valid_buf <= '0;
		master_tlast <= 1'b0;
	end
	else begin	

		shift_val_buf[0] <= shift_val; //buffering shift value
		if(i_AXI_master_ready) begin	
			for(int i=0; i<PIPELINE;++i)begin
				shift_val_buf[i+1] <= shift_val_buf[i];
				//separating one shift to several smaller 
				shift_val_clcltd[i] <= (shift_val_buf[i][ ( ( i + 1 )*SHIFT_RANGE/PIPELINE ) -: ( SHIFT_RANGE/PIPELINE ) + 1 ] << 3) << (i*($clog2(DATA_WIDTH/8)/PIPELINE));
				if(i==0) begin
					data_shift_buf[i] <= data_inv >> shift_val_clcltd[i]; // first shift 
					tkeep_shift_buf[i] <= {tkeep_buf[BYTE_NUM-1:0], tkeep_buf[2*BYTE_NUM-1:BYTE_NUM]} >> (shift_val_clcltd[i]>>3);
				end
				else begin
					data_shift_buf[i] <= data_shift_buf[i-1] >> shift_val_clcltd[i];        // shift steps
					tkeep_shift_buf[i] <= tkeep_shift_buf[i-1] >> (shift_val_clcltd[i]>>3); ////////////// 
				end
			end

			data_buf <= {data_buf[DATA_WIDTH-1:0], i_AXI_slave_data}; //buffering
			tkeep_buf <= {tkeep_buf[BYTE_NUM-1:0], i_AXI_slave_tkeep};///////////			
			
			valid_buf <= {valid_buf[PIPELINE-1:0], i_AXI_slave_valid_p};//buffering
			tlast_buf <= {tlast_buf,i_AXI_slave_tlast};
		end
		o_AXI_master_valid_p <= ( |shift_val_buf[PIPELINE] ) ? ((&valid_buf[PIPELINE-:2]) && (!tlast_buf[PIPELINE])) : valid_buf[PIPELINE];
		master_tlast <=   ( |shift_val_buf[PIPELINE-1] ) ? (tlast_buf[PIPELINE-1]) : tlast_buf[PIPELINE];
	end
assign o_AXI_master_tkeep = tkeep_shift_buf[PIPELINE-1];
assign o_AXI_master_data  = data_shift_buf[PIPELINE-1];
assign o_AXI_slave_ready = i_AXI_master_ready;
assign o_AXI_master_tlast = master_tlast & o_AXI_master_valid_p;
endmodule
