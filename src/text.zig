const std = @import("std");
const FMVideo = @import("essence.zig").FMVideo;
const Bitmap = @import("essence.zig").Bitmap;
const Face = @import("essence.zig").Face;
const print = std.debug.print;
const ft = @import("c/freetype.zig");
const maths = @import("maths.zig");

fn read_with_borders (x: i32, y: i32, w: usize, h: usize, a: ?[*]u8) i32 {
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

fn calculate_borders (out: []u8, in: Bitmap) void {
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

            out[y*(in.width+2) + x] = cval;
            M = maths.max(out[y*(in.width+2) + x], M);
        }
    }
    for (0..in.width+2) |x| {
        for (0..in.rows+2) |y| {
            const Mf: f32 = @floatFromInt(M);
            const val: f32 = @floatFromInt(out[y*(in.width+2)+x]);
            const nval: f32 = val * 255.0/Mf;
            out[y*(in.width+2)+x] = @truncate(@as(u32, @bitCast(
                        @as(i32, @intFromFloat(nval)))));
        }
    }
}

pub export fn write_text (v: *FMVideo, cg: [*c]u8, fg: [*c]u8, bg: [*c]u8, str:
    [*c]u32, len: i32, frames: i32, frame: i32, size_type: u8, face_type: u8,
    x_l: f32, x_r: f32, y_l: f32, y_t: f32) void {
    const size: i32 = v.font_size[size_type];

    const width_f: f32 = @floatFromInt(v.codec_ctx.width);
    const height_f: f32 = @floatFromInt(v.codec_ctx.height);
    const bottom_limit: i32 = @intFromFloat((1.0-y_l)/2.0*width_f);
    const allocator = v.allocator;
    
    var line_counter: u32 = 0;
    print("splitting text\n", .{});
    const newlines = splitTextInLines(v, x_l, x_r, str, len, face_type, size)
    orelse {
        print ("Out of memory (splitTextInLines)\n", .{});
        return;
    };

    print("Текст поделён на строки\n", .{});

    const p = [2]i32{
        @intFromFloat((x_l+1.0)*width_f/2.0),
        @intFromFloat((1.0-y_t)*height_f/2.0),
    };
    const cgf = [3]f32{
        @floatFromInt(@as(i32, cg[0])),
        @floatFromInt(@as(i32, cg[1])),
        @floatFromInt(@as(i32, cg[2])),
    };

    var bitmap: Bitmap = undefined;
    var glyphmap = v.glyphmaps[face_type][size_type];
    const face = v.faces[face_type];
    var err = ft.FT_Set_Char_Size(face, 0, 16*size, 300, 300);
    if (err != 0) {
        print ("couldn't set chat size\n", .{});
        return;
    }

    var old_index: ft.FT_UInt = 0;
    var pen_x: i32 = 0;
    var pen_y: i32 = 0;
    const tick = @as(f32, @floatFromInt(frames))/@as(f32, @floatFromInt(len+4));
    const tick_number: i32 = @intFromFloat(@as(f32, @floatFromInt(frame))/tick);
    var nlflag = true;

    for (0..@bitCast(@as(i64, maths.min(len, tick_number)))) |i| {
        print("frame number: {}\n", .{i});
        if (pen_y >= bottom_limit) {
            break;
        }
        print("log: 1\n", .{});
        if (i == newlines[line_counter]) {
            pen_x = 0;
            pen_y += @truncate(face.*.size.*.metrics.height >> 6);
            line_counter += 1;
            nlflag = true;
            continue;
        }
        print("log: 2\n", .{});
        const glyph_index = ft.FT_Get_Char_Index(face, str[i]);
        const bm_opt = glyphmap.get(str[i]);
        if (bm_opt == null) {
            err = ft.FT_Load_Glyph(face, glyph_index, ft.FT_LOAD_DEFAULT);
            if (err != 0) {
                print ("couldn't load a glyph\n", .{});
                std.process.exit(1);
            }
            err = ft.FT_Render_Glyph(face.*.glyph, ft.FT_RENDER_MODE_NORMAL);
            if (err != 0) {
                print ("error in rendering\n", .{});
                return;
            }
            
            print("log: 3\n", .{});

            bitmap.rows = face.*.glyph.*.bitmap.rows;
            bitmap.width = face.*.glyph.*.bitmap.width;
            bitmap.top = face.*.glyph.*.bitmap_top;
            bitmap.left = face.*.glyph.*.bitmap_left;
            if (face.*.glyph.*.bitmap.buffer == 0) {
                bitmap.data = null;
            } else {
                bitmap.data = (allocator.alloc(u8, bitmap.rows*bitmap.width)
                catch {
                    print("no memory for glyph map\n", .{});
                    std.process.exit(1);
                }).ptr;
                std.mem.copyBackwards(u8, bitmap.data.?[0..bitmap.rows*bitmap.width],
                    face.*.glyph.*.bitmap.buffer[0..bitmap.rows*bitmap.width]);
            }
            print("log: 4\n", .{});
            glyphmap.put(str[i], bitmap) catch {
                print("Could not put glyph into hashmap\n", .{});
                std.process.exit(1);
            };
            print("glyph is stored\n", .{});
        } else {
            bitmap = bm_opt.?;
        }

        if (i > 0 and !nlflag) {
            print("log: 5\n", .{});
            var kerning: ft.FT_Vector = undefined;
            err = ft.FT_Get_Kerning(face, old_index, glyph_index,
                ft.FT_KERNING_DEFAULT, &kerning);
            if (err != 0) {
                print ("error in defining kerning\n", .{});
                return;
            }
            pen_x += @truncate(kerning.x >> 6);
        }


        print("log: 6\n", .{});
        const linesize = v.frame.linesize;
        if (bitmap.data == null) {
            pen_x += @as(i32, @truncate(face.*.glyph.*.advance.x>>6));
            pen_y += @as(i32, @truncate(face.*.glyph.*.advance.y>>6));
            old_index = glyph_index;
            continue;
        }
        if (i < tick_number-4) {
            // showing letters
            print("log: 7\n", .{});
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
                    print("log: 8\n", .{});
                    const yr: i32 = @intFromFloat(cgf[0]*m + bgf[0]*(1.0-m));
                    const ur: i32 = @intFromFloat(cgf[1]*m + bgf[1]*(1.0-m));
                    const vr: i32 = @intFromFloat(cgf[2]*m + bgf[2]*(1.0-m));
                    v.frame.data[0][pos[0]] = @truncate(@as(u32, @bitCast(yr)));
                    if ((x&1)==0 and (y&1) == 0) {
                        v.frame.data[1][pos[1]] = @truncate(@as(u32,
                                @bitCast(ur)));
                        v.frame.data[2][pos[2]] = @truncate(@as(u32,
                                @bitCast(vr)));
                    }
                }
            }
        } else if (i > tick_number-4 and i <= tick_number) {
            // print("case 1\n", .{});
            //calculating borders
            const borders_size: usize = (bitmap.width+2)*(bitmap.rows+2);
            const borders: []u8 = allocator.alloc(u8, borders_size) catch {
                print ("Out of memory for borders\n", .{});
                return;
            };
            calculate_borders (borders, bitmap);
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
                        v.frame.data[0][pos[0]] = @truncate(@as(u32, @bitCast(
                                    yr)));
                        if ((x&1)==0 and (y&1) == 0) {
                            v.frame.data[1][pos[1]] = @truncate(@as(u32, 
                                    @bitCast(ur)));
                            v.frame.data[2][pos[2]] = @truncate(@as(u32,
                                    @bitCast(vr)));
                        }
                    }
                }
            }
            allocator.free(borders);
        } else if (i == tick_number-4) {
            const borders_size = (bitmap.width+2)*(bitmap.rows+2);
            const borders = allocator.alloc(u8, borders_size) catch {
                print ("Out of memory for borders\n", .{});
                return;
            };
            calculate_borders (borders, bitmap);
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

                    const bmtop: i32 = face.*.glyph.*.bitmap_top;
                    const bmleft: i32 = face.*.glyph.*.bitmap_left;
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

                    v.frame.data[0][pos[0]] = @truncate(@as(u32, @bitCast(yr)));
                    if ((x&1)==0 and (y&1) == 0) {
                        v.frame.data[1][pos[1]] = @truncate(@as(u32, @bitCast(
                                    ur)));
                        v.frame.data[2][pos[2]] = @truncate(@as(u32, @bitCast(
                                    vr)));
                    }
                }
            }
            allocator.free(borders);
        }
        pen_x += @as(i32, @truncate(face.*.glyph.*.advance.x>>6));
        pen_y += @as(i32, @truncate(face.*.glyph.*.advance.y>>6));
        old_index = glyph_index;
        nlflag = false;
    }
}

// Разбить текст на строки
// так как возварщается поинтер, то я могу возвращать зиговские конструкции
fn splitTextInLines (v: *FMVideo, x_l: f32, x_r: f32, 
    str: [*c]u32, len: i32, face_type: u8, size: i32) ?[]u32 {
    const window_width: i32 = @intFromFloat((x_r-x_l)*@as(f32,
            @floatFromInt(v.codec_ctx.width))/2.0);
    const allocator = v.allocator;

    var last_pos: u32 = 0;
    var retval = allocator.alloc(u32, 8) catch {
        print ("can't allocate text spliter", .{});
        return null;
    };

    const face = v.faces[face_type];

    var err = ft.FT_Set_Char_Size(face, 0, 16*size, 300, 300);
    if (err != 0) {
        print ("couldn't set chat size\n", .{});
        allocator.free(retval);
        return null;
    }

    // preparing for maths
    var old_index: ft.FT_UInt = 0;
    var pen_x: i32 = 0;
    var i: u32 = 0;
    var last_space: u32 = 0;
    var new_line: bool = true;
    while (i < len) : (i += 1) {
        // print ("{}\n", .{i});
        if (str[i] == 32) {
            // print ("?\n", .{});
            last_space = i;
        }
        // loading glyph
        const glyph_index = ft.FT_Get_Char_Index(face, str[i]);
        // adding kerning if not on new line
        if (!new_line) {
            var kerning: ft.FT_Vector = undefined;
            err = ft.FT_Get_Kerning(face, old_index, glyph_index, ft.FT_KERNING_DEFAULT, &kerning);
            if (err != 0) {
                print ("error in defining kerning\n", .{});
                allocator.free(retval);
                return null;
            }
            pen_x += @truncate(kerning.x >> 6);
        }
        new_line = false;
        if (pen_x >= window_width) {
            if (last_pos == retval.len) {
                retval = allocator.realloc(retval, retval.len+8) catch {
                    print ("could not relocate memory", .{});
                    allocator.free(retval);
                    return null;
                };
            }
            retval[last_pos] = last_space;
            last_pos += 1;
            i = last_space + 1;
            new_line = true;
            pen_x = 0;
        }
        old_index = glyph_index;
        pen_x += @truncate(face.*.glyph.*.advance.x >> 6); 
    }
    return retval;
}
