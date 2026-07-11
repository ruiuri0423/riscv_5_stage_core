function [31:0] ADD;
  input [31:0] din1;
  input [31:0] din2;
  
  ADD = din1 + din2;

endfunction

function [31:0] AND;
  input [31:0] din1;
  input [31:0] din2;

  AND = din1 & din2;

endfunction

function [31:0] OR;
  input [31:0] din1;
  input [31:0] din2;

  OR = din1 | din2;

endfunction

function [31:0] XOR;
  input [31:0] din1;
  input [31:0] din2;

  XOR = din1 ^ din2;

endfunction

function [31:0] SLL;
  input [31:0] din1;
  input [31:0] din2;

  SLL = din1 << din2[4:0];

endfunction

function [31:0] SRL;
  input [31:0] din1;
  input [31:0] din2;

  SRL = din1 >> din2[4:0];

endfunction

function [31:0] SRA;
  input [31:0] din1;
  input [31:0] din2;

  reg [62:0] ext_din1;
  reg [62:0] ext_shf1;

  ext_din1 = {{31{din1[31]}}, din1};
  ext_shf1 = ext_din1 >> din2[4:0];

  SRA = ext_shf1[31:0];

endfunction

function [31:0] SUB;
  input [31:0] din1;
  input [31:0] din2;

  SUB = din1 - din2;

endfunction

function [31:0] NPC;
  input [31:0] pc_i;

  NPC = pc_i + 3'd4;

endfunction

function EQ;
  input [31:0] din1;
  input [31:0] din2;

  EQ = (din1 == din2);

endfunction

function NE;
  input [31:0] din1;
  input [31:0] din2;

  NE = (din1 != din2);

endfunction

function LT;
  input [31:0] din1;
  input [31:0] din2;

  reg lt0, lt1, lt2, lt3;

  lt0 = din1[31] & ~din2[31];
  lt1 = din1[31] & din2[31];
  lt2 = ~din1[31] & ~din2[31];
  lt3 = din1 < din2;

  LT = lt0 | ((lt1 | lt2) & lt3);

endfunction

function LTU;
  input [31:0] din1;
  input [31:0] din2;

  LTU = (din1 < din2);

endfunction

function GE;
  input [31:0] din1;
  input [31:0] din2;

  reg lt0, lt1, lt2, lt3;

  lt0 = ~din1[31] & din2[31];
  lt1 = din1[31] & din2[31];
  lt2 = ~din1[31] & ~din2[31];
  lt3 = din1 >= din2;

  GE = lt0 | ((lt1 | lt2) & lt3);

endfunction

function GEU;
  input [31:0] din1;
  input [31:0] din2;

  GEU = (din1 >= din2);

endfunction

function [31:0] ASG;
  input [31:0] din1;

  ASG = din1;

endfunction