// MEMORY_SIZE yields ADDRESS_LEN 
//as we need to encode all of the bytes 
`define ADDRESS_LEN 19
`define TAG_LEN 10 // ADDRES_LEN - INDEX_LEN - OFFSET_LEN
`define INDEX_LEN 4 // Given
`define OFFSET_LEN 5 // Given
`define CACHE_SIZE 2048 // Given 
// OFFSET_LEN yields CACHE_LINE_SIZE
`define CACHE_LINE_SIZE 32
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
