# Content Addressable Memory (CAM) — Verilog

A parameterised **Content Addressable Memory** implemented in Verilog. Unlike normal RAM where you look up data by address, a CAM lets you search by *value* and returns the *address* where it's stored.

## What is a CAM?

A CAM is a special type of memory used in:
- **Network switches** — MAC address lookup tables
- **Routers** — routing table matching
- **CPU caches** — TLB (Translation Lookaside Buffer)
- **Databases** — fast key-based lookups

**Normal RAM:** Address → Data  
**CAM:** Data → Address

## Features

- Fully parameterised (depth, width, address size)
- Valid-bit tracking per entry
- Priority-based match (lowest index wins on duplicates)
- Entry deletion / invalidation
- Synchronous reset
- Full and empty status flags
- Comprehensive testbench

## Port Map

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | Input | 1 | Clock |
| `rst` | Input | 1 | Synchronous reset (active high) |
| `we` | Input | 1 | Write enable |
| `waddr` | Input | ADDR_WIDTH | Write address |
| `din` | Input | WIDTH | Data to write |
| `delete_en` | Input | 1 | Delete entry at `waddr` |
| `search_en` | Input | 1 | Start search |
| `search_key` | Input | WIDTH | Value to search for |
| `match` | Output | 1 | 1 if match found |
| `match_index` | Output | ADDR_WIDTH | Address of match |
| `busy` | Output | 1 | Search result ready |
| `full` | Output | 1 | All entries occupied |
| `empty` | Output | 1 | No entries occupied |

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DEPTH` | 16 | Number of memory entries |
| `WIDTH` | 8 | Data word width (bits) |
| `ADDR_WIDTH` | 4 | Address width (should be ≥ log₂(DEPTH)) |

## Simulation

### Icarus Verilog
```bash
iverilog -o cam_tb.vvp rtl/cam.v tb/cam_tb.v
vvp cam_tb.vvp
gtkwave cam_tb.vcd    # optional — view waveforms
```

### Xilinx Vivado
```tcl
read_verilog rtl/cam.v
read_verilog tb/cam_tb.v
launch_simulation
```

## Testbench

The testbench covers:

| Test | What it checks |
|------|----------------|
| Reset | Empty/full flags cleared after reset |
| Write | Entries stored correctly |
| Search hit | Correct value found at correct index |
| Search miss | No false positives |
| Priority | Lowest index returned when duplicates exist |
| Delete | Entry removed, next copy found |
| Overwrite | Old value replaced, new value searchable |
| Full flag | Asserted when all slots used |

## License

MIT License — see [LICENSE](LICENSE) for details.
