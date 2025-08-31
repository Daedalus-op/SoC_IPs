module map (
    output reg [3:0] dec,
    input [7:0] ascii
);

  always @(*) begin
    case (ascii)
      8'd48: dec = 4'd0;
      8'd49: dec = 4'd1;
      8'd50: dec = 4'd2;
      8'd51: dec = 4'd3;
      8'd52: dec = 4'd4;
      8'd53: dec = 4'd5;
      8'd54: dec = 4'd6;
      8'd55: dec = 4'd7;
      8'd56: dec = 4'd8;
      8'd57: dec = 4'd9;

      8'd97:  dec = 4'd10;
      8'd98:  dec = 4'd11;
      8'd99:  dec = 4'd12;
      8'd100: dec = 4'd13;
      8'd101: dec = 4'd14;
      8'd102: dec = 4'd15;
    endcase
  end

endmodule

module unmap (
    output reg [7:0] ascii,
    input [3:0] dec
);
  reg [3:0] dec1;
  always @(*) begin

    // if (dec < 4'd0) dec1 = dec + 5'd16;
    // else if (dec > 4'd15) dec1 = dec - 5'd16;
    // else dec1 = dec;

    case (dec)
      4'd0: ascii = 8'd48;
      4'd1: ascii = 8'd49;
      4'd2: ascii = 8'd50;
      4'd3: ascii = 8'd51;
      4'd4: ascii = 8'd52;
      4'd5: ascii = 8'd53;
      4'd6: ascii = 8'd54;
      4'd7: ascii = 8'd55;
      4'd8: ascii = 8'd56;
      4'd9: ascii = 8'd57;

      4'd10:   ascii = 8'd97;
      4'd11:   ascii = 8'd98;
      4'd12:   ascii = 8'd99;
      4'd13:   ascii = 8'd100;
      4'd14:   ascii = 8'd101;
      4'd15:   ascii = 8'd102;
      default: ascii = 8'd95;
    endcase
  end

endmodule
