/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Scaler coefficients rom
    (c) 2022, 2023 by Parretto B.V.

    History
    =======
    v1.0 - Initial release

    License
    =======
    This License will apply to the use of the IP-core (as defined in the License). 
    Please read the License carefully so that you know what your rights and obligations are when using the IP-core.
    The acceptance of this License constitutes a valid and binding agreement between Parretto and you for the use of the IP-core. 
    If you download and/or make any use of the IP-core you agree to be bound by this License. 
    The License is available for download and print at www.parretto.com/license.html
    Parretto grants you, as the Licensee, a free, non-exclusive, non-transferable, limited right to use the IP-core 
    solely for internal business purposes for the term and conditions of the License. 
    You are also allowed to create Modifications for internal business purposes, but explicitly only under the conditions of art. 3.2.
    You are, however, obliged to pay the License Fees to Parretto for the use of the IP-core, or any Modification, in, or embodied in, 
    a physical or non-tangible product or service that has substantial commercial, industrial or non-consumer uses. 
*/

`default_nettype none

module prt_scaler_coef
#(
    parameter    P_MODE = 2,   // Mode width
    parameter    P_IDX = 5,    // Index width
    parameter    P_DAT = 8     // Coefficient width
)
(
    // Reset and clock
    input wire                          CLK_IN,

    input wire [(P_MODE+P_IDX-1):0]     SEL_IN,         // Select
    output wire [P_DAT-1:0]             DAT_OUT
);

// Signals
logic [$size(SEL_IN)-1:0]   clk_sel;
logic [P_DAT-1:0]           clk_dat;

// Logic
    always_ff @ (posedge CLK_IN)
    begin
        clk_sel <= SEL_IN;
    end

generate
    always_ff @ (posedge CLK_IN)
    begin
        case (clk_sel)
            // Ratio 3/2
            {(P_MODE'(0)), (P_IDX'(1))}  : clk_dat <= 'd255;    // C1
            {(P_MODE'(0)), (P_IDX'(2))}  : clk_dat <= 'd128;    // C2
            {(P_MODE'(0)), (P_IDX'(3))}  : clk_dat <= 'd127;    // C3
            {(P_MODE'(0)), (P_IDX'(4))}  : clk_dat <= 'd237;    // C4
            {(P_MODE'(0)), (P_IDX'(5))}  : clk_dat <= 'd18;     // C5
            {(P_MODE'(0)), (P_IDX'(6))}  : clk_dat <= 'd64;     // C6
            {(P_MODE'(0)), (P_IDX'(7))}  : clk_dat <= 'd64;     // C7
            {(P_MODE'(0)), (P_IDX'(8))}  : clk_dat <= 'd64;     // C8
            {(P_MODE'(0)), (P_IDX'(9))}  : clk_dat <= 'd63;     // C9
            {(P_MODE'(0)), (P_IDX'(10))} : clk_dat <= 'd97;     // C10
            {(P_MODE'(0)), (P_IDX'(11))} : clk_dat <= 'd31;     // C11
            {(P_MODE'(0)), (P_IDX'(12))} : clk_dat <= 'd97;     // C12
            {(P_MODE'(0)), (P_IDX'(13))} : clk_dat <= 'd30;     // C13
            {(P_MODE'(0)), (P_IDX'(14))} : clk_dat <= 'd122;    // C14
            {(P_MODE'(0)), (P_IDX'(15))} : clk_dat <= 'd63;     // C15
            {(P_MODE'(0)), (P_IDX'(16))} : clk_dat <= 'd63;     // C16
            {(P_MODE'(0)), (P_IDX'(17))} : clk_dat <= 'd7;      // C17

            // Ratio 2/1
            {(P_MODE'(1)), (P_IDX'(1))} : clk_dat <= 'd114;     // C1
            {(P_MODE'(1)), (P_IDX'(2))} : clk_dat <= 'd64;      // C2
            {(P_MODE'(1)), (P_IDX'(3))} : clk_dat <= 'd13;      // C3

            // Ratio 3/1
            {(P_MODE'(2)), (P_IDX'(1))}  : clk_dat <= 'd255;     // C1
            {(P_MODE'(2)), (P_IDX'(2))}  : clk_dat <= 'd201;     // C2
            {(P_MODE'(2)), (P_IDX'(3))}  : clk_dat <= 'd51;      // C3
            {(P_MODE'(2)), (P_IDX'(4))}  : clk_dat <= 'd194;     // C4
            {(P_MODE'(2)), (P_IDX'(5))}  : clk_dat <= 'd61;      // C5
            {(P_MODE'(2)), (P_IDX'(6))}  : clk_dat <= 'd219;     // C6
            {(P_MODE'(2)), (P_IDX'(7))}  : clk_dat <= 'd36;      // C7
            {(P_MODE'(2)), (P_IDX'(8))}  : clk_dat <= 'd104;     // C8
            {(P_MODE'(2)), (P_IDX'(9))}  : clk_dat <= 'd69;      // C9
            {(P_MODE'(2)), (P_IDX'(10))} : clk_dat <= 'd59;      // C10
            {(P_MODE'(2)), (P_IDX'(11))} : clk_dat <= 'd23;      // C11

            // Ratio 4/3
            {(P_MODE'(3)), (P_IDX'(1))}  : clk_dat <= 'd255;     // C1
            {(P_MODE'(3)), (P_IDX'(2))}  : clk_dat <= 'd77;      // C2
            {(P_MODE'(3)), (P_IDX'(3))}  : clk_dat <= 'd178;     // C3
            {(P_MODE'(3)), (P_IDX'(4))}  : clk_dat <= 'd140;     // C4
            {(P_MODE'(3)), (P_IDX'(5))}  : clk_dat <= 'd115;     // C5
            {(P_MODE'(3)), (P_IDX'(6))}  : clk_dat <= 'd209;     // C6
            {(P_MODE'(3)), (P_IDX'(7))}  : clk_dat <= 'd46;      // C7
            {(P_MODE'(3)), (P_IDX'(8))}  : clk_dat <= 'd11;      // C8
            {(P_MODE'(3)), (P_IDX'(9))}  : clk_dat <= 'd66;      // C9
            {(P_MODE'(3)), (P_IDX'(10))} : clk_dat <= 'd112;     // C10
            {(P_MODE'(3)), (P_IDX'(11))} : clk_dat <= 'd48;      // C11
            {(P_MODE'(3)), (P_IDX'(12))} : clk_dat <= 'd36;      // C12
            {(P_MODE'(3)), (P_IDX'(13))} : clk_dat <= 'd92;      // C13
            {(P_MODE'(3)), (P_IDX'(14))} : clk_dat <= 'd79;      // C14
            {(P_MODE'(3)), (P_IDX'(15))} : clk_dat <= 'd77;      // C15
            {(P_MODE'(3)), (P_IDX'(16))} : clk_dat <= 'd13;      // C16
            {(P_MODE'(3)), (P_IDX'(17))} : clk_dat <= 'd117;     // C17
            {(P_MODE'(3)), (P_IDX'(18))} : clk_dat <= 'd48;      // C18
            {(P_MODE'(3)), (P_IDX'(19))} : clk_dat <= 'd8;       // C19
            {(P_MODE'(3)), (P_IDX'(20))} : clk_dat <= 'd87;      // C20
            {(P_MODE'(3)), (P_IDX'(21))} : clk_dat <= 'd40;      // C21
            {(P_MODE'(3)), (P_IDX'(22))} : clk_dat <= 'd120;     // C22
            {(P_MODE'(3)), (P_IDX'(23))} : clk_dat <= 'd148;     // C23
            {(P_MODE'(3)), (P_IDX'(24))} : clk_dat <= 'd107;     // C24
            {(P_MODE'(3)), (P_IDX'(25))} : clk_dat <= 'd38;      // C25
            {(P_MODE'(3)), (P_IDX'(26))} : clk_dat <= 'd84;      // C26
            {(P_MODE'(3)), (P_IDX'(27))} : clk_dat <= 'd51;      // C27
            {(P_MODE'(3)), (P_IDX'(28))} : clk_dat <= 'd82;      // C28
            {(P_MODE'(3)), (P_IDX'(29))} : clk_dat <= 'd84;      // C29
            {(P_MODE'(3)), (P_IDX'(30))} : clk_dat <= 'd61;      // C30
            {(P_MODE'(3)), (P_IDX'(31))} : clk_dat <= 'd61;      // C31
            {(P_MODE'(3)), (P_IDX'(32))} : clk_dat <= 'd49;      // C32
            {(P_MODE'(3)), (P_IDX'(33))} : clk_dat <= 'd102;     // C33
            {(P_MODE'(3)), (P_IDX'(34))} : clk_dat <= 'd36;      // C34
            {(P_MODE'(3)), (P_IDX'(35))} : clk_dat <= 'd92;      // C35
            {(P_MODE'(3)), (P_IDX'(36))} : clk_dat <= 'd25;      // C36
            {(P_MODE'(3)), (P_IDX'(37))} : clk_dat <= 'd28;      // C37
            {(P_MODE'(3)), (P_IDX'(38))} : clk_dat <= 'd107;     // C38
            {(P_MODE'(3)), (P_IDX'(39))} : clk_dat <= 'd20;      // C39
            {(P_MODE'(3)), (P_IDX'(40))} : clk_dat <= 'd100;     // C40
            {(P_MODE'(3)), (P_IDX'(41))} : clk_dat <= 'd240;     // C41
            {(P_MODE'(3)), (P_IDX'(42))} : clk_dat <= 'd15;      // C42
            {(P_MODE'(3)), (P_IDX'(43))} : clk_dat <= 'd79;      // C43
            {(P_MODE'(3)), (P_IDX'(44))} : clk_dat <= 'd115;     // C44
            {(P_MODE'(3)), (P_IDX'(45))} : clk_dat <= 'd13;      // C45
            {(P_MODE'(3)), (P_IDX'(46))} : clk_dat <= 'd48;      // C46
            {(P_MODE'(3)), (P_IDX'(47))} : clk_dat <= 'd102;     // C47
            {(P_MODE'(3)), (P_IDX'(48))} : clk_dat <= 'd92;      // C48
            {(P_MODE'(3)), (P_IDX'(49))} : clk_dat <= 'd36;      // C49
            {(P_MODE'(3)), (P_IDX'(50))} : clk_dat <= 'd25;      // C50
            {(P_MODE'(3)), (P_IDX'(51))} : clk_dat <= 'd122;     // C51
            {(P_MODE'(3)), (P_IDX'(52))} : clk_dat <= 'd63;      // C52
            {(P_MODE'(3)), (P_IDX'(53))} : clk_dat <= 'd63;      // C53
            {(P_MODE'(3)), (P_IDX'(54))} : clk_dat <= 'd7;       // C54
            {(P_MODE'(3)), (P_IDX'(55))} : clk_dat <= 'd56;      // C55
            {(P_MODE'(3)), (P_IDX'(56))} : clk_dat <= 'd122;     // C56
            {(P_MODE'(3)), (P_IDX'(57))} : clk_dat <= 'd6;       // C57
            {(P_MODE'(3)), (P_IDX'(58))} : clk_dat <= 'd71;      // C58
            {(P_MODE'(3)), (P_IDX'(59))} : clk_dat <= 'd3;       // C59
            {(P_MODE'(3)), (P_IDX'(60))} : clk_dat <= 'd252;     // C60
            {(P_MODE'(3)), (P_IDX'(61))} : clk_dat <= 'd8;       // C61
            {(P_MODE'(3)), (P_IDX'(62))} : clk_dat <= 'd40;      // C62
            {(P_MODE'(3)), (P_IDX'(63))} : clk_dat <= 'd87;      // C63
            {(P_MODE'(3)), (P_IDX'(64))} : clk_dat <= 'd120;     // C64
            {(P_MODE'(3)), (P_IDX'(65))} : clk_dat <= 'd28;      // C65
            {(P_MODE'(3)), (P_IDX'(66))} : clk_dat <= 'd20;      // C66
            {(P_MODE'(3)), (P_IDX'(67))} : clk_dat <= 'd107;     // C67
            {(P_MODE'(3)), (P_IDX'(68))} : clk_dat <= 'd100;     // C68
            {(P_MODE'(3)), (P_IDX'(69))} : clk_dat <= 'd56;      // C69
            {(P_MODE'(3)), (P_IDX'(70))} : clk_dat <= 'd5;       // C70
            {(P_MODE'(3)), (P_IDX'(71))} : clk_dat <= 'd122;     // C71
            {(P_MODE'(3)), (P_IDX'(72))} : clk_dat <= 'd72;      // C72
            {(P_MODE'(3)), (P_IDX'(73))} : clk_dat <= 'd4;       // C73
            {(P_MODE'(3)), (P_IDX'(74))} : clk_dat <= 'd63;      // C74
            {(P_MODE'(3)), (P_IDX'(75))} : clk_dat <= 'd63;      // C75
            {(P_MODE'(3)), (P_IDX'(76))} : clk_dat <= 'd125;     // C76
            default : clk_dat <= 'd0;
        endcase
    end
endgenerate

// Outputs
    assign DAT_OUT = clk_dat;

endmodule

`default_nettype wire
