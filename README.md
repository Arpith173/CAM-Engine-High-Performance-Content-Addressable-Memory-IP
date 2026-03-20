# CAM-Engine-High-Performance-Content-Addressable-Memory-IP
[![Verilog](https://img.shields.io/badge/HDL-Verilog-blue.svg)](https://en.wikipedia.org/wiki/Verilog)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Sim: Icarus](https://img.shields.io/badge/Sim-Icarus%20Verilog-orange.svg)](http://iverilog.icarus.com/)

A **fully parameterised, synthesisable Content Addressable Memory (CAM / TCAM)** IP core written in Verilog. Designed for high-throughput parallel lookups in networking, caching, and pattern-matching applications.

---

## ✨ Features

| Feature | Description |
|---|---|
| **Ternary Matching (TCAM)** | Per-bit don't-care masks for wildcard lookups |
| **Configurable Depth & Width** | Scale from 8×4 to 1024×128+ via parameters |
| **Priority Encoder** | Selectable LSB-first or MSB-first priority |
| **Multi-Match Detection** | `multi_match` flag + full `match_vector` output |
| **Match Counting** | Popcount of all matching entries per search |
| **Auto-Allocation** | First-free-slot finder for automatic address management |
| **Entry Invalidation** | Per-address delete and bulk flush |
| **Occupancy Tracking** | Live `occupancy` counter with `full` / `empty` flags |
| **LRU Age Counters** | Per-entry age tracking for replacement policies |
| **Pipeline Register** | Optional output pipeline stage for timing closure |
| **Debug Readback** | `ifdef`-gated data/mask readback port for verification |
| **Clean Modular Design** | 3-file hierarchy: cell → priority encoder → engine |

---

### Ternary Matching

Each CAM cell stores a **data** word and a **mask** word. Match logic:

```
mismatch = (stored_data XOR search_key) AND (NOT mask)
hit      = valid AND (mismatch == 0)
```

| mask bit | Behaviour            |
|----------|----------------------|
| `0`      | Bit must match exactly |
| `1`      | Bit is **don't care** (wildcard) |

---

## 🧮 Parameters

| Parameter | Default | Description |
|---|---|---|
| `DEPTH` | 16 | Number of CAM entries |
| `WIDTH` | 8 | Data word width (bits) |
| `ADDR_WIDTH` | 4 | Address width (≥ ⌈log₂(DEPTH)⌉) |
| `PRIORITY_DIR` | `"LSB"` | `"LSB"` = lowest index wins, `"MSB"` = highest |
| `PIPELINE` | 1 | `1` = register outputs, `0` = combinational |

---

## 🔌 Port Map

### Write Interface
| Port | Dir | Width | Description |
|---|---|---|---|
| `we` | in | 1 | Write enable |
| `auto_alloc` | in | 1 | Use first-free-slot instead of `waddr` |
| `waddr` | in | ADDR_WIDTH | Write address |
| `din` | in | WIDTH | Write data |
| `mask_in` | in | WIDTH | Ternary mask (1 = don't care) |
| `delete_en` | in | 1 | Invalidate entry at `waddr` |
| `flush` | in | 1 | Invalidate all entries |

### Search Interface
| Port | Dir | Width | Description |
|---|---|---|---|
| `search_en` | in | 1 | Search enable |
| `search_key` | in | WIDTH | Search key |
| `match` | out | 1 | At least one match found |
| `match_index` | out | ADDR_WIDTH | Highest-priority match address |
| `multi_match` | out | 1 | More than one entry matched |
| `match_vector` | out | DEPTH | Raw per-entry match bits |
| `match_count` | out | ADDR_WIDTH+1 | Number of matching entries |
| `search_valid` | out | 1 | Results valid this cycle |

### Status
| Port | Dir | Width | Description |
|---|---|---|---|
| `occupancy` | out | ADDR_WIDTH+1 | Number of valid entries |
| `full` | out | 1 | CAM is full |
| `empty` | out | 1 | CAM is empty |
| `next_free` | out | ADDR_WIDTH | First available slot |
| `alloc_valid` | out | 1 | `next_free` is valid |
| `age_vector` | out | DEPTH×ADDR_WIDTH | Packed LRU age counters |

---

## 🚀 Quick Start

### Simulate with Icarus Verilog

```bash
# Compile
iverilog -o cam_tb.vvp \
    rtl/cam_cell.v \
    rtl/priority_encoder.v \
    rtl/cam_engine.v \
    tb/cam_engine_tb.v

# Run
vvp cam_tb.vvp

# View waveforms (optional)
gtkwave cam_engine_tb.vcd &
```

### Simulate with Vivado

```tcl
# In Vivado Tcl console
read_verilog rtl/cam_cell.v
read_verilog rtl/priority_encoder.v
read_verilog rtl/cam_engine.v
read_verilog -sv tb/cam_engine_tb.v
launch_simulation
```

### Instantiation Template

```verilog
cam_engine #(
    .DEPTH       (64),
    .WIDTH       (32),
    .ADDR_WIDTH  (6),
    .PRIORITY_DIR("LSB"),
    .PIPELINE    (1)
) u_cam (
    .clk         (sys_clk),
    .rst_n       (sys_rst_n),
    .we          (cam_we),
    .auto_alloc  (1'b1),        // automatic slot allocation
    .waddr       (6'd0),
    .din         (cam_data),
    .mask_in     (cam_mask),
    .delete_en   (cam_del),
    .flush       (cam_flush),
    .search_en   (cam_search),
    .search_key  (cam_key),
    .match       (cam_hit),
    .match_index (cam_idx),
    .multi_match (cam_multi),
    .match_vector(),            // unused
    .match_count (cam_cnt),
    .search_valid(cam_valid),
    .occupancy   (cam_occ),
    .full        (cam_full),
    .empty       (cam_empty),
    .next_free   (),
    .alloc_valid (),
    .age_vector  ()
);
```

---

## 📊 Use Cases

| Application | Configuration |
|---|---|
| **MAC Address Table** | `WIDTH=48, DEPTH=1024` — Ethernet switch forwarding |
| **IPv4 ACL / Firewall** | `WIDTH=32, DEPTH=256` with ternary masks |
| **TLB (Translation Lookaside Buffer)** | `WIDTH=20, DEPTH=64` — virtual page lookup |
| **Cache Tag Store** | `WIDTH=TAG_BITS, DEPTH=WAYS` — set-associative cache |
| **Pattern Matching** | Variable width — intrusion detection, regex accelerator |
| **Database Index** | `WIDTH=KEY_BITS` — hash-free exact-match lookups |

---

## 🧪 Testbench Coverage

The testbench (`tb/cam_engine_tb.v`) runs **11 test groups**:

| # | Group | What's Tested |
|---|---|---|
| 1 | Reset | Empty/full flags, occupancy, allocator state |
| 2 | Write & Search | Single write, exact match, search_valid |
| 3 | Search Miss | No-match scenario |
| 4 | Multi-Match | Duplicate entries, priority encoding, match_count |
| 5 | Ternary Match | Wildcard masks, partial matching |
| 6 | Deletion | Single entry invalidation, post-delete search |
| 7 | Flush | Bulk invalidation |
| 8 | Auto-Alloc | Automatic slot allocation sequence |
| 9 | Full Flag | Fill to capacity, full/alloc_valid |
| 10 | Overwrite | Re-writing existing entry |
| 11 | Age Counters | LRU counter increment verification |

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).

---

## 🤝 Contributing

Contributions are welcome! Feel free to open issues or submit PRs for:
- Synthesis optimisations (e.g., parallel prefix priority encoder)
- AXI-Lite / Wishbone wrapper
- Additional testbench scenarios
- FPGA resource utilisation reports

---

<p align="center">
  <b>Built for speed. Designed for flexibility. Ready for silicon.</b>
</p>
