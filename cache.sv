`include "constants.sv"

module cache(
  input clk,
  input reset,

  input wire [`ADDR1_BUS_LEN - 1:0] A1,
  inout wire [`DATA1_BUS_LEN - 1 : 0] D1,
  inout wire [`CTR1_BUS_LEN - 1 : 0] C1,

  output wire [`ADDR2_BUS_LEN - 1 : 0] A2,
  inout wire [`DATA2_BUS_LEN - 1 : 0] D2,
  inout wire [`CTR2_BUS_LEN - 1 : 0] C2

);

typedef enum logic [3:0] {
  IDLE,
  READ_ADDR1,
  READ_ADDR2,
  CHECK_CACHE,
  HIT_READ,
  HIT_WRITE,
  MISS_READ,
  MISS_WRITE,
  PROCESS_COMMAND
} state_cache;

typedef enum logic [`CTR1_BUS_LEN - 1 : 0] {
  C1_NOP,
  C1_INVALIDATE,
  C1_READ_8,
  C1_WRITE_8,
  C1_READ_16,
  C1_WRITE_16,
  C1_READ_32,
  C1_WRITE_32,
  C1_RESPONSE
} c1_commands;

state_cache state;
c1_commands current_cmd;

wire [`CTR1_BUS_LEN - 1 : 0] C1_in;
wire [`DATA1_BUS_LEN - 1 : 0] D1_in;
assign C1_in = C1;
assign D1_in = D1;

logic [`CTR1_BUS_LEN - 1 : 0] C1_out;
logic [`DATA1_BUS_LEN - 1 : 0] D1_out;
logic C1_writing_out;
logic D1_writing_out;
assign C1 = C1_writing_out ? C1_out : 'z;
assign D1 = D1_writing_out ? D1_out : 'z;

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

logic [`TAG_LEN + `INDEX_LEN + `OFFSET_LEN - 1 : 0] addr1;

logic [`CACHE_LINE_SIZE * 8 - 1 : 0] cache_data[`CACHE_SET_COUNT][`CACHE_WAY];
logic [`TAG_LEN - 1 : 0] cache_tag[`CACHE_SET_COUNT][`CACHE_WAY];
logic cache_dirty[`CACHE_SET_COUNT][`CACHE_WAY];
logic cache_valid[`CACHE_SET_COUNT][`CACHE_WAY];

logic [`LRU_AGE_LEN - 1 : 0] lru_age[`CACHE_SET_COUNT][`CACHE_WAY];
logic bit_plru [`CACHE_SET_COUNT][`CACHE_WAY]; 

reg [`INDEX_LEN - 1 : 0] set_index;
reg [`TAG_LEN - 1 : 0] tag;
reg [`OFFSET_LEN - 1 : 0] offset;

assign set_index = addr1[`INDEX_LEN + `OFFSET_LEN - 1 : `OFFSET_LEN];
assign tag = addr1[`TAG_LEN + `INDEX_LEN + `OFFSET_LEN - 1 : `OFFSET_LEN + `INDEX_LEN];
assign offset = addr1[`OFFSET_LEN - 1 : 0];

reg [1:0] hit_line_index = 0;

always @(posedge clk, posedge reset) begin

  if(reset) begin
    state <= IDLE;

  end else begin
    case (state)
      IDLE : begin
        if (C1_in != C1_NOP) begin
          state <= READ_ADDR1;
          current_cmd <= C1_in;
        end
      end

      READ_ADDR1 : begin
        addr1[`TAG_LEN + `INDEX_LEN + `OFFSET_LEN - 1 : `OFFSET_LEN] <= A1;
        state <= READ_ADDR2;
      end

      READ_ADDR2 : begin
        addr1[`OFFSET_LEN - 1 : 0] <= A1[`OFFSET_LEN - 1 : 0];
        state <= CHECK_CACHE;
      end

      CHECK_CACHE : begin

        if(current_cmd == C1_READ_8 || current_cmd == C1_READ_16 || current_cmd == C1_READ_32) begin
          state <= MISS_READ;
          D1_writing_out <= 0;
          D2_writing_out <= 0;
        end else begin
          state <= MISS_WRITE;
          D1_writing_out <= 0;
          D2_writing_out <= 0;
        end
        
        for(int i = 0; i < `CACHE_WAY; i++) begin
          if (cache_tag[set_index][i] == tag && cache_valid[set_index][i]) begin
            hit_line_index <= i;

            if(current_cmd == C1_READ_8 || current_cmd == C1_READ_16 || current_cmd == C1_READ_32) begin
              state <= HIT_READ;
              D1_writing_out <= 1;
            end else begin
              state <= HIT_WRITE;
              D1_writing_out <= 0;
            end

          end
        end
      end

      HIT_READ : begin


        case (current_cmd)

        C1_READ_8 : begin
          cache_data[set_index][hit_line_index][7:0];
        end

        C1_READ_16 : begin
          
        end

        C1_READ_32 : begin
          
        end

        endcase

      end

      HIT_WRITE : begin
        case (current_cmd)
        
        C1_WRITE_8 : begin
          
        end

        C1_WRITE_16 : begin
          
        end

        C1_WRITE_32 : begin
          
        end

        endcase
        
      end


    endcase
    
  end


end


endmodule
