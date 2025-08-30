module d_flip_flop (
    input wire d,       
    input wire clk,    
    input wire rst,
    output reg q);

always @(posedge clk or posedge rst)
begin
if ( rst ) 
    q <= 0;
else
    q <= d;
end
endmodule
