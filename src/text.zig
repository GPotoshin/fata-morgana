const std = @import("std");
const FMVideo = @import("essence.zig").FMVideo;
const Bitmap = @import("essence.zig").Bitmap;
const Face = @import("essence.zig").Face;
const print = std.debug.print;
const ft = @import("c/freetype.zig");
const maths = @import("maths.zig");
var gpa = &@import("essence.zig").gpa;

fn read_with_borders (x: i32, y: i32, w: usize, h: usize, a: ?[]u8) i32 {
    if (x < 0 or y < 0 or x >= w or y >= h or a == null) {
        return 0;
    } else {
        const x_u: usize = @as(u32, @bitCast(x));
        const y_u: usize = @as(u32, @bitCast(y));
        return @bitCast(@as(u32, a.?[y_u*w + x_u]));
    }
}

fn print_box (a: []u8, w: usize, h: usize) void {
    for (0..w) |x| {
        for (0..h) |y| {
            print ("{} ", .{a[y*w+x]});
        }
        print ("\n", .{});
    }
}

fn calculate_borders (in: Bitmap) void {
    var M: i32 = 0;
    for (0..in.width+2) |x| {
        for (0..in.rows+2) |y| {
            const x_i: i32 = @bitCast(@as(u32, @truncate(x)));
            const y_i: i32 = @bitCast(@as(u32, @truncate(y)));
            var m1: f32 = 0.0;
            var m2: f32 = 0.0;
            m1 += @as(f32, @floatFromInt(read_with_borders
                    (x_i-2, y_i-2, in.width, in.rows, in.data)));
            m1 += 2.0*@as(f32, @floatFromInt(read_with_borders
                    (x_i-1, y_i-2, in.width, in.rows, in.data)));
            m1 += @as(f32, @floatFromInt(read_with_borders
                    (x_i,   y_i-2, in.width, in.rows, in.data)));
            m1 -= @as(f32, @floatFromInt(read_with_borders
                    (x_i-2, y_i, in.width, in.rows, in.data)));
            m1 -= 2.0*@as(f32, @floatFromInt(read_with_borders
                    (x_i-1, y_i, in.width, in.rows, in.data)));
            m1 -= @as(f32, @floatFromInt(read_with_borders
                    (x_i,   y_i, in.width, in.rows, in.data)));
            m2 += @as(f32, @floatFromInt(read_with_borders
                    (x_i-2, y_i-2, in.width, in.rows, in.data)));
            m2 += 2.0*@as(f32, @floatFromInt(read_with_borders
                    (x_i-2, y_i-1, in.width, in.rows, in.data)));
            m2 += @as(f32, @floatFromInt(read_with_borders
                    (x_i-2, y_i,   in.width, in.rows, in.data)));
            m2 -= @as(f32, @floatFromInt(read_with_borders
                    (x_i, y_i-2, in.width, in.rows, in.data)));
            m2 -= 2.0*@as(f32, @floatFromInt(read_with_borders
                    (x_i, y_i-1, in.width, in.rows, in.data)));
            m2 -= @as(f32, @floatFromInt(read_with_borders
                    (x_i, y_i,   in.width, in.rows, in.data)));

            const fval: f32 = std.math.hypot(m1/8.0, m2/8.0)/1.4142136;
            const ival: i32 = @intFromFloat(fval);
            const uval: u32 = @bitCast(ival);
            const cval: u8  = @truncate(uval);

            in.borders.?[y*(in.width+2) + x] = cval;
            M = @max(in.borders.?[y*(in.width+2) + x], M);
        }
    }
    for (0..in.width+2) |x| {
        for (0..in.rows+2) |y| {
            const Mf: f32 = @floatFromInt(M);
            const val: f32 = @floatFromInt(in.borders.?[y*(in.width+2)+x]);
            const nval: f32 = val * 255.0/Mf;
            in.borders.?[y*(in.width+2)+x] = @truncate(@as(u32, @bitCast(
                        @as(i32, @intFromFloat(nval)))));
        }
    }
}

fn load_glyph(allocator: std.mem.Allocator, face: ft.FT_Face, key: u32, glyphmap: *std.AutoHashMap(u32, Bitmap)) void {
    var bitmap: Bitmap = undefined;
    const glyph_index = ft.FT_Get_Char_Index(face, key);
    var err = ft.FT_Load_Glyph(face, glyph_index, ft.FT_LOAD_DEFAULT);
    if (err != 0) {
        print ("couldn't load a glyph\n", .{});
        std.process.exit(1);
    }
    err = ft.FT_Render_Glyph(face.*.glyph, ft.FT_RENDER_MODE_NORMAL);
    if (err != 0) {
        print ("error in rendering\n", .{});
        return;
    }


    bitmap.rows = face.*.glyph.*.bitmap.rows;
    bitmap.width = face.*.glyph.*.bitmap.width;
    bitmap.top = face.*.glyph.*.bitmap_top;
    bitmap.left = face.*.glyph.*.bitmap_left;
    bitmap.advance_x = face.*.glyph.*.advance.x;
    bitmap.advance_y = face.*.glyph.*.advance.y;
    if (face.*.glyph.*.bitmap.buffer == 0) {
        bitmap.data = null;
        bitmap.borders = null;
    } else {
        bitmap.data = allocator.alloc(u8, bitmap.rows*bitmap.width)
            catch {
                print("no memory for glyph map\n", .{});
                std.process.exit(1);
            };
        std.mem.copyBackwards(u8, bitmap.data.?[0..bitmap.rows*bitmap.width],
            face.*.glyph.*.bitmap.buffer[0..bitmap.rows*bitmap.width]);
        const borders_size = (bitmap.width+2)*(bitmap.rows+2);
        bitmap.borders = allocator.alloc(u8, borders_size) catch {
            print ("Out of memory for borders\n", .{});
            std.process.exit(1);
        };
        calculate_borders (bitmap);
    }
    glyphmap.put(key, bitmap) catch {
        print("Could not put glyph into hashmap\n", .{});
        std.process.exit(1);
    };

}


/// Render all glyphs from string to a bitmap corresponding to the right face
/// family and right size.
pub export fn render_glyphs (opt_state: ?*FMVideo, text: [*c]const u32, len: u32,
    size_type: u8, face_type: u8) void {

    const state = opt_state.?;

    const allocator = state.scene_arena.allocator();
    const size: u32 = state.font_size[size_type];
    var glyphmap = &state.glyphmaps[size_type][face_type];
    const face = state.faces[face_type];
    const err = ft.FT_Set_Char_Size(face, 0, size, 300, 300);
    if (err != 0) {
        print ("couldn't set char size\n", .{});
        return;
    }

    for (0..len) |i| {
        const bm_opt = glyphmap.get(text[i]);
        if (bm_opt == null) {
            load_glyph(allocator, face, text[i], glyphmap);
        }
    }
    load_glyph(allocator, face, '\n', glyphmap);
}

pub export fn write_text(v: ?*FMVideo, cg: [*c]const u8, fg: [*c]const u8, bg: [*c]const u8, str:
    [*c]const u32, len: i32, frames: u32, frame: u32, size_type: u8, face_type: u8,
    x_l: f32, x_r: f32, y_l: f32, y_t: f32) void {
    var state = v.?;
    const size: u32 = state.font_size[size_type];
    _ = x_r;

    const glyphmap = state.glyphmaps[size_type][face_type];
    const face = state.faces[face_type];

    // remove that dependecy one day
    var err = ft.FT_Set_Char_Size(face, 0, size, 300, 300);
    if (err != 0) {
        print ("couldn't set chat size\n", .{});
        std.process.exit(1);
    }

    const width_f: f32 = @floatFromInt(state.codec_ctx.width);
    const height_f: f32 = @floatFromInt(state.codec_ctx.height);
    const bottom_limit: i32 = @intFromFloat((1.0-y_l)/2.0*width_f);
    
    const p = [2]i32{
        @intFromFloat((x_l+1.0)*width_f/2.0),
        @intFromFloat((1.0-y_t)*height_f/2.0),
    };
    const cgf = [3]f32{
        @floatFromInt(@as(i32, cg[0])),
        @floatFromInt(@as(i32, cg[1])),
        @floatFromInt(@as(i32, cg[2])),
    };

    var old_index: ft.FT_UInt = 0;
    var pen_x: i32 = 0;
    var pen_y: i32 = 0;
    const tick = @as(f32, @floatFromInt(frames))/@as(f32, @floatFromInt(len+4));
    const tick_number: i32 = @intFromFloat(@as(f32, @floatFromInt(frame))/tick);
    var nlflag = true;

    for (0..@bitCast(@as(i64, @min(len, tick_number)))) |i| {
        if (pen_y >= bottom_limit) {
            break;
        }

        // all the values must have been precomputed

        const bitmap = glyphmap.get(str[i]) orelse unreachable;
        if (str[i] == '\n') {
            pen_x = 0;
            pen_y += @truncate(face.*.size.*.metrics.height >> 6); // @Remark: it used to be metrix.height, so
                                                       // new lines may be not working correctly
            nlflag = true;
            continue;
        }

        const glyph_index = ft.FT_Get_Char_Index(face, str[i]);

        if (i > 0 and !nlflag) {
            var kerning: ft.FT_Vector = undefined;
            err = ft.FT_Get_Kerning(face, old_index, glyph_index, // can't the kerning be precomputed?
                ft.FT_KERNING_DEFAULT, &kerning);
            if (err != 0) {
                print ("error in defining kerning\n", .{});
                return;
            }
            pen_x += @truncate(kerning.x >> 6);
        }

        const linesize = state.frame.linesize;
        if (bitmap.data == null) {
            pen_x += @as(i32, @truncate(bitmap.advance_x>>6));
            pen_y += @as(i32, @truncate(bitmap.advance_y>>6));
            old_index = glyph_index;
            continue;
        }
        const borders = bitmap.borders.?;
        if (i < tick_number-4) {
            // showing letter
            for (0..bitmap.width) |x| {
                for (0..bitmap.rows) |y| {
                    const m: f32 = @as(f32,
                        @floatFromInt(bitmap.data.?[y*bitmap.width + x]))/255.0;

                    const x_i: i32 = @bitCast(@as(u32, @truncate(x)));
                    const y_i: i32 = @bitCast(@as(u32, @truncate(y)));
                    const bmtop: i32 = bitmap.top;
                    const bmleft: i32 = bitmap.left;
                    const linesize_0: i32 = linesize[0]; 
                    const linesize_1: i32 = linesize[1]; 
                    const linesize_2: i32 = linesize[2]; 

                    const pos_0: i32 = 
                        (y_i+p[1]+pen_y-bmtop) *
                        linesize_0 + (x_i+p[0]+pen_x+bmleft);
                    const pos_1: i32 = 
                        @divFloor(y_i+p[1]+pen_y-bmtop,2) *
                        linesize_1 + @divFloor(x_i+p[0]+pen_x+bmleft,2);
                    const pos_2: i32 =
                        @divFloor(y_i+p[1]+pen_y-bmtop,2) *
                        linesize_2 + @divFloor(x_i+p[0]+pen_x+bmleft,2);

                    const pos = [3]usize{
                        @as(u32, @bitCast(pos_0)),
                        @as(u32, @bitCast(pos_1)),
                        @as(u32, @bitCast(pos_2)),
                    };

                    const bgf = [3]f32{
                        @floatFromInt(@as(i32, bg[0])),
                        @floatFromInt(@as(i32, bg[1])),
                        @floatFromInt(@as(i32, bg[2])),
                    };
                    const yr: i32 = @intFromFloat(cgf[0]*m + bgf[0]*(1.0-m));
                    const ur: i32 = @intFromFloat(cgf[1]*m + bgf[1]*(1.0-m));
                    const vr: i32 = @intFromFloat(cgf[2]*m + bgf[2]*(1.0-m));
                    state.frame.data[0][pos[0]] = @truncate(@as(u32, @bitCast(yr)));
                    if ((x&1)==0 and (y&1) == 0) {
                        state.frame.data[1][pos[1]] = @truncate(@as(u32,
                                @bitCast(ur)));
                        state.frame.data[2][pos[2]] = @truncate(@as(u32,
                                @bitCast(vr)));
                    }
                }
            }
        } else if (i > tick_number-4 and i <= tick_number) {
            // print("case 1\n", .{});
            //calculating borders
            for (0..bitmap.width+2) |x| {
                for (0..bitmap.rows+2) |y| {
                    const angle_coef: f32 = (@as(f32, @floatFromInt(frame)) -
                        @as(f32, @floatFromInt(@as(i32, @bitCast(@as(u32,
                        @truncate(i))))))*tick)/(4.0*tick);
                    const m: f32 = @as(f32, @floatFromInt(@as(i32,
                        borders[y*(bitmap.width+2) + x])))/255.0;

                    const x_i: i32 = @bitCast(@as(u32, @truncate(x)));
                    const y_i: i32 = @bitCast(@as(u32, @truncate(y)));
                    const bmtop: i32 = bitmap.top;
                    const bmleft: i32 = bitmap.left;
                    const linesize_0: i32 = linesize[0]; 
                    const linesize_1: i32 = linesize[1]; 
                    const linesize_2: i32 = linesize[2]; 

                    const pos_0: i32 = 
                        (y_i+p[1]+pen_y-bmtop) *
                        linesize_0 + (x_i+p[0]+pen_x+bmleft);
                   const pos_1: i32 = 
                        @divFloor(y_i+p[1]+pen_y-bmtop,2) *
                        linesize_1 + @divFloor(x_i+p[0]+pen_x+bmleft,2);
                   const pos_2: i32 =
                        @divFloor(y_i+p[1]+pen_y-bmtop,2) *
                        linesize_2 + @divFloor(x_i+p[0]+pen_x+bmleft,2);

                    const pos = [3]usize{
                        @as(u32, @bitCast(pos_0)),
                        @as(u32, @bitCast(pos_1)),
                        @as(u32, @bitCast(pos_2)),
                    };

                    const bgf = [3]f32{
                        @floatFromInt(@as(i32, bg[0])),
                        @floatFromInt(@as(i32, bg[1])),
                        @floatFromInt(@as(i32, bg[2])),
                    };
                    const fgf = [3]f32{
                        @floatFromInt(@as(i32, fg[0])),
                        @floatFromInt(@as(i32, fg[1])),
                        @floatFromInt(@as(i32, fg[2])),
                    };
                    const yr: i32 = @intFromFloat(fgf[0]*m + bgf[0]*(1.0-m));
                    const ur: i32 = @intFromFloat(fgf[1]*m + bgf[1]*(1.0-m));
                    const vr: i32 = @intFromFloat(fgf[2]*m + bgf[2]*(1.0-m));
                    
                    const xf: f32 = @floatFromInt(@as(i32, @bitCast(@as(u32, 
                        @truncate(x)))));
                    const yf: f32 = @floatFromInt(@as(i32, @bitCast(@as(u32,
                        @truncate(y)))));
                    if (std.math.pi/2.0-maths.vector_angle(xf, yf) <= std.math.pi/2.0
                        * angle_coef) {
                        state.frame.data[0][pos[0]] = @truncate(@as(u32, @bitCast(
                                    yr)));
                        if ((x&1)==0 and (y&1) == 0) {
                            state.frame.data[1][pos[1]] = @truncate(@as(u32, 
                                    @bitCast(ur)));
                            state.frame.data[2][pos[2]] = @truncate(@as(u32,
                                    @bitCast(vr)));
                        }
                    }
                }
            }
        } else if (i == tick_number-4) {
            for (0..bitmap.width+2) |x| {
                for (0..bitmap.rows+2) |y| {
                    const x_i: i32 = @bitCast(@as(u32, @truncate(x)));
                    const y_i: i32 = @bitCast(@as(u32, @truncate(y)));

                    const frame_f: f32 = @floatFromInt(frame);
                    const tick_number_f: f32 = @floatFromInt(tick_number);
                    const buf_val_f: f32 = @floatFromInt(read_with_borders(x_i-1,
                            y_i-1, bitmap.width, bitmap.rows, bitmap.data));
                    const borval: f32 = @floatFromInt(borders[y*(bitmap.width+2)+x]);

                    const filling_to_border: f32 = (frame_f-tick_number_f*tick) /
                        tick;
                    const filling_coef: f32 = filling_to_border*buf_val_f/255.0;
                    const border_coef: f32 = (1.0 - filling_to_border) * borval
                        / 255.0;
                    const bg_coef: f32 = 1.0 - filling_coef - border_coef;

                    const bmtop: i32 = bitmap.top;
                    const bmleft: i32 = bitmap.left;
                    const linesize_0: i32 = linesize[0]; 
                    const linesize_1: i32 = linesize[1]; 
                    const linesize_2: i32 = linesize[2]; 

                    const pos_0: i32 = 
                        (y_i+p[1]+pen_y-bmtop) *
                        linesize_0 + (x_i+p[0]+pen_x+bmleft);
                   const pos_1: i32 = 
                        @divFloor(y_i+p[1]+pen_y-bmtop,2) *
                        linesize_1 + @divFloor(x_i+p[0]+pen_x+bmleft,2);
                   const pos_2: i32 =
                        @divFloor(y_i+p[1]+pen_y-bmtop,2) *
                        linesize_2 + @divFloor(x_i+p[0]+pen_x+bmleft,2);

                    const pos = [3]usize{
                        @as(u32, @bitCast(pos_0)),
                        @as(u32, @bitCast(pos_1)),
                        @as(u32, @bitCast(pos_2)),
                    };

                    const bgf = [3]f32{
                        @floatFromInt(@as(i32, bg[0])),
                        @floatFromInt(@as(i32, bg[1])),
                        @floatFromInt(@as(i32, bg[2])),
                    };
                    const fgf = [3]f32{
                        @floatFromInt(@as(i32, fg[0])),
                        @floatFromInt(@as(i32, fg[1])),
                        @floatFromInt(@as(i32, fg[2])),
                    };
                    const yr: i32 = @intFromFloat(cgf[0]*filling_coef +
                        fgf[0]*border_coef + bgf[0]*bg_coef);
                    const ur: i32 = @intFromFloat(cgf[1]*filling_coef +
                        fgf[1]*border_coef + bgf[1]*bg_coef);
                    const vr: i32 = @intFromFloat(cgf[2]*filling_coef +
                        fgf[2]*border_coef + bgf[2]*bg_coef);

                    state.frame.data[0][pos[0]] = @truncate(@as(u32, @bitCast(yr)));
                    if ((x&1)==0 and (y&1) == 0) {
                        state.frame.data[1][pos[1]] = @truncate(@as(u32, @bitCast(
                                    ur)));
                        state.frame.data[2][pos[2]] = @truncate(@as(u32, @bitCast(
                                    vr)));
                    }
                }
            }
        }
        pen_x += @as(i32, @truncate(bitmap.advance_x>>6));
        pen_y += @as(i32, @truncate(bitmap.advance_y>>6));
        old_index = glyph_index;
        nlflag = false;
    }
}

pub export fn add_line_splits(v: ?*FMVideo, x_l: f32, x_r: f32, 
    str: [*]u32, len: i32, size_type: u8, face_type: u8) void {
    const state = v.?;
    const window_width: i32 = @intFromFloat((x_r-x_l)*@as(f32,
            @floatFromInt(state.codec_ctx.width))/2.0);

    const face = state.faces[face_type];
    const size = state.font_size[size_type];
    const map = state.glyphmaps[size_type][face_type];

    var err = ft.FT_Set_Char_Size(face, 0, size, 300, 300);
    if (err != 0) {
        print ("couldn't set chat size\n", .{});
        std.process.exit(1);
    }

    var old_index: ft.FT_UInt = 0;
    var pen_x: i32 = 0;
    var i: u32 = 0;
    var last_space: u32 = 0;
    var new_line: bool = true;
    var bitmap: Bitmap = undefined;
    print("window_width: {}\n", .{window_width});
    while (i < len) : (i += 1) {
        bitmap = map.get(str[i]) orelse {
            print("failed at {} with code {}\n", .{i, str[i]});
            unreachable;
        };
        if (str[i] == 32) {
            last_space = i;
        }
        const glyph_index = ft.FT_Get_Char_Index(face, str[i]);
        if (!new_line) {
            var kerning: ft.FT_Vector = undefined;
            err = ft.FT_Get_Kerning(face, old_index, glyph_index, ft.FT_KERNING_DEFAULT, &kerning);
            if (err != 0) {
                print ("error in defining kerning\n", .{});
                std.process.exit(1);
            }
            pen_x += @truncate(kerning.x >> 6);
        }
        new_line = false;
        if (pen_x >= window_width) {
            str[last_space] = '\n';
            i = last_space + 1;
            new_line = true;
            pen_x = 0;
        }
        old_index = glyph_index;
        pen_x += @truncate(bitmap.advance_x >> 6); 
    }
}

