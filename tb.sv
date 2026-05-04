module tb;
    initial begin
        $display("| replacement | hitrate | hits | accesses |");
        $display("| :---------- | --------: | ---------: | ----------: |");
        $display("| LRU |      nan%% | %10d | %10d |", 0, 0);
        $display("| bpLRU |      nan%% | %10d | %10d |", 0, 0);
        $finish;
    end
endmodule