// everything the uvm bench needs, in one package, the usual way

package axis_pkg;

   import uvm_pkg::*;
`include "uvm_macros.svh"

   parameter int DATA_W  = 32;
   parameter int PKT_LEN = 4;
   parameter logic [DATA_W-1:0] SEED = 32'h0000_00A0;

   // how the slave is told to push back during a packet
   typedef enum {
      BP_NONE,   // never stall
      BP_LIGHT,  // stall about one cycle in seven
      BP_HEAVY,  // stall more than half the time
      BP_LAST    // stall exactly on the TLAST beat, the corner case
   } bp_e;

`include "axis_item.svh"
`include "axis_pkt.svh"
`include "axis_sequence.svh"

`include "axis_driver.svh"
`include "axis_monitor.svh"
`include "axis_agent.svh"

`include "axis_scoreboard.svh"
`include "axis_coverage.svh"

`include "axis_env.svh"
`include "axis_test.svh"

endpackage : axis_pkg
