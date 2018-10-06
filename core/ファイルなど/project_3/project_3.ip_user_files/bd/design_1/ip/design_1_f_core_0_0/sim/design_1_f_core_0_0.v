// (c) Copyright 1995-2018 Xilinx, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// 
// DO NOT MODIFY THIS FILE.


// IP VLNV: xilinx.com:module_ref:f_core:1.0
// IP Revision: 1

`timescale 1ns/1ps

(* DowngradeIPIdentifiedWarnings = "yes" *)
module design_1_f_core_0_0 (
  clk,
  rst,
  memaddr_a,
  w_data_a,
  wenable_a,
  wenable_b,
  r_data_a,
  en_ab,
  memaddr_b,
  w_data_b,
  r_data_b,
  iaddr,
  instout,
  en_inst,
  corereadwhere,
  corereadok,
  coreread,
  indoutb,
  corewritewhere,
  corewriteok,
  corewrite,
  outdina,
  outwe
);

(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk, ASSOCIATED_RESET rst, FREQ_HZ 100000000, PHASE 0.000, CLK_DOMAIN design_1_f_core_all_0_0_clk" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *)
input wire clk;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME rst, POLARITY ACTIVE_LOW" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst RST" *)
input wire rst;
output wire [31 : 0] memaddr_a;
output wire [31 : 0] w_data_a;
output wire [3 : 0] wenable_a;
output wire [3 : 0] wenable_b;
input wire [31 : 0] r_data_a;
output wire en_ab;
output wire [31 : 0] memaddr_b;
output wire [31 : 0] w_data_b;
input wire [31 : 0] r_data_b;
output wire [31 : 0] iaddr;
input wire [31 : 0] instout;
output wire en_inst;
input wire [1 : 0] corereadwhere;
input wire corereadok;
output wire coreread;
input wire [31 : 0] indoutb;
input wire [1 : 0] corewritewhere;
input wire corewriteok;
output wire corewrite;
output wire [31 : 0] outdina;
output wire [3 : 0] outwe;

  f_core #(
    .ILENGTH(32),
    .INUM(1024),
    .IADDLEN(8),
    .CLK_PER_HALF_BIT(400)
  ) inst (
    .clk(clk),
    .rst(rst),
    .memaddr_a(memaddr_a),
    .w_data_a(w_data_a),
    .wenable_a(wenable_a),
    .wenable_b(wenable_b),
    .r_data_a(r_data_a),
    .en_ab(en_ab),
    .memaddr_b(memaddr_b),
    .w_data_b(w_data_b),
    .r_data_b(r_data_b),
    .iaddr(iaddr),
    .instout(instout),
    .en_inst(en_inst),
    .corereadwhere(corereadwhere),
    .corereadok(corereadok),
    .coreread(coreread),
    .indoutb(indoutb),
    .corewritewhere(corewritewhere),
    .corewriteok(corewriteok),
    .corewrite(corewrite),
    .outdina(outdina),
    .outwe(outwe)
  );
endmodule
