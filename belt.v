module belt (clk, rst, drop, wdata, r1, rdata1, r2, rdata2);
    input clk, rst;

    input drop;
    input [31:0] wdata;

    input [3:0] r1;
    output reg [31:0] rdata1;

    input [3:0] r2;
    output reg [31:0] rdata2;

    reg [31:0] belt [0:15];
    reg [3:0] idx;


    always @(posedge clk) begin
        if(rst) begin
            idx <= 0;
        end else begin
            rdata1 <= belt[(idx-r1-1) & 4'hf];
            rdata2 <= belt[(idx-r2-1) & 4'hf];

            if(drop) begin
                belt[idx] <= wdata;
                idx <= idx + 1;
            end
        end
    end
endmodule
