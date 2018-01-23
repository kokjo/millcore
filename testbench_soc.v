module testbench_soc();
    reg clk = 1;
    reg rst = 0;

    wire mem_valid;
    reg mem_ready;
    wire [31:0] mem_addr;
    reg [31:0] mem_rdata;

    soc soc0 (
        .clk(clk),
        .rst(rst),
        .mem_valid(mem_valid),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_rdata(mem_rdata)
    );

    reg [31:0] mem[0:255];

    always @(posedge clk) begin
        mem_ready <= 0;
        if(mem_valid && !mem_ready) begin
            mem_ready <= 1;
            mem_rdata <= mem[mem_addr[7:2]];
        end
    end

    always clk = #1 !clk;

    initial begin
        mem[0] = 32'hff000000; // rdrand
        mem[1] = 32'hfe000000; // rdtsc
        mem[2] = 32'he8100000; // shl r1, r0
        mem[3] = 32'hff120000;
        mem[4] = 32'h00000001; // drop 1        [1]
        mem[5] = 32'h10000004; // droprel 4     [pc, 1]
        mem[6] = 32'h00000001; // drop 1        [a, pc, b]
        mem[7] = 32'h20020000; // add r0, r2    [a+b, a, pc, a]
        mem[8] = 32'h22220000; // or r2, r2     [pc, a+b, a, pc, b]
        mem[9] = 32'h22440000; // or r4, r4     [b, pc, a+b, a, pc, b]
        mem[10] = 32'h40110000; // branch r1, r1
        $dumpfile("soc.vcd");
        $dumpvars;
        rst = 1;
        #1
        rst = 0;
        #1000
        $finish;
    end
endmodule
