`timescale 1ns / 1ps
module Top_Game#(
    parameter HDISPLAY = 640,
    parameter HFRONT_PORCH = 16,
    parameter HRETRACE = 96,
    parameter HBACK_PORCH = 48,
    parameter HMAX = HFRONT_PORCH + HRETRACE + HBACK_PORCH + HDISPLAY,

    parameter VDISPLAY = 480,
    parameter VFRONT_PORCH = 10,
    parameter VRETRACE = 2,
    parameter VBACK_PORCH = 33,
    parameter VMAX = VFRONT_PORCH + VRETRACE + VBACK_PORCH + VDISPLAY
)

(
    input clk_100MHz,
    input sprite_up,
    input sprite_down,
    input sprite_left,
    input sprite_right,
    output hsync,
    output vsync,
    output video_on,
    output [11:0] pixel_data_to_VGA_Output
);
  clk_wiz_0 Custom_Clock
   (
    // Clock out ports
    .clk_25MHz(clk_25MHz),     // output clk_25MHz
    // Status and control signals
    .reset(reset), // input reset
    .locked(locked),       // output locked
   // Clock in ports
    .clk_in1(clk_100MHz)      // input clk_in1
);
    // Tracking Pixels
    wire signed [11:0] current_xpixel_position,current_ypixel_position;
    // Background color Generated
    wire [11:0] generated_background_color;
    // Output Data from Blender to Controller
    wire [11:0] data_from_blender_to_VGA_controller;
    // Sprite Data from Sprite Ram 
    wire [11:0] ram_sprite_pixel_data;
  VGA_Frame_Counter #(
        .HDISPLAY(HDISPLAY),
        .HFRONT_PORCH(HFRONT_PORCH),
        .HRETRACE(HRETRACE),
        .HBACK_PORCH(HBACK_PORCH),
        .HMAX(HMAX),
        .VDISPLAY(VDISPLAY),
        .VFRONT_PORCH(VFRONT_PORCH),
        .VRETRACE(VRETRACE),
        .VBACK_PORCH(VBACK_PORCH),
        .VMAX(VMAX)
    ) Global_Frame_Counter (
        .clk_pixel(clk_25MHz),
        .current_xpixel_position(current_xpixel_position),
        .current_ypixel_position(current_ypixel_position),
        .frame_start(),  
        .frame_end()
    );
    
    BackGround_Image_Ram_640x480(
        .current_xpixel_position(current_xpixel_position),
        .current_ypixel_position(current_ypixel_position),
        .pixel_data_to_blender(generated_background_color)
    );
    
    Sprite_Generation_Circuit Sprite_Gen1(
        .current_xpixel_position(current_xpixel_position),
        .current_ypixel_position(current_ypixel_position),
        .clk(clk_25MHz),
        .ram_sprite_pixel_data(ram_sprite_pixel_data),
        .sprite_up(sprite_up),
        .sprite_down(sprite_down),
        .sprite_left(sprite_left),
        .sprite_right(sprite_right)
    );
    
    Blender_Mux Blender(
        .ram_sprite_pixel_data(ram_sprite_pixel_data),
        .bg_generated(generated_background_color),
        .pixel_data_from_blender(data_from_blender_to_VGA_controller)
    );
    
    VGA_Controller#(
        .HDISPLAY(HDISPLAY),
        .HFRONT_PORCH(HFRONT_PORCH),
        .HRETRACE(HRETRACE),
        .HBACK_PORCH(HBACK_PORCH),
        .HMAX(HMAX),
        .VDISPLAY(VDISPLAY),
        .VFRONT_PORCH(VFRONT_PORCH),
        .VRETRACE(VRETRACE),
        .VBACK_PORCH(VBACK_PORCH),
        .VMAX(VMAX)
    ) VGA_Protocol(
        .clk_25MHz(clk_25MHz),
        .pixel_data_from_blender(data_from_blender_to_VGA_controller),
        .hsync(hsync),
        .vsync(vsync),
        .vid_on(video_on),
        .bgr_data_to_monitor(pixel_data_to_VGA_Output)
    );
endmodule
// ############################ SUB MODULE CREATION ####################################
//*************************************************
//              VGA Protocol Modules
//*************************************************
module VGA_Frame_Counter#(    
    parameter HDISPLAY = 640,
    parameter HFRONT_PORCH = 16,
    parameter HRETRACE = 96,
    parameter HBACK_PORCH = 48,
    parameter HMAX = HFRONT_PORCH + HRETRACE + HBACK_PORCH+HDISPLAY,
    
    parameter VDISPLAY = 480,
    parameter VFRONT_PORCH = 10,
    parameter VRETRACE = 2,
    parameter VBACK_PORCH = 33,
    parameter VMAX = VFRONT_PORCH + VRETRACE + VBACK_PORCH+VDISPLAY
    )
    (
    input clk_pixel,
    output reg signed [11:0]  current_ypixel_position,
    output reg signed [11:0]  current_xpixel_position,
    output frame_start,
    output frame_end
    );
    initial begin
        current_ypixel_position = 0;
        current_xpixel_position = 0;   
    end
    
    assign frame_start = (current_xpixel_position == 0)&&(current_ypixel_position == 0);
    assign frame_end = (current_xpixel_position == (HDISPLAY-1))&&(current_ypixel_position == (VDISPLAY-1));
    // Incrementing Horizontal
    always @(posedge clk_pixel)begin 
        if(current_xpixel_position == (HMAX - 1))begin
           current_xpixel_position <= 0;
        end

        else begin
            current_xpixel_position <= current_xpixel_position + 1;
        end 
    end

// Incrementing Vertical
   always @(posedge clk_pixel)begin
        if((current_xpixel_position == (HMAX - 1))&& (current_ypixel_position == VMAX-1)) begin 
            current_ypixel_position <= 0;
        end
        else if(current_xpixel_position == (HMAX - 1)&& (current_ypixel_position < VMAX-1))begin
             current_ypixel_position <= current_ypixel_position + 1;
        end
    end
endmodule
module VGA_Pixel_Position_Decoding#(    
    parameter HDISPLAY = 640,
    parameter HFRONT_PORCH = 16,
    parameter HRETRACE = 96,
    parameter HBACK_PORCH = 48,
    parameter HMAX = HFRONT_PORCH + HRETRACE + HBACK_PORCH + HDISPLAY,
    
    parameter VDISPLAY = 480,
    parameter VFRONT_PORCH = 10,
    parameter VRETRACE = 2,
    parameter VBACK_PORCH = 33,
    parameter VMAX = VFRONT_PORCH + VRETRACE + VBACK_PORCH + VDISPLAY)
    (
        input signed [11:0] current_ypixel_position,
        input signed [11:0] current_xpixel_position,
        output reg hsync_pulse,
        output reg vsync_pulse,
        output reg video_on
    );
    always @(*)begin
    // Assert/Deassert H Pulse
        hsync_pulse <= ~((current_xpixel_position >= HDISPLAY + HFRONT_PORCH)&&(current_xpixel_position <= HDISPLAY + HFRONT_PORCH+ HRETRACE-2 ));
    // Assert/Deassert V Pulse
        vsync_pulse <= ~((current_ypixel_position >= VDISPLAY + VFRONT_PORCH)&&(current_ypixel_position <= VDISPLAY + VFRONT_PORCH+ VRETRACE - 2 ));
    // Assert/Deassert Video On
        video_on <= ((current_xpixel_position < HDISPLAY-1)&&(current_ypixel_position <= VDISPLAY-1));
    end
endmodule
module VGA_Controller#(    
    parameter HDISPLAY = 640,
    parameter HFRONT_PORCH = 16,
    parameter HRETRACE = 96,
    parameter HBACK_PORCH = 48,
    parameter HMAX = HFRONT_PORCH + HRETRACE + HBACK_PORCH+HDISPLAY,
    
    parameter VDISPLAY = 480,
    parameter VFRONT_PORCH = 10,
    parameter VRETRACE = 2,
    parameter VBACK_PORCH = 33,
    parameter VMAX = VFRONT_PORCH + VRETRACE + VBACK_PORCH + VDISPLAY)
    (
    input clk_25MHz,
    input [11:0] pixel_data_from_blender,
    output hsync,
    output vsync,
    output vid_on,
    output reg [11:0] bgr_data_to_monitor
);

// Internal Connections 
wire signed [11:0] current_ypixel_position,current_xpixel_position;


//Electron Beam 
VGA_Frame_Counter#(
        .HDISPLAY(HDISPLAY),
        .HFRONT_PORCH(HFRONT_PORCH),
        .HRETRACE(HRETRACE),
        .HBACK_PORCH(HBACK_PORCH),
        .HMAX(HMAX),
        .VDISPLAY(VDISPLAY),
        .VFRONT_PORCH(VFRONT_PORCH),
        .VRETRACE(VRETRACE),
        .VBACK_PORCH(VBACK_PORCH),
        .VMAX(VMAX)
    )Pixel_Tracker(
        .clk_pixel(clk_25MHz),        
        .current_ypixel_position(current_ypixel_position),   
        .current_xpixel_position(current_xpixel_position),   
        .frame_start(),               // Optionally connect frame_start if used
        .frame_end()                  // Optionally connect frame_end if used
    );
//VGA Procotol 
VGA_Pixel_Position_Decoding#(
        .HDISPLAY(HDISPLAY),
        .HFRONT_PORCH(HFRONT_PORCH),
        .HRETRACE(HRETRACE),
        .HBACK_PORCH(HBACK_PORCH),
        .HMAX(HMAX),
        .VDISPLAY(VDISPLAY),
        .VFRONT_PORCH(VFRONT_PORCH),
        .VRETRACE(VRETRACE),
        .VBACK_PORCH(VBACK_PORCH),
        .VMAX(VMAX)
    )VGA_Decoder(
    .current_ypixel_position(current_ypixel_position),
    .current_xpixel_position(current_xpixel_position),
    .hsync_pulse(hsync),     // Connect to top-level hsync output
    .vsync_pulse(vsync),     // Connect to top-level vsync output
    .video_on(vid_on)        // Connect to top-level vid_on reg
    );

    always@(*)begin 
        if(vid_on)begin
            bgr_data_to_monitor <= pixel_data_from_blender;
        end
        else begin 
            bgr_data_to_monitor <= {12'h000};
        end
    end
endmodule
//*************************************************
//              Back Ground Color Tester
//*************************************************
module BG_Generated_Test(
    input pixel_clock,
    output reg [11:0] bg_generated
);
    always@ (posedge pixel_clock)begin
        bg_generated = 12'b111111111111;
    end
endmodule 
//*************************************************
//              BackGround Ram  
//*************************************************
module BackGround_Image_Ram_640x480 #(
    parameter color_depth = 12, // bits per pixel
    parameter sprite_resolution_x = 640,
    parameter sprite_resolution_y = 480,
    parameter image_path = "Path to Image Here", // Update with the correct file path
    parameter resolution_width = 10
)
(
    input wire signed [resolution_width+1:0] current_xpixel_position,
    input wire signed [resolution_width+1:0] current_ypixel_position,
    output reg [color_depth-1:0] pixel_data_to_blender
);

    // Calculate the total number of pixels and addressable lines
    localparam num_pixels = sprite_resolution_x * sprite_resolution_y;
    // Define the RAM to hold all pixel data
    reg [color_depth-1:0] ram [0:num_pixels-1];
    reg[18:0] ram_address; // Adjusted for larger address space

    // Load the pixel data into the RAM at initialization
    initial begin
        $readmemh(image_path, ram);
    end

    // Assign the pixel data from the RAM based on the address
    always @(*) begin
        if((current_xpixel_position <=640)&&(current_ypixel_position<=480))begin
            ram_address <= current_ypixel_position * sprite_resolution_x + current_xpixel_position;
            pixel_data_to_blender <= ram[ram_address];
        end
    end
endmodule
//*************************************************
//              Sprite Gen Modules 
//*************************************************
module Sprite_Generation_Circuit #(
    parameter [11:0] chroma_key = 12'h000,
    parameter resolution_width_bits = 12,
    parameter color_depth = 12
)(
    input clk,
    input signed [resolution_width_bits-1:0] current_xpixel_position,
    input signed [resolution_width_bits-1:0] current_ypixel_position,
    input sprite_up,
    input sprite_down,
    input sprite_left,
    input sprite_right,
    output [color_depth-1:0] ram_sprite_pixel_data
);

    // Internal Registers
    wire in_sprite_region;
    wire signed [resolution_width_bits-1:0] x_relative; // Assuming your system can handle negative coordinates
    wire signed [resolution_width_bits-1:0] y_relative;
    wire read_bit;
    wire [color_depth-1:0] sprite_ram_data;


    // Instantiate the Relative_Position module
    Relative_Position sprite_square_check(
        .clk(clk),
        .current_xpixel_position(current_xpixel_position),
        .current_ypixel_position(current_ypixel_position),
        .sprite_up(sprite_up),
        .sprite_down(sprite_down),
        .sprite_left(sprite_left),
        .sprite_right(sprite_right),
        .x_relative(x_relative),
        .y_relative(y_relative)
    );

    // Instantiate the In_Region module
    In_Region_64x64 region_check(
        .x_relative(x_relative),
        .y_relative(y_relative),
        .in_sprite_region(in_sprite_region)
    );

    // Continuous assignment for read_bit
    assign read_bit = in_sprite_region;

    // Instantiate the Sprite_Image_Ram module
    Sprite_Image_Ram_64x64 sprite_ram(
        .x_relative(x_relative),
        .y_relative(y_relative),
        .read_bit(read_bit),
        .pixel_data_from_blender(sprite_ram_data)
    );

    Sprite_Mux Sprite_Pixel_Selct(
        .in_sprite_region(in_sprite_region),
        .chroma_key(chroma_key),
        .sprite_ram_data(sprite_ram_data),
        .ram_sprite_pixel_data(ram_sprite_pixel_data)
    );
    

endmodule
module Relative_Position#(
    parameter resolution_width_bits = 10
)
(
    input clk,
    input sprite_up,
    input sprite_down,
    input sprite_left,
    input sprite_right,
    input signed [resolution_width_bits+1:0] current_xpixel_position,
    input signed [resolution_width_bits+1:0] current_ypixel_position,
    output reg signed [resolution_width_bits+1:0] x_relative,
    output reg signed [resolution_width_bits+1:0] y_relative
);
    // Internal registers for origin tracking
    reg signed [resolution_width_bits+1:0] xsprite_origin;
    reg signed [resolution_width_bits+1:0] ysprite_origin;

    // Internal Regs for updated origins
    wire signed [resolution_width_bits+1:0] updated_xorigin;
    wire signed [resolution_width_bits+1:0] updated_yorigin;

    // Initialize the internal registers with input values
    initial begin
        xsprite_origin = 320;
        ysprite_origin = 220;
    end

       Sprite_Movement #( 
        // Parameters if required
    ) Movement (
        .clk(clk),
        .xsprite_origin_in(xsprite_origin),
        .ysprite_origin_in(ysprite_origin),
        .up(sprite_up),
        .down(sprite_down),
        .left(sprite_left),
        .right(sprite_right),
        .xsprite_origin_out(updated_xorigin),
        .ysprite_origin_out(updated_yorigin)
    );
    always @(*) begin
        x_relative = current_xpixel_position - updated_xorigin;
        y_relative = current_ypixel_position - updated_yorigin;
    end

endmodule
module Sprite_Mux(
    input in_sprite_region,
    input [11:0] chroma_key,
    input [11:0] sprite_ram_data,
    output reg [11:0] ram_sprite_pixel_data
);
    always@(*)begin
        if(in_sprite_region)begin
            ram_sprite_pixel_data = sprite_ram_data;
        end
        else begin
            ram_sprite_pixel_data = chroma_key;
        end
    end
endmodule
module In_Region_16x16#(
    parameter resolution_width = 10,
    parameter signed [5:0]sprite_height = 16,
    parameter signed [5:0] sprite_width = 16
)
(
    input signed [resolution_width+1:0] x_relative,
    input signed [resolution_width+1:0] y_relative,
    output in_sprite_region
);
    assign in_sprite_region = (((x_relative >=0)&&(x_relative <= sprite_width)) && ((y_relative >=0)&&(y_relative <= sprite_height)));
endmodule
module In_Region_32x32#(
    parameter resolution_width = 10,
    parameter signed [6:0]sprite_height = 32,
    parameter signed [6:0] sprite_width = 32
)
(
    input signed [resolution_width+1:0] x_relative,
    input signed [resolution_width+1:0] y_relative,
    output in_sprite_region
);
    assign in_sprite_region = (((x_relative >=0)&&(x_relative <= sprite_width)) && ((y_relative >=0)&&(y_relative <= sprite_height)));
endmodule
module In_Region_64x64#(
    parameter resolution_width = 10,
    parameter signed [7:0]sprite_height = 64,
    parameter signed [7:0] sprite_width = 64
)
(
    input signed [resolution_width+1:0] x_relative,
    input signed [resolution_width+1:0] y_relative,
    output in_sprite_region
);
    assign in_sprite_region = (((x_relative >=0)&&(x_relative <= sprite_width)) && ((y_relative >=0)&&(y_relative <= sprite_height)));
endmodule
//*************************************************
//              Sprite Rams 
//*************************************************
module Sprite_Image_Ram_16x16 #(
    parameter color_depth = 12, // bits per pixel
    parameter sprite_resolution = 16,
    parameter image_path = "Path to Image Here", // Assuming this is for simulation only.
    parameter resolution_width = 10
)
(
    input wire signed [resolution_width+1:0] x_relative,
    input wire signed [resolution_width+1:0] y_relative,
    input wire read_bit, // Added this input to control the read operation.
    output reg [color_depth-1:0] pixel_data_from_blender
);

    // Calculate the total number of pixels and addressable lines
    localparam num_pixels = sprite_resolution * sprite_resolution;
    // Define the RAM to hold all pixel data
    reg [color_depth-1:0] ram [0:num_pixels-1];
    reg[7:0] ram_address;
    // Load the pixel data into the RAM at initialization
    initial begin
        $readmemh(image_path, ram);
    end

    // Assign the pixel data from the RAM based on the address
    always @(*) begin
        // Only calculate the address and access RAM if coordinates are non-negative and read_bit is asserted
        if (read_bit && x_relative >= 0 && y_relative >= 0 && x_relative < sprite_resolution && y_relative < sprite_resolution) begin
            // Calculate the address within the always block to ensure it is only done with valid coordinates
            ram_address  <= y_relative * sprite_resolution + x_relative;
            pixel_data_from_blender <= ram[y_relative * sprite_resolution + x_relative];
        end else begin
            // Output zero or chroma key when coordinates are out of bounds or read_bit is not asserted
            pixel_data_from_blender = {color_depth{1'b0}};
        end
    end
endmodule
module Sprite_Image_Ram_32x32 #(
    parameter color_depth = 12, // bits per pixel
    parameter sprite_resolution = 32,
    parameter image_path = "Path to Image Here", // Assuming this is for simulation only.
    parameter resolution_width = 10
)
(
    input wire signed [resolution_width+1:0] x_relative,
    input wire signed [resolution_width+1:0] y_relative,
    input wire read_bit, // Added this input to control the read operation.
    output reg [color_depth-1:0] pixel_data_from_blender
);

    // Calculate the total number of pixels and addressable lines
    localparam num_pixels = sprite_resolution * sprite_resolution;
    // Define the RAM to hold all pixel data
    reg [color_depth-1:0] ram [0:num_pixels-1];
    reg[9:0] ram_address;
    // Load the pixel data into the RAM at initialization
    initial begin
        $readmemh(image_path, ram);
    end

    // Assign the pixel data from the RAM based on the address
    always @(*) begin
        // Only calculate the address and access RAM if coordinates are non-negative and read_bit is asserted
        if (read_bit && x_relative >= 0 && y_relative >= 0 && x_relative < sprite_resolution && y_relative < sprite_resolution) begin
            // Calculate the address within the always block to ensure it is only done with valid coordinates
            ram_address  <= y_relative * sprite_resolution + x_relative;
            pixel_data_from_blender <= ram[y_relative * sprite_resolution + x_relative];
        end else begin
            // Output zero or chroma key when coordinates are out of bounds or read_bit is not asserted
            pixel_data_from_blender = {color_depth{1'b0}};
        end
    end
endmodule
module Sprite_Image_Ram_64x64 #(
    parameter color_depth = 12, // bits per pixel
    parameter sprite_resolution = 64,
    parameter image_path = "Path to Image Here", // Assuming this is for simulation only.
    parameter resolution_width = 10
)
(
    input wire signed [resolution_width+1:0] x_relative,
    input wire signed [resolution_width+1:0] y_relative,
    input wire read_bit, // Added this input to control the read operation.
    output reg [color_depth-1:0] pixel_data_from_blender
);

    // Calculate the total number of pixels and addressable lines
    localparam num_pixels = sprite_resolution * sprite_resolution;
    // Define the RAM to hold all pixel data
    reg [color_depth-1:0] ram [0:num_pixels-1];
    reg[11:0] ram_address;
    // Load the pixel data into the RAM at initialization
    initial begin
        $readmemh(image_path, ram);
    end

    // Assign the pixel data from the RAM based on the address
    always @(*) begin
        // Only calculate the address and access RAM if coordinates are non-negative and read_bit is asserted
        if (read_bit && x_relative >= 0 && y_relative >= 0 && x_relative < sprite_resolution && y_relative < sprite_resolution) begin
            // Calculate the address within the always block to ensure it is only done with valid coordinates
            ram_address  <= y_relative * sprite_resolution + x_relative;
            pixel_data_from_blender <= ram[y_relative * sprite_resolution + x_relative];
        end else begin
            // Output zero or chroma key when coordinates are out of bounds or read_bit is not asserted
            pixel_data_from_blender = {color_depth{1'b0}};
        end
    end
endmodule

//*************************************************
//              Chroma Blender Mux Module 
//*************************************************
module Blender_Mux(
    input [11:0] ram_sprite_pixel_data, 
    input [11:0] bg_generated,           
    output reg [11:0] pixel_data_from_blender     
);
    always @(*) begin
        if (ram_sprite_pixel_data == 12'h000) begin
            pixel_data_from_blender = bg_generated;
        end else begin
            pixel_data_from_blender = ram_sprite_pixel_data;
        end
    end
endmodule
//*************************************************
//              Sprite Movement 
//*************************************************
module Sprite_Movement#(
    parameter movement_scalar = 10,
    parameter max_x = 608,  // Maximum x-coordinate
    parameter max_y = 448   // Maximum y-coordinate
)(
    input clk,  // Clock signal for edge detection
    input signed [11:0] xsprite_origin_in,
    input signed [11:0] ysprite_origin_in,
    input up,
    input down,
    input left,
    input right,
    output reg signed [11:0] xsprite_origin_out,
    output reg signed [11:0] ysprite_origin_out
);

    reg signed [11:0] internal_xsprite_origin;
    reg signed [11:0] internal_ysprite_origin;

    // Previous state of the buttons
    reg prev_up, prev_down, prev_left, prev_right;

    initial begin
        internal_xsprite_origin = xsprite_origin_in;
        internal_ysprite_origin = ysprite_origin_in;
        prev_up = 0;
        prev_down = 0;
        prev_left = 0;
        prev_right = 0;
    end

    always @(posedge clk) begin
        // Detect rising edge (transition from not pressed to pressed)
        if (up && !prev_up) begin
            internal_ysprite_origin = internal_ysprite_origin - movement_scalar;
        end
        if (down && !prev_down) begin
            internal_ysprite_origin = internal_ysprite_origin + movement_scalar;
        end
        if (left && !prev_left) begin
            internal_xsprite_origin = internal_xsprite_origin - movement_scalar;
        end
        if (right && !prev_right) begin
            internal_xsprite_origin = internal_xsprite_origin + movement_scalar;
        end

        // Boundary checks
        if (internal_xsprite_origin > max_x) internal_xsprite_origin = max_x;
        if (internal_xsprite_origin < 0) internal_xsprite_origin = 0;
        if (internal_ysprite_origin > max_y) internal_ysprite_origin = max_y;
        if (internal_ysprite_origin < 0) internal_ysprite_origin = 0;

        // Update the previous button states
        prev_up <= up;
        prev_down <= down;
        prev_left <= left;
        prev_right <= right;

        // Update output positions
        xsprite_origin_out = internal_xsprite_origin;
        ysprite_origin_out = internal_ysprite_origin;
    end
endmodule




