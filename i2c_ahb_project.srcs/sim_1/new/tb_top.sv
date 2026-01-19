`timescale 1ns / 1ps

`include "uvm_macros.svh"
import uvm_pkg::*; 

////////////////////////////////////////////////////////////////////

interface ahb_if (input logic HCLK);
  logic        HSEL;
  logic [31:0] HADDR;
  logic        HWRITE;
  logic [1:0]  HTRANS;
  logic [31:0] HWDATA;
  logic [31:0] HRDATA;
  logic        HREADY;
  logic HRESETn; 
endinterface

interface i2c_if;
  logic scl;
  wire  sda;
endinterface

////////////////////////////////////////////////////////////////////////////////

class ahb_txn extends uvm_sequence_item;
 `uvm_object_utils(ahb_txn)
 
  rand bit [31:0] HADDR;
  rand bit [31:0] HWDATA;
  bit HWRITE;
  bit [1:0] HTRANS;
  bit HSEL;
  bit [31:0] HRDATA;
  logic sda,scl;
  bit HRESETn;
  
  static int cnt = 0;   
  
  bit [31:0] addr,rdata,wdata; 
  bit write;
  
  function new(string path ="ahb_txn");
    super.new(path);
  endfunction
  
  constraint HADDR_1 {HADDR[31:16] == 16'h0000;}

  constraint HWDATA_CTRL_1bit {if (HADDR[3:0] == 4'b0000) HWDATA[1] == 1'b1;
  }
  
  constraint HADDR_2 {
    if (cnt == 0) HADDR[15:0] == 16'h0000;
    else if (cnt == 1) HADDR[15:0]== 16'h0008;
    else if (cnt == 2) HADDR[15:0] == 16'h000C;
    else               HADDR[15:0] == 16'h0010;
  }

  function void post_randomize();
    cnt = (cnt + 1) % 4;   // move to next value
  endfunction
endclass

class read_seq extends uvm_sequence #(ahb_txn);
  `uvm_object_utils(read_seq)
  
  ahb_txn tr; 
  
  function new(string path = "read_seq");
    super.new(path);
  endfunction
  
  virtual task body(); 
    repeat(5) begin 
    tr = ahb_txn::type_id::create("tr");
    start_item(tr); 
    assert(tr.randomize())
    tr.HRESETn = 1'b1;
    tr.HWRITE = 1'b0;
    `uvm_info("SEQ",$sformatf(" HADDR : %0h  HWDATA : %0h HWRITE :%0h",tr.HADDR,tr.HWDATA,tr.HWRITE),	 UVM_NONE);
    finish_item(tr); 
  end 
  endtask 
endclass


class reset_dut extends uvm_sequence #(ahb_txn);
    `uvm_object_utils(reset_dut)
   
     ahb_txn tr; 
    
    function new(string path = "reset_dut");
        super.new(path);
    endfunction 
    
  virtual task body();
    begin 
    ahb_txn tr = ahb_txn::type_id::create("tr");
    start_item(tr);
    tr.HRESETn = 0;   
    `uvm_info("SEQ"," RESET DONE ",UVM_NONE);           
    finish_item(tr); 
  end 
  endtask 
endclass 


class write_seq extends uvm_sequence #(ahb_txn);
  `uvm_object_utils(write_seq)
  
  ahb_txn tr; 
  
  function new(string path = "write_seq");
    super.new(path);
  endfunction
  
  virtual task body(); 
    repeat(5) begin 
    ahb_txn tr = ahb_txn::type_id::create("tr");
      start_item(tr);
      assert(tr.randomize());
      tr.HRESETn = 1'b1; 
      tr.HWRITE  = 1;            // <-- important
    `uvm_info("SEQ",$sformatf(" HADDR : %0h  HWDATA : %0h HWRITE :%0h",tr.HADDR,tr.HWDATA,tr.HWRITE),	 UVM_NONE);
    finish_item(tr); 
  end 
  endtask 
endclass

//////////////////////////////////////////////////////////////////////////////////////////////////

class ahb_drv extends uvm_driver #(ahb_txn);
  `uvm_component_utils(ahb_drv)
  
  ahb_txn tr;
  virtual ahb_if vif;
  
  
  function new (string path = "ahb_drv", uvm_component parent = null);
    super.new(path,parent); 
  endfunction 

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tr = ahb_txn::type_id::create("tr");
    if(!uvm_config_db#(virtual ahb_if)::get(this,"","vif",vif))`uvm_error("DRV","Unable to access AHB IF");
    
  endfunction
    
    task reset_d();
    begin
        vif.HRESETn <= 0;
        vif.HSEL    <= 0;
        vif.HTRANS  <= 0;
        vif.HWRITE  <= 0;
        vif.HADDR   <= 0;
        vif.HWDATA  <= 0;
        @(posedge vif.HCLK);
        vif.HRESETn <= 1;
        
      `uvm_info("DRV"," RESET DONE ",UVM_NONE);
    end 
    endtask
      
    task write_d();
    begin
   	  @(posedge vif.HCLK);
      vif.HSEL   <= 1'b1;
      vif.HTRANS <= 2'b10;
      vif.HWRITE <= 1'b1;
      vif.HADDR  <= tr.HADDR;
      vif.HWDATA <= tr.HWDATA;
      `uvm_info("DRV",$sformatf(" HADDR : %0h  HWDATA : %0h HWRITE :%0h",tr.HADDR,tr.HWDATA,tr.HWRITE),	 UVM_NONE);
    end 
    endtask
    
      task read_d();
        begin 
   	  @(posedge vif.HCLK);
      vif.HSEL   <= 1'b1;
      vif.HTRANS <= 2'b10;
      vif.HWRITE <= 1'b0;
      vif.HADDR  <= tr.HADDR;
      vif.HWDATA <= tr.HWDATA;
      `uvm_info("DRV",$sformatf(" HADDR : %0h  HWDATA : %0h HWRITE :%0h",tr.HADDR,tr.HWDATA,tr.HWRITE),	 UVM_NONE);
        end
      endtask 
    
  virtual task run_phase(uvm_phase phase);
    forever begin
     seq_item_port.get_next_item(tr);
      if (tr.HRESETn == 0)
        reset_d();
      else if (tr.HWRITE)
        write_d();
      else
        read_d();
      seq_item_port.item_done();
    end
  endtask
endclass

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


class ahb_mon extends uvm_monitor;
  `uvm_component_utils(ahb_mon)
  
  ahb_txn tr;
  virtual ahb_if vif;
  uvm_analysis_port#(ahb_txn) ap_ahb;
  	
  
  function new (string path = "ahb_mon", uvm_component parent = null);
    super.new(path,parent); 
  endfunction 

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_ahb = new("ap_ahb", this);
    if (!uvm_config_db#(virtual ahb_if)::get(this,"","vif",vif))
      `uvm_error("AHB_MON","Unable to access AHB IF");
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      tr = ahb_txn::type_id::create("tr");
      @(posedge vif.HCLK);begin 
      tr.HADDR = vif.HADDR;
      tr.HWDATA = vif.HWDATA;        
      tr.HWRITE = vif.HWRITE;
      tr.HRDATA = vif.HRDATA;
      ap_ahb.write(tr);
       `uvm_info("AHB_MON",$sformatf(" HADDR : %0h  HWDATA : %0h HWRITE :%0h",tr.HADDR,tr.HWDATA,tr.HWRITE),	 UVM_NONE);
      end   
    end
  endtask
endclass
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

class i2c_mon extends uvm_component;

  virtual i2c_if aif;
  bit [6:0] slave_addr = 7'h50;
  bit [7:0] mem = 8'hA5;
  bit sda_out, sda_oe;

  `uvm_component_utils(i2c_mon)
   uvm_analysis_port#(ahb_txn) ap_i2c;
  
  function new(input string path = "i2c_mon", uvm_component parent = null);
    super.new(path,parent);
  endfunction 

  function void build_phase(uvm_phase phase);
  super.build_phase(phase);
   ap_i2c = new("ap_i2c", this);
    if (!uvm_config_db#(virtual i2c_if)::get(this,"","aif",aif))
      `uvm_fatal("NO VIF","I2C IF not found")
  endfunction

  task run_phase(uvm_phase phase);
    bit [7:0] rx;
    forever begin
      @(negedge aif.sda iff aif.scl);
      recv(rx);
      if (rx[7:1] == slave_addr)begin 
      if (rx[0]==0)begin 
      recv(rx); 
      mem=rx;
      end
      else begin 
      send(mem); 
      recv(rx); 
      end
    end
    end 
  endtask

  task recv(output bit [7:0] d);
    for (int i=7;i>=0;i--) 
    begin @(posedge aif.scl); 
    d[i]=aif.sda; 
    end
  endtask

  task send(input bit [7:0] d);
    for (int i=7;i>=0;i--) 
    begin 
        @(negedge aif.scl); 
        sda_out=d[i]; sda_oe=1; 
        @(posedge aif.scl); 
        end
    sda_oe=0;
  endtask
  
endclass 

/////////////////////////////////////////////////////////////////////
`uvm_analysis_imp_decl(_exp)
`uvm_analysis_imp_decl(_act)

class ahb_i2c_scb extends uvm_scoreboard;
  `uvm_component_utils(ahb_i2c_scb)
      
  
  uvm_analysis_imp_exp #(ahb_txn, ahb_i2c_scb) ap_ahb;  
  uvm_analysis_imp_act #(ahb_txn, ahb_i2c_scb) ap_i2c;  
  
  ahb_txn exp_tr;
  ahb_txn act_tr;
  
  bit [31:0] exp_addr, exp_wdata, exp_rdata;
  bit        exp_wr;
    
  function new (string path = "ahb_i2c_scb", uvm_component parent = null);
    super.new(path,parent); 
  endfunction 

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_ahb = new("ap_ahb", this);
    ap_i2c = new("ap_i2c", this);
  endfunction

 
  function void write_exp(ahb_txn tr);
    exp_addr  = tr.HADDR;
    exp_wdata = tr.HWDATA;
    exp_rdata = tr.HRDATA;
    exp_wr    = tr.HWRITE;
    `uvm_info("SCB", 
    $sformatf("EXP: addr=%0h wdata=%0h wr=%0b", 
      exp_addr, exp_wdata, exp_wr), 
    UVM_LOW)
  endfunction
  
  
  function void write_act(ahb_txn tr);
    if (tr.write) begin
      if ((tr.write == exp_wr) &&
          (tr.addr  == exp_addr) &&
          (tr.wdata == exp_wdata))
        `uvm_info("SCB", "TEST PASSED", UVM_NONE)
      else
        `uvm_info("SCB", "TEST FAILED", UVM_NONE)
    end
    else begin
      if ((tr.write == exp_wr) &&
          (tr.addr  == exp_addr) &&
          (tr.rdata == exp_rdata))
        `uvm_info("SCB", "TEST PASSED", UVM_NONE)
      else
        `uvm_info("SCB", "TEST FAILED", UVM_NONE)
    end
  endfunction
 
endclass



////////////////////////////////////////////////////////////////////////////////////////

class ahb_agent extends uvm_agent;  
  ahb_drv drv;
  i2c_mon mon; 
  ahb_mon a_mon; 
  uvm_sequencer #(ahb_txn) seqr;
  
   `uvm_component_utils(ahb_agent)
   
  function new (string path = "ahb_agent", uvm_component parent = null);
    super.new(path,parent); 
  endfunction 

  function void build_phase(uvm_phase phase);
    drv  = ahb_drv::type_id::create("drv",this);
    mon  = i2c_mon::type_id::create("mon",this);
    a_mon  = ahb_mon::type_id::create("a_mon",this);
    seqr = uvm_sequencer #(ahb_txn)::type_id::create("seqr",this);
  endfunction

  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction
endclass


////////////////////////////////////////////////////////////////////////////////////////////

class env extends uvm_env;

  ahb_agent      a;
  ahb_i2c_scb    scb;

  `uvm_component_utils(env)
  
  function new(string path = "env", uvm_component parent = null);
    super.new(path,parent);
    endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    a   = ahb_agent::type_id::create("a", this);
    scb = ahb_i2c_scb::type_id::create("scb", this);
  endfunction


  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    a.a_mon.ap_ahb.connect(scb.ap_ahb);   // driver → scoreboard
    a.mon.ap_i2c.connect(scb.ap_i2c);      // monitor → scoreboard
  endfunction

endclass

   
///////////////////////////////////////////////////////////////////////////


class test extends uvm_test;
`uvm_component_utils(test)

function new(string inst = "test", uvm_component parent = null);
super.new(inst,parent);
endfunction

env e;
reset_dut rst;
write_seq wr;
read_seq rd;

virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
   rst  = reset_dut::type_id::create("rst");
   wr  = write_seq::type_id::create("wr");
   rd  = read_seq::type_id::create("rd");
   e  = env::type_id::create("env",this); 
endfunction

virtual task run_phase(uvm_phase phase);
phase.raise_objection(this);
rst.start(e.a.seqr);
wr.start(e.a.seqr);
//rd.start(e.a.seqr);

phase.drop_objection(this);
endtask
endclass


//////////////////////////////////////////////////////////////////////////

module tb_top;
  logic HCLK;
  
  initial begin 
    HCLK = 1'b0;
  end 
   always #5 HCLK = ~HCLK;
   
 
  ahb_if ahb_if_inst(HCLK);
  i2c_if i2c_if_inst();

  ahb_i2c_top dut (
    .HCLK(HCLK),
    .HRESETn(ahb_if_inst.HRESETn),
    .HSEL(ahb_if_inst.HSEL),
    .HADDR(ahb_if_inst.HADDR),
    .HWRITE(ahb_if_inst.HWRITE),
    .HTRANS(ahb_if_inst.HTRANS),
    .HWDATA(ahb_if_inst.HWDATA),
    .HRDATA(ahb_if_inst.HRDATA),
    .HREADY(ahb_if_inst.HREADY),
    .HREADYOUT(),
    .HRESP(),
    .scl(i2c_if_inst.scl),
    .sda(i2c_if_inst.sda)
  );

  initial begin
    uvm_config_db#(virtual ahb_if)::set(null,"*","vif",ahb_if_inst);
    uvm_config_db#(virtual i2c_if)::set(null,"*","aif",i2c_if_inst);
    run_test("test");
  end
  
endmodule
