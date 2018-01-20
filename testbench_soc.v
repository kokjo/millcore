module testbench_soc();
    reg clk = 1;
    reg rst = 0;

    wire ext_mem_valid;
    reg ext_mem_ready;
    wire [7:0] ext_mem_addr;
    reg [31:0] ext_mem_rdata;

    reg [31:0] ext_mem[0:255];

    soc soc0(
        .clk(clk),
        .rst(rst),
        .ext_mem_valid(ext_mem_valid),
        .ext_mem_ready(ext_mem_ready),
        .ext_mem_addr(ext_mem_addr),
        .ext_mem_rdata(ext_mem_rdata)
    );

    always clk = #2 !clk;

    always @(posedge clk) begin
        ext_mem_ready <= 0;
        if(ext_mem_valid && !ext_mem_ready) begin
            ext_mem_ready <= 1;
            ext_mem_rdata <= ext_mem[ext_mem_addr];
        end
    end

    initial begin
        ext_mem[0] = 32'h00000001; // drop 1        [1]
        ext_mem[1] = 32'h10000004; // droprel 4     [pc, 1]
        ext_mem[2] = 32'h00000001; // drop 1        [a, pc, b]
        ext_mem[3] = 32'h20020000; // add r0, r2    [a+b, a, pc, a]
        ext_mem[4] = 32'h22220000; // or r2, r2     [pc, a+b, a, pc, b]
        ext_mem[5] = 32'h22440000; // or r4, r4     [b, pc, a+b, a, pc, b]
        ext_mem[6] = 32'h30110000; // branch r1, r1
        $dumpfile("soc.vcd");
        $dumpvars;
        rst = 1;
        #2
        rst = 0;
        #1000
        $finish;
    end
endmodule
