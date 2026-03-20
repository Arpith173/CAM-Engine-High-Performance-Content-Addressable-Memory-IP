// ============================================================================
// Module      : cam
// Description : Content Addressable Memory (CAM)
//               Searches memory by content and returns the matching address.
//               Supports write, search, delete, and reset operations.
//
// Features:
//   - Parameterised depth, width, and address size
//   - Valid-bit tracking per entry
//   - Priority-based match (lowest index wins)
//   - Entry deletion
//   - Full / empty status flags
// ============================================================================

module cam #(
    parameter DEPTH      = 16,
    parameter WIDTH      = 8,
    parameter ADDR_WIDTH = 4
)(
    input  wire                  clk,
    input  wire                  rst,          // Synchronous reset (active high)

    // Write interface
    input  wire                  we,           // Write enable
    input  wire [ADDR_WIDTH-1:0] waddr,        // Write address
    input  wire [WIDTH-1:0]      din,          // Data to write

    // Delete interface
    input  wire                  delete_en,    // Invalidate entry at waddr

    // Search interface
    input  wire                  search_en,    // Search enable
    input  wire [WIDTH-1:0]      search_key,   // Key to search for

    // Outputs
    output reg                   match,        // 1 if a match was found
    output reg  [ADDR_WIDTH-1:0] match_index,  // Address of first match
    output reg                   busy,         // Search result is valid

    // Status
    output wire                  full,         // All entries are occupied
    output wire                  empty         // No entries are occupied
);

    // -------------------------------------------------------------------------
    // Memory array and valid bits
    // -------------------------------------------------------------------------
    reg [WIDTH-1:0] mem   [0:DEPTH-1];
    reg             valid [0:DEPTH-1];

    // -------------------------------------------------------------------------
    // Occupancy tracking
    // -------------------------------------------------------------------------
    reg [ADDR_WIDTH:0] entry_count;

    assign full  = (entry_count == DEPTH);
    assign empty = (entry_count == 0);

    // -------------------------------------------------------------------------
    // Occupancy counter update
    // -------------------------------------------------------------------------
    integer c;
    always @(posedge clk) begin
        if (rst) begin
            entry_count <= 0;
        end else begin
            // Recount every cycle from valid bits (simple and safe)
            entry_count <= 0;
            for (c = 0; c < DEPTH; c = c + 1)
                entry_count <= entry_count + valid[c];
        end
    end

    // -------------------------------------------------------------------------
    // Write, delete, and reset logic
    // -------------------------------------------------------------------------
    integer j;
    always @(posedge clk) begin
        if (rst) begin
            for (j = 0; j < DEPTH; j = j + 1) begin
                mem[j]   <= {WIDTH{1'b0}};
                valid[j] <= 1'b0;
            end
        end else if (delete_en) begin
            valid[waddr] <= 1'b0;
        end else if (we) begin
            mem[waddr]   <= din;
            valid[waddr] <= 1'b1;
        end
    end

    // -------------------------------------------------------------------------
    // Search logic — priority goes to lowest matching index
    // -------------------------------------------------------------------------
    integer i;
    reg found;  // temp variable used inside the always block

    always @(posedge clk) begin
        if (rst) begin
            match       <= 1'b0;
            match_index <= {ADDR_WIDTH{1'b0}};
            busy        <= 1'b0;
        end else if (search_en) begin
            found = 1'b0;
            for (i = 0; i < DEPTH; i = i + 1) begin
                if (!found && valid[i] && mem[i] == search_key) begin
                    match       <= 1'b1;
                    match_index <= i[ADDR_WIDTH-1:0];
                    found = 1'b1;
                end
            end
            if (!found) begin
                match       <= 1'b0;
                match_index <= {ADDR_WIDTH{1'b0}};
            end
            busy <= 1'b1;
        end else begin
            busy <= 1'b0;
        end
    end

endmodule
