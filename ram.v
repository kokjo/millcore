module ram (
    clk,
    mem_valid, mem_ready, mem_addr, mem_rdata, mem_wdata, mem_wstrb
);
    localparam RAM_DEPTH = 1024;
    input clk;
    input mem_valid;
    output reg mem_ready;
    input [31:0] mem_addr;
    output reg [31:0] mem_rdata;
    input [31:0] mem_wdata;
    input [3:0] mem_wstrb;
    
    wire [29:0] mem_word = mem_addr >> 2;

    reg [31:0] mem[0:RAM_DEPTH-1];

    always @(posedge clk) begin
        mem_ready <= 0;
        if(mem_valid && !mem_ready) begin
            mem_ready <= 1;
            mem_rdata <= mem[mem_addr];
            if(mem_wstrb[0]) mem[mem_word][ 7: 0] <= mem_wdata[ 7 :0];
            if(mem_wstrb[1]) mem[mem_word][15: 8] <= mem_wdata[15: 8];
            if(mem_wstrb[2]) mem[mem_word][23:16] <= mem_wdata[23:16];
            if(mem_wstrb[3]) mem[mem_word][31:24] <= mem_wdata[31:24];
        end
    end

endmodule

