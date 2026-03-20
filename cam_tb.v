// ============================================================================
// Testbench : cam_tb
// Description : Tests for the CAM module
//               Covers: reset, write, search hit, search miss, delete,
//                       full/empty flags, priority, overwrite
// ============================================================================

`timescale 1ns / 1ps

module cam_tb;

    // Parameters
    localparam DEPTH      = 8;
    localparam WIDTH      = 8;
    localparam ADDR_WIDTH = 3;
    localparam CLK_PERIOD = 10;

    // DUT signals
    reg                   clk;
    reg                   rst;
    reg                   we;
    reg  [ADDR_WIDTH-1:0] waddr;
    reg  [WIDTH-1:0]      din;
    reg                   delete_en;
    reg                   search_en;
    reg  [WIDTH-1:0]      search_key;

    wire                  match;
    wire [ADDR_WIDTH-1:0] match_index;
    wire                  busy;
    wire                  full;
    wire                  empty;

    // Instantiate DUT
    cam #(
        .DEPTH     (DEPTH),
        .WIDTH     (WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .clk        (clk),
        .rst        (rst),
        .we         (we),
        .waddr      (waddr),
        .din        (din),
        .delete_en  (delete_en),
        .search_en  (search_en),
        .search_key (search_key),
        .match      (match),
        .match_index(match_index),
        .busy       (busy),
        .full       (full),
        .empty      (empty)
    );

    // Clock generation
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Test counters
    integer pass_cnt = 0;
    integer fail_cnt = 0;

    task check(input [199:0] name, input condition);
        begin
            if (condition) begin
                $display("[PASS] %0s", name);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("[FAIL] %0s", name);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    // Main test
    initial begin
        $dumpfile("cam_tb.vcd");
        $dumpvars(0, cam_tb);

        // Initialise inputs
        rst        = 0;
        we         = 0;
        waddr      = 0;
        din        = 0;
        delete_en  = 0;
        search_en  = 0;
        search_key = 0;

        $display("");
        $display("========================================");
        $display("  CAM Testbench  (DEPTH=%0d, WIDTH=%0d)", DEPTH, WIDTH);
        $display("========================================");
        $display("");

        // ----- Reset -----
        $display("--- Reset ---");
        rst = 1;
        @(posedge clk); @(posedge clk);
        rst = 0;
        @(posedge clk);
        check("Empty after reset", empty == 1);
        check("Not full after reset", full == 0);

        // ----- Write some entries -----
        $display("--- Write entries ---");

        // Write 0xAA to address 0
        @(posedge clk); we = 1; waddr = 0; din = 8'hAA; @(posedge clk); we = 0;
        // Write 0xBB to address 1
        @(posedge clk); we = 1; waddr = 1; din = 8'hBB; @(posedge clk); we = 0;
        // Write 0xCC to address 2
        @(posedge clk); we = 1; waddr = 2; din = 8'hCC; @(posedge clk); we = 0;
        // Write 0xAA to address 4 (duplicate value)
        @(posedge clk); we = 1; waddr = 4; din = 8'hAA; @(posedge clk); we = 0;

        @(posedge clk);
        check("Not empty after writes", empty == 0);

        // ----- Search hit -----
        $display("--- Search hit ---");
        @(posedge clk); search_en = 1; search_key = 8'hBB; @(posedge clk); search_en = 0;
        @(posedge clk);
        check("Match found for 0xBB", match == 1);
        check("Match index = 1", match_index == 1);

        // ----- Search miss -----
        $display("--- Search miss ---");
        @(posedge clk); search_en = 1; search_key = 8'hFF; @(posedge clk); search_en = 0;
        @(posedge clk);
        check("No match for 0xFF", match == 0);

        // ----- Priority (lowest index wins) -----
        $display("--- Priority ---");
        @(posedge clk); search_en = 1; search_key = 8'hAA; @(posedge clk); search_en = 0;
        @(posedge clk);
        check("Match found for 0xAA", match == 1);
        check("Lowest index wins (index=0)", match_index == 0);

        // ----- Delete -----
        $display("--- Delete ---");
        // Delete entry 0 (which held 0xAA)
        @(posedge clk); delete_en = 1; waddr = 0; @(posedge clk); delete_en = 0;
        @(posedge clk);

        // Search 0xAA again — should now find index 4
        @(posedge clk); search_en = 1; search_key = 8'hAA; @(posedge clk); search_en = 0;
        @(posedge clk);
        check("Match still found after delete", match == 1);
        check("Falls to index 4 after delete", match_index == 4);

        // ----- Overwrite -----
        $display("--- Overwrite ---");
        // Overwrite address 1 with new value 0xDD
        @(posedge clk); we = 1; waddr = 1; din = 8'hDD; @(posedge clk); we = 0;
        @(posedge clk);

        // Old value should be gone
        @(posedge clk); search_en = 1; search_key = 8'hBB; @(posedge clk); search_en = 0;
        @(posedge clk);
        check("Old value 0xBB not found", match == 0);

        // New value should be there
        @(posedge clk); search_en = 1; search_key = 8'hDD; @(posedge clk); search_en = 0;
        @(posedge clk);
        check("New value 0xDD found", match == 1);
        check("Overwrite index = 1", match_index == 1);

        // ----- Fill to capacity -----
        $display("--- Full flag ---");
        rst = 1; @(posedge clk); @(posedge clk); rst = 0; @(posedge clk);

        begin : fill
            integer fi;
            for (fi = 0; fi < DEPTH; fi = fi + 1) begin
                @(posedge clk);
                we = 1; waddr = fi[ADDR_WIDTH-1:0]; din = fi[WIDTH-1:0];
                @(posedge clk);
                we = 0;
            end
        end
        @(posedge clk); @(posedge clk);
        check("Full flag set", full == 1);

        // ----- Summary -----
        $display("");
        $display("========================================");
        $display("  %0d PASSED / %0d FAILED / %0d TOTAL",
                 pass_cnt, fail_cnt, pass_cnt + fail_cnt);
        $display("========================================");
        if (fail_cnt == 0) $display("*** ALL TESTS PASSED ***");
        else               $display("*** SOME TESTS FAILED ***");
        $display("");

        $finish;
    end

    // Timeout
    initial begin
        #50000;
        $display("[TIMEOUT]");
        $finish;
    end

endmodule
