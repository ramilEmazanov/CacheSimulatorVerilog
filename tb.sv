`include "constants.sv"
`include "cache.sv"
`include "memctr.sv"

module tb;

logic clk = 0;
always #1 clk = ~clk;

logic reset = 0;

logic [`ADDR1_BUS_LEN-1:0] A1_lru;
wire [`DATA1_BUS_LEN-1:0] D1_lru;
wire [`CTR1_BUS_LEN-1:0] C1_lru;

logic [`ADDR2_BUS_LEN-1:0] A2_lru;
wire [`DATA2_BUS_LEN-1:0] D2_lru;
wire [`CTR2_BUS_LEN-1:0] C2_lru;

logic [`DATA1_BUS_LEN-1:0] D1_lru_out;
logic [`CTR1_BUS_LEN-1:0] C1_lru_out;
logic D1_lru_writing;
logic C1_lru_writing;

assign D1_lru = D1_lru_writing ? D1_lru_out : 'z;
assign C1_lru = C1_lru_writing ? C1_lru_out : 'z;

logic [31:0] hits_lru;
logic [31:0] accesses_lru;

logic [`ADDR1_BUS_LEN-1:0] A1_blru;
wire [`DATA1_BUS_LEN-1:0] D1_blru;
wire [`CTR1_BUS_LEN-1:0] C1_blru;

logic [`ADDR2_BUS_LEN-1:0] A2_blru;
wire [`DATA2_BUS_LEN-1:0] D2_blru;
wire [`CTR2_BUS_LEN-1:0] C2_blru;

logic [`DATA1_BUS_LEN-1:0] D1_blru_out;
logic [`CTR1_BUS_LEN-1:0] C1_blru_out;

logic D1_blru_writing;
logic C1_blru_writing;

assign D1_blru = D1_blru_writing ? D1_blru_out : 'z;
assign C1_blru = C1_blru_writing ? C1_blru_out : 'z;

logic [31:0] hits_blru;
logic [31:0] accesses_blru;


cache #(.IS_PLRU(0)) cache_lru (
    .clk (clk),
    .reset (reset),
    .A1 (A1_lru),
    .D1 (D1_lru),
    .C1 (C1_lru),
    .A2 (A2_lru),
    .D2 (D2_lru),
    .C2 (C2_lru),
    .hits (hits_lru),
    .accesses (accesses_lru)
);

memctr mem_lru (
    .clk (clk),
    .reset (reset),
    .A2 (A2_lru),
    .D2 (D2_lru),
    .C2 (C2_lru)
);

cache #(.IS_PLRU(1)) cache_blru (
    .clk (clk),
    .reset (reset),
    .A1 (A1_blru),
    .D1 (D1_blru),
    .C1 (C1_blru),
    .A2 (A2_blru),
    .D2 (D2_blru),
    .C2 (C2_blru),
    .hits (hits_blru),
    .accesses (accesses_blru)
);

memctr mem_blru (
    .clk (clk),
    .reset (reset),
    .A2 (A2_blru),
    .D2 (D2_blru),
    .C2 (C2_blru)
);

task send_cmd_lru(
    input logic [`ADDRESS_LEN-1:0] addr,
    input logic [`CTR1_BUS_LEN-1:0] cmd,
    input logic [31:0] data
);
    @(negedge clk);
    C1_lru_writing = 1;
    C1_lru_out = cmd;

    @(negedge clk);
    A1_lru = addr[`ADDRESS_LEN-1 : `OFFSET_LEN];

    if (cmd == C1_WRITE_8 || cmd == C1_WRITE_16 || cmd == C1_WRITE_32) begin
        D1_lru_writing = 1;
        D1_lru_out = data[15:0];
    end

    @(negedge clk);
    A1_lru[`OFFSET_LEN - 1:0] = addr[`OFFSET_LEN - 1 : 0];

    if (cmd == C1_WRITE_32) begin
        D1_lru_out = data[15:0];
    end

    @(negedge clk);
    C1_lru_writing = 0;

    if (cmd == C1_WRITE_32) begin
        @(posedge clk);
        @(negedge clk);
        D1_lru_out = data[31:16];
    end

    begin : wait_resp
        while (1) begin
            @(posedge clk);
            if (C1_lru === C1_RESPONSE) begin
                disable wait_resp;
            end
        end
    end

    @(negedge clk);
    D1_lru_writing = 0;

    @(negedge clk);
endtask

task send_cmd_plru(
    input logic [`ADDRESS_LEN-1:0] addr,
    input logic [`CTR1_BUS_LEN-1:0] cmd,
    input logic [31:0] data
);
    @(negedge clk);
    C1_blru_writing = 1;
    C1_blru_out = cmd;

    @(negedge clk);
    A1_blru = addr[`ADDRESS_LEN-1 : `OFFSET_LEN];

    if (cmd == C1_WRITE_8 || cmd == C1_WRITE_16 || cmd == C1_WRITE_32) begin
        D1_blru_writing = 1;
        D1_blru_out = data[15:0];
    end

    @(negedge clk);
    A1_lru[`OFFSET_LEN - 1:0] = addr[`OFFSET_LEN - 1 : 0];

    if (cmd == C1_WRITE_32) begin
        D1_blru_out = data[15:0];
    end

    @(negedge clk);
    C1_blru_writing = 0;

    if (cmd == C1_WRITE_32) begin
        @(posedge clk);
        @(negedge clk);
        D1_blru_out = data[31:16];
    end

    begin : wait_resp
        while (1) begin
            @(posedge clk);

            if (C1_blru === C1_RESPONSE) begin
                disable wait_resp;
            end

        end
    end

    @(negedge clk);
    D1_blru_writing = 0;

    @(negedge clk);
endtask


int M = 64;
int N = 60;
int K = 32;

logic [`ADDRESS_LEN-1:0] BEGIN_A = `ADDRESS_LEN'h128;
logic [`ADDRESS_LEN-1:0] BEGIN_B = `ADDRESS_LEN'h928;
logic [`ADDRESS_LEN-1:0] BEGIN_C = `ADDRESS_LEN'h1828;

initial begin
    A1_lru = '0;
    C1_lru_out = C1_NOP;
    D1_lru_out = '0;
    C1_lru_writing = 0;
    D1_lru_writing = 0;

    reset = 1;
    repeat(1) @(posedge clk);
    @(negedge clk);
    reset = 0;

    for (int y = 0; y < M; y++) begin
        for (int x = 0; x < N; x++) begin
            logic [`ADDRESS_LEN-1:0] addr_c;

            for (int k = 0; k < K; k++) begin
                logic [`ADDRESS_LEN-1:0] addr_a;
                logic [`ADDRESS_LEN-1:0] addr_b;

                addr_a = BEGIN_A + y*K + k;
                send_cmd_lru(addr_a, C1_READ_8, 32'h0);
                send_cmd_plru(addr_a, C1_READ_8, 32'h0);

                addr_b = BEGIN_B + (k*N + x)*2;
                send_cmd_lru(addr_b, C1_READ_16, 32'h0);
                send_cmd_plru(addr_b, C1_READ_16, 32'h0);
            end

            addr_c = BEGIN_C + (y*N + x)*4;
            send_cmd_lru(addr_c, C1_WRITE_32, 32'h0);
            send_cmd_plru(addr_c, C1_WRITE_32, 32'h0);

        end
    end

    $display("| replacement |  hitrate  |    hits    |  accesses  |\n| :---------- | --------: | ---------: | ----------: |\n| LRU         |  %3.4f%% | %10d | %10d |\n| bpLRU       |  %3.4f%% | %10d | %10d |\n"
    ,100.0 * real'(hits_lru) / real'(accesses_lru), hits_lru, accesses_lru, 100.0 * real'(hits_blru) / real'(accesses_blru), hits_blru, accesses_blru);
    $finish;
end

endmodule