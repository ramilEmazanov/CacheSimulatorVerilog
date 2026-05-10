`include "constants.sv"

module cache #(parameter IS_PLRU = 0)(
  input clk,
  input reset,

  input wire [`ADDR1_BUS_LEN - 1:0] A1,
  inout wire [`DATA1_BUS_LEN - 1 : 0] D1,
  inout wire [`CTR1_BUS_LEN - 1 : 0] C1,

  output logic [`ADDR2_BUS_LEN - 1 : 0] A2,
  inout wire [`DATA2_BUS_LEN - 1 : 0] D2,
  inout wire [`CTR2_BUS_LEN - 1 : 0] C2,

  output logic [31:0] hits,
  output logic [31:0] accesses
);

typedef enum logic [4:0] {
  IDLE,
  READ_ADDR1,
  READ_ADDR2,
  CHECK_CACHE,
  HIT_READ_1,
  HIT_READ_2,
  HIT_READ_RESPONSE,
  HIT_WRITE_1,
  HIT_WRITE_2,
  HIT_WRITE_RESPONSE,
  MISS_READ_GET_VICTIM,
  MISS_SEND_ADDR,
  MISS_GET_DATA,
  WRITE_DIRTY,
  WRITE_DIRTY_DATA,
  WAIT_WRITE_RESPONSE,
  INVALIDATE_STATE,
  PROCESS_COMMAND
} state_cache;

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

wire [`INDEX_LEN - 1 : 0] set_index;
wire [`TAG_LEN - 1 : 0] tag;
wire [`OFFSET_LEN - 1 : 0] offset;

assign set_index = addr1[`INDEX_LEN + `OFFSET_LEN - 1 : `OFFSET_LEN];
assign tag = addr1[`TAG_LEN + `INDEX_LEN + `OFFSET_LEN - 1 : `OFFSET_LEN + `INDEX_LEN];
assign offset = addr1[`OFFSET_LEN - 1 : 0];

reg [1:0] hit_line_index = 0;
reg [1:0] victim_index = 0;
reg [4:0] cnt = 0;

always @(posedge clk, posedge reset) begin

  if (reset) begin
    state <= IDLE;
    current_cmd <= C1_NOP;

    C1_writing_out <= 0;
    D1_writing_out <= 0;
    C2_writing_out <= 0;
    D2_writing_out <= 0;

    C1_out <= C1_NOP;
    D1_out <= '0;
    C2_out <= '0;
    D2_out <= '0;

    addr1 <= '0;
    hit_line_index <= '0;
    victim_index <= '0;
    cnt <= '0;

    hits <= 0;
    accesses <= 0;

    for (int i = 0; i < `CACHE_SET_COUNT; i++) begin
      for (int j = 0; j < `CACHE_WAY; j++) begin
        cache_valid[i][j] <= 0;
        cache_dirty[i][j] <= 0;
        cache_tag[i][j] <= '0;
        cache_data[i][j] <= '0;
        lru_age[i][j] <= j;
        bit_plru[i][j] <= 0;
      end
    end
  end else begin
    case (state)
      IDLE : begin
        C1_writing_out <= 0;
        D1_writing_out <= 0;
        C2_writing_out <= 0;
        D2_writing_out <= 0;
        C1_out <= C1_NOP;
        C2_out <= C2_NOP;

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
        logic is_access;
        logic is_hit;
        is_access = 0;
        is_hit = 0;
        
        if (current_cmd == C1_INVALIDATE) begin
          state <= INVALIDATE_STATE;
        end else begin
          state <= MISS_READ_GET_VICTIM;
          is_access = 1;
        end

        if (is_access) begin
          accesses <= accesses + 1;
        end

        for(int i = 0; i < `CACHE_WAY; i++) begin
          if (cache_tag[set_index][i] == tag && cache_valid[set_index][i]) begin
            hit_line_index <= i;
            is_hit = 1;

            if(current_cmd == C1_READ_8 || current_cmd == C1_READ_16 || current_cmd == C1_READ_32) begin
              state <= HIT_READ_1;
            end else begin
              state <= HIT_WRITE_1;
            end
          end
        end

        if (is_hit) begin
          hits <= hits + 1;
        end
      end

      INVALIDATE_STATE : begin
        for(int i = 0; i < `CACHE_WAY; ++i) begin
          if (cache_tag[set_index][i] == tag) begin
            cache_valid[set_index][i] <= 0;
            cache_dirty[set_index][i] <= 0;
          end
        end

        state <= IDLE;
      end

      HIT_READ_1 : begin
        D1_writing_out <= 1;
        C1_writing_out <= 1;

        case (current_cmd)
        C1_READ_8 : begin
          D1_out <= '0;
          D1_out[7:0] <= cache_data[set_index][hit_line_index][offset * 8 +: 8];
          C1_out <= C1_RESPONSE;
          state <= HIT_READ_RESPONSE;
        end

        C1_READ_16 : begin
          D1_out <= cache_data[set_index][hit_line_index][offset * 8 +: 16];
          C1_out <= C1_RESPONSE;
          state <= HIT_READ_RESPONSE;
        end

        C1_READ_32 : begin
          D1_out <= cache_data[set_index][hit_line_index][offset * 8 +: 16];
          C1_out <= C1_NOP;
          state <= HIT_READ_2;
        end

        default : begin
          state <= IDLE;
        end
        endcase
        
        if(IS_PLRU) begin
          bit_plru[set_index][hit_line_index] <= 1;
        end else begin

          lru_age[set_index][hit_line_index] <= 0;
          
          for(int i = 0; i < `CACHE_WAY; ++i) begin
            if(i != hit_line_index && cache_valid[set_index][i]) begin
              if(lru_age[set_index][hit_line_index] > lru_age[set_index][i]) begin
                lru_age[set_index][i] <= lru_age[set_index][i] + 1;
              end
            end
          end
        end
      end

      HIT_READ_2 : begin
        D1_out <= cache_data[set_index][hit_line_index][(offset + 2) * 8 +: 16];
        C1_out <= C1_RESPONSE;
        state <= HIT_READ_RESPONSE;
      end

      HIT_READ_RESPONSE : begin
        state <= IDLE;
        D1_writing_out <= 0;
        C1_writing_out <= 0;
      end

      HIT_WRITE_1 : begin
        D1_writing_out <= 0;
        C1_writing_out <= 1;

        cache_dirty[set_index][hit_line_index] <= 1;

        case (current_cmd)
        C1_WRITE_8 : begin
          cache_data[set_index][hit_line_index][offset * 8 +: 8] <= D1_in[7:0];
          C1_out <= C1_RESPONSE;
          state <= HIT_WRITE_RESPONSE;
        end

        C1_WRITE_16 : begin
          cache_data[set_index][hit_line_index][offset * 8 +: 16] <= D1_in[15:0];
          C1_out <= C1_RESPONSE;
          state <= HIT_WRITE_RESPONSE;
        end

        C1_WRITE_32 : begin
          cache_data[set_index][hit_line_index][offset * 8 +: 16] <= D1_in[15:0];
          C1_out <= C1_NOP;
          state <= HIT_WRITE_2;
        end

        endcase

        if(IS_PLRU) begin
          bit_plru[set_index][hit_line_index] <= 1;
        end else begin
          lru_age[set_index][hit_line_index] <= 0;
          
          for(int i = 0; i < `CACHE_WAY; ++i) begin
            if(i != hit_line_index && cache_valid[set_index][i]) begin
              if(lru_age[set_index][hit_line_index] > lru_age[set_index][i]) begin
              lru_age[set_index][i] <= lru_age[set_index][i] + 1;
              end
            end
          end
        end

      end

      HIT_WRITE_2 : begin
        cache_data[set_index][hit_line_index][(offset + 2) * 8 +: 16] <= D1_in;
        C1_out <= C1_RESPONSE;
        state <= HIT_WRITE_RESPONSE;      
      end

      HIT_WRITE_RESPONSE : begin
        state <= IDLE;
        C1_writing_out <= 0;
      end

      MISS_READ_GET_VICTIM : begin
        int found_invalid;
        int victim;
        
        victim = 0;
        found_invalid = 0;

        for(int i = 0; i < `CACHE_WAY; ++i) begin
          if(cache_valid[set_index][i] == 0 && found_invalid == 0) begin
            victim = i;
            found_invalid = 1;
          end 

          if(lru_age[set_index][i] > lru_age[set_index][victim] && found_invalid == 0) begin
            victim = i;
          end
        end

        victim_index <= victim;

        if(cache_valid[set_index][victim] && cache_dirty[set_index][victim] == 1) begin
          state <= WRITE_DIRTY;
          C2_writing_out <= 1;
        end else begin
          state <= MISS_SEND_ADDR;
          D2_writing_out <= 0;
        end
      end

      WRITE_DIRTY : begin
        C2_out <= C2_WRITE;
        A2[3:0] <= set_index;
        A2[13:4] <= cache_tag[set_index][victim_index];
        cnt <= 0;
        D2_writing_out <= 1;
        state <= WRITE_DIRTY_DATA;
      end

      WRITE_DIRTY_DATA : begin
        if (cnt < `CACHE_LINE_SIZE * 8 / `DATA2_BUS_LEN) begin                      
          D2_out <= cache_data[set_index][victim_index][cnt * `DATA2_BUS_LEN +: `DATA2_BUS_LEN];                                                              
          cnt <= cnt + 1;                                                             
        end else begin            
          D2_writing_out <= 0;                                                      
          C2_writing_out <= 0;
          cnt <= 0;                                                                 
          state <= WAIT_WRITE_RESPONSE;                                                 
        end
      end

      WAIT_WRITE_RESPONSE : begin
        C2_writing_out <= 0;
        D2_writing_out <= 0;
        if (C2_in == C2_RESPONSE) begin
          state <= MISS_SEND_ADDR;                                                 
        end
      end

      MISS_SEND_ADDR : begin
        C2_writing_out <= 1;
        D2_writing_out <= 0;
        C2_out <= C2_READ;
        A2[3:0] <= set_index;
        A2[13:4] <= tag;
        cnt <= 0;
        state <= PROCESS_COMMAND;
      end

      PROCESS_COMMAND : begin
        state <= MISS_GET_DATA;
      end

      MISS_GET_DATA : begin
        C2_writing_out <= 0;
        D2_writing_out <= 0;

        if(C2_in == C2_RESPONSE) begin
          if (cnt < `CACHE_LINE_SIZE * 8 / `DATA2_BUS_LEN - 1) begin
            cache_data[set_index][victim_index][cnt * `DATA2_BUS_LEN +: `DATA2_BUS_LEN] <= D2_in;
            cnt <= cnt + 1;

          end else begin

            cache_valid[set_index][victim_index] <= 1;
            cache_dirty[set_index][victim_index] <= 0;
            cache_tag[set_index][victim_index] <= tag;
            hit_line_index <= victim_index;
            cnt <= 0;

            if(current_cmd == C1_READ_8 || current_cmd == C1_READ_16 || current_cmd == C1_READ_32) begin
              state <= HIT_READ_1;
            end else begin
              state <= HIT_WRITE_1;
            end
            
          end
        end
      end

      default : begin
        state <= IDLE;
        C1_writing_out <= 0;
        D1_writing_out <= 0;
        C2_writing_out <= 0;
        D2_writing_out <= 0;
      end
    endcase
  end
end

endmodule