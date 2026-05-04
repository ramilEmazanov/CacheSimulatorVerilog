`include "constants.sv"

module memctr(
  input clk,
  input reset,
  
  input wire [`ADDR2_BUS_LEN - 1:0] A2,
  inout wire [`DATA2_BUS_LEN - 1:0] D2,
  inout wire [`CTR2_BUS_LEN - 1:0] C2

);

// то что memctr видит на шине C2
wire [`CTR2_BUS_LEN - 1:0] C2_in;
wire [`DATA2_BUS_LEN - 1:0] D2_in;

assign C2_in = C2;
assign D2_in = D2;

// то что memctr хочет выдать на шину C2
logic [`CTR2_BUS_LEN - 1:0] C2_out;
logic [`DATA2_BUS_LEN - 1:0] D2_out;

logic C2_writing_out;
logic D2_writing_out;

assign C2 = C2_writing_out ? C2_out : 'z;
assign D2 = D2_writing_out ? D2_out : 'z;

typedef enum logic [2:0] {
  IDLE,
  READ_MEMORY,
  READ_RESPONSE,
  WRITE_DATA,
  WRITE_RESPONSE
} state_t;

typedef enum logic [2:0] {
    C2_NOP      = 3'b000,
    C2_READ     = 3'b001,
    C2_WRITE    = 3'b010,
    C2_RESPONSE = 3'b011
} c2_commands;

state_t state;

logic [`ADDR2_BUS_LEN - 1:0] addr2;

reg [4:0]cnt = 0;

// 255
logic [`CACHE_LINE_SIZE*8 - 1:0] data;

always @(posedge clk, posedge reset) begin

  if(reset) begin
    C2_writing_out <= 0;
    D2_writing_out <= 0;
    C2_out <= C2_NOP;
    D2_out <= 0;
    state <= IDLE;

  end else begin
    case (state)
      IDLE : begin
        case (C2_in)
          C2_READ : begin
            state <= READ_MEMORY;
            addr2 <= A2;
          end
          
          C2_WRITE : begin
            state <= WRITE_DATA;
            addr2 <= A2;
          end
          C2_RESPONSE : begin
            
          end

          C2_NOP : begin
            
          end
        endcase
      end

      READ_MEMORY : begin
        // в дату записываем хоть что-то. отдаем data в READ_RESPONSE
        data <= '0;
        cnt <= 0;
        state <= READ_RESPONSE;
      end

      WRITE_DATA : begin
        // data[BASE +: WIDTH] 
        // data[BASE + WIDTH - 1 : BASE]
        data[cnt * `DATA2_BUS_LEN * 8 +: `DATA2_BUS_LEN * 8] <= D2_in;
        cnt <= cnt + 1;

        // -1 because cnt will update only on next tick
        if(cnt == (`CACHE_LINE_SIZE * 8 / `DATA2_BUS_LEN) - 1) begin
          cnt <= 0;
          state <= WRITE_RESPONSE;  
        end

      end

      WRITE_RESPONSE : begin
        // for(int i = 0; i < `CACHE_LINE_SIZE; ++i) begin
        //   // Maybe write data in memory
        // end

        // Сейчас будем отдавать команду
        C2_writing_out <= 1;
        // Отдаем на выход C2_RESPONSE
        C2_out <= C2_RESPONSE;
        // Мы ничего не читаем
        D2_writing_out <= 0;
        state <= IDLE;
      end

      READ_RESPONSE : begin
        D2_writing_out <= 1;
        // тут отдаем данные
      end
    endcase
  end
end

endmodule