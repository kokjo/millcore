module soc (
    // clock and reset
    clk, rst,
    // external memory interface
    mem_valid, mem_ready, mem_addr, mem_rdata, mem_wdata, mem_wstrb
);
    parameter RESET_PC = 32'h01000000;
    parameter RAM_WORDS = 1024;

    input clk, rst;

    wire cpu_valid;
    wire cpu_ready;
    wire [31:0] cpu_addr;
    wire [31:0] cpu_rdata;
    wire [31:0] cpu_wdata;
    wire [3:0] cpu_wstrb;

    cpu #(
        .RESET_PC(RESET_PC)
    ) cpu0 (
        .clk(clk),
        .rst(rst),
        .mem_valid(cpu_valid),
        .mem_ready(cpu_ready),
        .mem_addr(cpu_addr),
        .mem_rdata(cpu_rdata),
        .mem_wdata(cpu_wdata),
        .mem_wstrb(cpu_wstrb)
    ); 

    wire ram_valid = cpu_valid && cpu_addr[31:16] == 16'h0000;
    wire ram_ready;
    wire [31:0] ram_addr = cpu_addr;
    wire [31:0] ram_rdata;
    wire [31:0] ram_wdata = cpu_wdata;
    wire [3:0] ram_wstrb = cpu_wstrb;
    
    ram #(
        .RAM_WORDS(RAM_WORDS)
    ) ram0 (
        .clk(clk),
        .mem_valid(ram_valid),
        .mem_ready(ram_ready),
        .mem_addr(ram_addr),
        .mem_rdata(ram_rdata),
        .mem_wdata(ram_wdata),
        .mem_wstrb(ram_wstrb)
    );

    output mem_valid;
    input mem_ready;
    output [31:0] mem_addr;
    input [31:0] mem_rdata;
    output [31:0] mem_wdata;
    output [3:0] mem_wstrb;

    assign mem_valid = cpu_valid && cpu_addr >= 32'h01000000;
    assign mem_addr = cpu_addr;
    assign mem_wdata = cpu_wdata;
    assign mem_wstrb = cpu_wstrb;

    assign cpu_ready = (ram_valid && ram_ready) |
                       (mem_valid && mem_ready) ;

    assign cpu_rdata = (ram_valid && ram_ready) ? ram_rdata :
                       (mem_valid && mem_ready) ? mem_rdata :
                       32'hxxxxxxxx;
endmodule

module ram (
    clk,
    mem_valid, mem_ready, mem_addr, mem_rdata, mem_wdata, mem_wstrb
);
    parameter RAM_WORDS = 1024;
    input clk;
    input mem_valid;
    output reg mem_ready;
    input [31:0] mem_addr;
    output reg [31:0] mem_rdata;
    input [31:0] mem_wdata;
    input [3:0] mem_wstrb;
    
    wire [29:0] mem_word = mem_addr >> 2;

    reg [31:0] mem[0:RAM_WORDS-1];

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

