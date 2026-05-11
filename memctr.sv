`include "constants.sv"

module memctr(
  input clk,
  input reset,
  
  input wire [`ADDR2_BUS_LEN - 1:0] A2,
  inout wire [`DATA2_BUS_LEN - 1:0] D2,
  inout wire [`CTR2_BUS_LEN - 1:0] C2

);

wire [`CTR2_BUS_LEN - 1:0] C2_in;
wire [`DATA2_BUS_LEN - 1:0] D2_in;

assign C2_in = C2;
assign D2_in = D2;

logic [`CTR2_BUS_LEN - 1:0] C2_out;
logic [`DATA2_BUS_LEN - 1:0] D2_out;

logic C2_writing_out;
logic D2_writing_out;

assign C2 = C2_writing_out ? C2_out : 'z;
assign D2 = D2_writing_out ? D2_out : 'z;

state_memctr state;

logic [`ADDR2_BUS_LEN - 1:0] addr2;

reg [4:0] cnt = 0;

logic [`CACHE_LINE_SIZE*8 - 1:0] data;

always @(posedge clk, posedge reset) begin

  if(reset) begin
    C2_writing_out <= 0;
    D2_writing_out <= 0;
    C2_out <= C2_NOP;
    D2_out <= 0;
    state <= START;
    cnt <= 0;
    addr2 <= '0;
    data <= '0;

  end else begin
    case (state)
      START : begin
        C2_writing_out <= 0;
        D2_writing_out <= 0;
        C2_out <= C2_NOP;
        
        case (C2_in)
          C2_READ : begin
            state <= READ_MEMORY;
            addr2 <= A2;
          end
          
          C2_WRITE : begin
            state <= WRITE_DATA;
            addr2 <= A2;
          end

          C2_NOP : begin
          end

          default: begin
            state <= START;
          end
        endcase
      end

      READ_MEMORY : begin
        data <= '0;
        cnt <= 0;
        state <= READ_RESPONSE;
      end

      WRITE_DATA : begin
        data[cnt * `DATA2_BUS_LEN +: `DATA2_BUS_LEN] <= D2_in;
        cnt <= cnt + 1;

        if(cnt == (`CACHE_LINE_SIZE * 8 / `DATA2_BUS_LEN) - 1) begin
          cnt <= 0;
          state <= WRITE_RESPONSE;
        end

      end

      WRITE_RESPONSE : begin
        C2_writing_out <= 1;
        C2_out <= C2_RESPONSE;
        D2_writing_out <= 0;
        state <= START;
      end

      READ_RESPONSE : begin
        C2_writing_out <= 1;
        C2_out <= C2_RESPONSE;

        D2_writing_out <= 1;
        D2_out <= data[cnt * `DATA2_BUS_LEN +: `DATA2_BUS_LEN];
        
        cnt <= cnt + 1;

        if (cnt == (`CACHE_LINE_SIZE * 8 / `DATA2_BUS_LEN)) begin
          cnt <= 0;

          D2_writing_out <= 0;
          C2_writing_out <= 0;

          state <= START;
        end
      end

      default: begin
        state <= START;
        C2_writing_out <= 0;
        D2_writing_out <= 0;
      end
    endcase
  end
end

endmodule