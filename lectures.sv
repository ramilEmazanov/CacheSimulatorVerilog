// Здесь все чисто на модулях. Модуль состоит из модулей

module lecture1(
  input wire clk1,
  output wire clk2 
);

assign clk1 = clk2;

endmodule

module adder(
  input a,
  input b,
  input carry_in,
  output sum,
  output carry_out
);

assign sum = (a ^ b) ^ carry_in;
assign carry_out = (a & b) | ((a ^ b) & carry_in);

endmodule

module adder8(
  input [7:0]a,
  input [7:0]b,
  output [7:0]sum
);


adder adder_0(.a(a[0]), .b(b[0]), .carry_in(1'b0), .sum(sum[0]), .carry_out(c0));
adder adder_1(.a(a[1]), .b(b[1]), .carry_in(c0),   .sum(sum[1]), .carry_out(c1));
adder adder_2(.a(a[2]), .b(b[2]), .carry_in(c1),   .sum(sum[2]), .carry_out(c2));
adder adder_3(.a(a[3]), .b(b[3]), .carry_in(c2),   .sum(sum[3]), .carry_out(c3));
adder adder_4(.a(a[4]), .b(b[4]), .carry_in(c3),   .sum(sum[4]), .carry_out(c4));
adder adder_5(.a(a[5]), .b(b[5]), .carry_in(c4),   .sum(sum[5]), .carry_out(c5));
adder adder_6(.a(a[6]), .b(b[6]), .carry_in(c5),   .sum(sum[6]), .carry_out(c6));
adder adder_7(.a(a[7]), .b(b[7]), .carry_in(c6),   .sum(sum[7]), .carry_out(carry_out));

endmodule

module top();

reg [7:0]a;
reg [7:0]b;
wire [7:0]s;

adder8 adder8_inst(.a(a), .b(b), .sum(s));

// запускается 1 раз в начале симуляции
initial begin 
  a = 35; b = 62; #1 $display("a = %d, b = %d, sum = %d", a, b, s);
  a = 19; b = 14; #1 $display("a = %d, b = %d, sum = %d", a, b, s);
end

endmodule

// D-триггер (d предыдущее состояние, q новое, меняется когда clk включен)
reg q;
always @(posedge clk) begin
  q <= d; // Неблокирующее присваивание 
end


// Сохранение предыдущего состояние. Цепочка из двух D-триггеров
reg a;
reg b;

always @(posedge clk) begin
  a <= d;
  b <= a;
end 

// Д-триггер со сбросом состояния
reg q;

// Поменяется когда reset уйдет в 1
always @(posedge clk, posedge reset) begin
  if(reset)
    q <= 0
  else
    q <= d
end

// Поменяется когда reset уйдет в 0
always @(posedge clk, negedge reset) begin
  if(!reset)
    q <= 0
  else
    q <= d
end

// Непрерывное присваивание
wire [3:0]a;
wire [3:0]b = 4'b10;

assign a = b + 4'b1;


// Счетчик
module counter(
  input clk
);

reg [3:0]cnt = 0;

always @(posedge clk) begin
  if(cnt == 9)
    cnt <= 0;
  else
    cnt = cnt + 1;
end

endmodule

// Счетчик c выходом counter
module counter(
  input clk,
  output clk2
);

assign clk2 = (cnt == 9);

reg [3:0]cnt = 0;

always @(posedge clk) begin
  if(clk2)
    cnt <= 0;
  else
    cnt <= cnt + 1;
end

endmodule