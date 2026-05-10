`ifndef CONSTANTS_SV
`define CONSTANTS_SV

// MEMORY_SIZE yields ADDRESS_LEN 
//as we need to encode all of the bytes 
`define ADDRESS_LEN 19

// ADDRES_LEN - INDEX_LEN - OFFSET_LEN
`define TAG_LEN 10
`define INDEX_LEN 4 // Given
`define OFFSET_LEN 5 // Given
`define CACHE_SIZE 2048 // Given 

// OFFSET_LEN yields CACHE_LINE_SIZE
`define CACHE_LINE_SIZE 32 // Byte

// CACHE_SIZE / CACHE_LINE_SIZE = 64
`define CACHE_LINE_COUNT 64

// INDEX_LEN = 4 -> 2^4 = 16 Sets
`define CACHE_SET_COUNT 16

// CACHE_LINE_COUNT / CACHE_SET_COUNT = 64 / 16 = 4
`define CACHE_WAY 4
`define MEMORY_SIZE 524288 // Given : 2^9 Kb -> 2^19 Bytes

`define ADDR1_BUS_LEN 14
`define ADDR2_BUS_LEN 14

`define DATA1_BUS_LEN 16 // Given
`define DATA2_BUS_LEN 16 // Given

// 10 commands for CPU <-> CACHE -> 4 bits to encode all of them
`define CTR1_BUS_LEN 4
// 4 commands for CACHE <-> MEMCTR
`define CTR2_BUS_LEN 2

`define LRU_AGE_LEN 2

typedef enum logic [2:0] {
  IDLE,
  READ_MEMORY,
  READ_RESPONSE,
  WRITE_DATA,
  WRITE_RESPONSE
} state_memctr;

typedef enum logic [1:0] {
  C2_NOP,
  C2_READ,
  C2_WRITE,
  C2_RESPONSE
} c2_commands;

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

`endif