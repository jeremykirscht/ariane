// Copyright 2021 Thales DIS Design Services SAS
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://solderpad.org/licenses/
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.0


`ifndef __UVMT_CVA6_TB_SV__
`define __UVMT_CVA6_TB_SV__


/**
 * Module encapsulating the CVA6 DUT wrapper, and associated SV interfaces.
 * Also provide UVM environment entry and exit points.
 */
`default_nettype none
module uvmt_cva6_tb;

   import uvm_pkg::*;
   import uvmt_cva6_pkg::*;
   import uvme_cva6_pkg::*;

   localparam AXI_USER_WIDTH    = ariane_pkg::AXI_USER_WIDTH;
   localparam AXI_USER_EN       = ariane_pkg::AXI_USER_EN;
   localparam AXI_ADDRESS_WIDTH = 64;
   localparam AXI_DATA_WIDTH    = 64;
   localparam NUM_WORDS         = 2**24;

   // ENV (testbench) parameters
   parameter int ENV_PARAM_INSTR_ADDR_WIDTH  = 32;
   parameter int ENV_PARAM_INSTR_DATA_WIDTH  = 32;
   parameter int ENV_PARAM_RAM_ADDR_WIDTH    = 22;

   // Agent interfaces
   uvma_clknrst_if              clknrst_if(); // clock and resets from the clknrst agent
   uvma_cvxif_intf              cvxif_if(
                                         .clk(clknrst_if.clk),
                                         .reset_n(clknrst_if.reset_n)
                                        ); // cvxif from the cvxif agent
   uvma_axi_intf                axi_if(
                                         .clk(clknrst_if.clk),
                                         .rst_n(clknrst_if.reset_n)
                                      );
   uvme_cva6_core_cntrl_if      core_cntrl_if();

   //bind assertion module for cvxif interface
   bind uvmt_cva6_dut_wrap
      uvma_cvxif_assert          cvxif_assert(.cvxif_assert(cvxif_if),
                                              .clk(clknrst_if.clk),
                                              .reset_n(clknrst_if.reset_n)
                                             );
   //bind assertion module for axi interface
   bind uvmt_cva6_dut_wrap
      uvmt_axi_assert            axi_assert(.axi_assert(axi_if.passive),
                                            .clk(clknrst_if.clk),
                                            .rst_n(clknrst_if.reset_n)
                                           );
   // DUT Wrapper Interfaces
   uvmt_rvfi_if                     rvfi_if(
                                                 .rvfi_o(),
                                                 .tb_exit_o()
                                                 ); // Status information generated by the Virtual Peripherals in the DUT WRAPPER memory.

  /**
   * DUT WRAPPER instance
   */

   uvmt_cva6_dut_wrap #(
     .AXI_USER_WIDTH    (AXI_USER_WIDTH),
     .AXI_USER_EN       (AXI_USER_EN),
     .AXI_ADDRESS_WIDTH (AXI_ADDRESS_WIDTH),
     .AXI_DATA_WIDTH    (AXI_DATA_WIDTH),
     .NUM_WORDS         (NUM_WORDS)
   ) cva6_dut_wrap (
                    .clknrst_if(clknrst_if),
                    .cvxif_if  (cvxif_if),
                    .axi_if    (axi_if),
                    .core_cntrl_if(core_cntrl_if),
                    .tb_exit_o(rvfi_if.tb_exit_o),
                    .rvfi_o(rvfi_if.rvfi_o)
                    );


   /**
    * Test bench entry point.
    */
   initial begin : test_bench_entry_point

     // Specify time format for simulation (units_number, precision_number, suffix_string, minimum_field_width)
     $timeformat(-9, 3, " ns", 8);

     // Add interfaces handles to uvm_config_db
     uvm_config_db#(virtual uvma_clknrst_if )::set(.cntxt(null), .inst_name("*.env.clknrst_agent"), .field_name("vif"),       .value(clknrst_if));
     uvm_config_db#(virtual uvma_cvxif_intf )::set(.cntxt(null), .inst_name("*.env.cvxif_agent"),   .field_name("vif"),       .value(cvxif_if)  );
     uvm_config_db#(virtual uvma_axi_intf   )::set(.cntxt(null), .inst_name("*"),                   .field_name("axi_vif"),    .value(axi_if));
     uvm_config_db#(virtual uvmt_rvfi_if    )::set(.cntxt(null), .inst_name("*"),                   .field_name("rvfi_vif"),  .value(rvfi_if));
     uvm_config_db#(virtual uvme_cva6_core_cntrl_if)::set(.cntxt(null), .inst_name("*"), .field_name("core_cntrl_vif"),  .value(core_cntrl_if));

     // DUT and ENV parameters
     uvm_config_db#(int)::set(.cntxt(null), .inst_name("*"), .field_name("ENV_PARAM_INSTR_ADDR_WIDTH"),  .value(ENV_PARAM_INSTR_ADDR_WIDTH) );
     uvm_config_db#(int)::set(.cntxt(null), .inst_name("*"), .field_name("ENV_PARAM_INSTR_DATA_WIDTH"),  .value(ENV_PARAM_INSTR_DATA_WIDTH) );
     uvm_config_db#(int)::set(.cntxt(null), .inst_name("*"), .field_name("ENV_PARAM_RAM_ADDR_WIDTH"),    .value(ENV_PARAM_RAM_ADDR_WIDTH)   );

     // Run test
     uvm_top.enable_print_topology = 0; // ENV coders enable this as a debug aid
     uvm_top.finish_on_completion  = 1;
     uvm_top.run_test();
   end : test_bench_entry_point

   assign core_cntrl_if.clk = clknrst_if.clk;

   /**
    * End-of-test summary printout.
    */
   final begin: end_of_test
      string             summary_string;
      uvm_report_server  rs;
      int                err_count;
      int                warning_count;
      int                fatal_count;
      static bit         sim_finished = 0;

      static string  red   = "\033[31m\033[1m";
      static string  green = "\033[32m\033[1m";
      static string  reset = "\033[0m";

      rs            = uvm_top.get_report_server();
      err_count     = rs.get_severity_count(UVM_ERROR);
      warning_count = rs.get_severity_count(UVM_WARNING);
      fatal_count   = rs.get_severity_count(UVM_FATAL);

      void'(uvm_config_db#(bit)::get(null, "", "sim_finished", sim_finished));
      $display("### Got sim_finished:  %4d", sim_finished);
      $display("###     warning_count: %4d", warning_count);
      $display("###     err_count:     %4d", err_count);
      $display("###     fatal_count:   %4d", fatal_count);

      $display("\n%m: *** Test Summary ***\n");

      if (sim_finished && (err_count == 0) && (fatal_count == 0)) begin
         $display("    PPPPPPP    AAAAAA    SSSSSS    SSSSSS   EEEEEEEE  DDDDDDD     ");
         $display("    PP    PP  AA    AA  SS    SS  SS    SS  EE        DD    DD    ");
         $display("    PP    PP  AA    AA  SS        SS        EE        DD    DD    ");
         $display("    PPPPPPP   AAAAAAAA   SSSSSS    SSSSSS   EEEEE     DD    DD    ");
         $display("    PP        AA    AA        SS        SS  EE        DD    DD    ");
         $display("    PP        AA    AA  SS    SS  SS    SS  EE        DD    DD    ");
         $display("    PP        AA    AA   SSSSSS    SSSSSS   EEEEEEEE  DDDDDDD     ");
         $display("    ----------------------------------------------------------");
         if (warning_count == 0) begin
           $display("                        SIMULATION PASSED                     ");
         end
         else begin
           $display("                 SIMULATION PASSED with WARNINGS              ");
         end
         $display("    ----------------------------------------------------------");
      end
      else begin
         $display("    FFFFFFFF   AAAAAA   IIIIII  LL        EEEEEEEE  DDDDDDD       ");
         $display("    FF        AA    AA    II    LL        EE        DD    DD      ");
         $display("    FF        AA    AA    II    LL        EE        DD    DD      ");
         $display("    FFFFF     AAAAAAAA    II    LL        EEEEE     DD    DD      ");
         $display("    FF        AA    AA    II    LL        EE        DD    DD      ");
         $display("    FF        AA    AA    II    LL        EE        DD    DD      ");
         $display("    FF        AA    AA  IIIIII  LLLLLLLL  EEEEEEEE  DDDDDDD       ");
         $display("    ----------------------------------------------------------");
         if (sim_finished == 0) begin
            $display("                   SIMULATION FAILED - ABORTED              ");
         end
         else begin
            $display("                       SIMULATION FAILED                    ");
         end
         $display("    ----------------------------------------------------------");
      end
   end

endmodule : uvmt_cva6_tb
`default_nettype wire

`endif // __UVMT_CVA6_TB_SV__
