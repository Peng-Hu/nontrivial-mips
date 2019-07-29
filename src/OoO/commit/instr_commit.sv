`include "cpu_defs.svh"

module instr_commit(
	// commit ROB
	input  rob_packet_t  rob_packet,
	input  rob_index_t   [1:0] rob_reorder,
	input  logic         rob_empty,
	output logic         rob_ack,

	// register requests
	output logic         [1:0] reg_we,
	output reg_addr_t    [1:0] reg_waddr,
	output uint32_t      [1:0] reg_wdata,

	// resolved branch
	output branch_resolved_t resolved_branch,

	// exception
	output except_req_t  except_req,
	input  cp0_regs_t    cp0_regs,
	input  logic [7:0]   interrupt_flag,

	// LSU store
	output data_memreq_t lsu_store_memreq,
	output logic         lsu_store_push,
	input  logic         lsu_store_full,

	// commit CP0
	output logic         commit_cp0,

	// commit HILO
	output logic         commit_mul,

	// commit flush request
	output logic         commit_flush,
	output virt_t        commit_flush_pc
);

// commit registers
assign reg_we[0] = rob_ack & rob_packet[0].valid & ~(except_req.valid & except_req.alpha_taken);
assign reg_we[1] = rob_ack & rob_packet[1].valid & ~except_req.valid;
for(genvar i = 0; i < 2; ++i) begin: gen_reg_requests
	assign reg_waddr[i] = rob_packet[i].dest;
	assign reg_wdata[i] = rob_packet[i].value;
end

logic  [1:0] is_store, is_mul;
logic  store_request, packet_ready;
assign packet_ready    = ~rob_packet[0].busy & ~rob_packet[1].busy & ~rob_empty;

assign is_store[0] = rob_packet[0].valid && rob_packet[0].fu == FU_STORE;
assign is_store[1] = rob_packet[1].valid && rob_packet[1].fu == FU_STORE;
assign is_mul[0] = rob_packet[0].valid && rob_packet[0].fu == FU_MUL;
assign is_mul[1] = rob_packet[1].valid && rob_packet[1].fu == FU_MUL;

assign store_request    = |is_store;
assign lsu_store_memreq = is_store[1] ? rob_packet[1].data.memreq : rob_packet[0].data.memreq;
assign lsu_store_push   = packet_ready & store_request & ~lsu_store_full;

assign commit_mul      = rob_ack && |is_mul && ~except_req.valid;
assign commit_cp0      = rob_ack && rob_packet[0].fu == FU_CP0 && ~except_req.valid;
assign resolved_branch = rob_ack ? rob_packet[0].data.resolved_branch : '0;

assign rob_ack         = packet_ready & (~store_request | store_request & ~lsu_store_full);
assign commit_flush    = 1'b0;
assign commit_flush_pc = '0;

except except_inst(
	.rst ( ~rob_ack ),
	.rob_packet,
	.cp0_regs,
	.interrupt_flag ( '0 ),
	.except_req
);

endmodule
