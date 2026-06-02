package main

import "core:fmt"
import raylib "vendor:raylib"

Frame_Data :: struct {
    delta_time:     f32,
    fps:            i32,
    map_path:       string,
    wall_count:     u8,
    spawner_count:  u8,
    map_height:     u32,
    map_width:      u32,
    bullet_count:   u16,
    time_survived:  f64,
}

hud_draw :: proc(data: ^Frame_Data) {
    // 1. Top Left: FPS
    fps_text := fmt.caprintf("FPS: %d", data.fps, allocator = context.temp_allocator)
    raylib.DrawText(fps_text, 10, 10, 20, raylib.DARKGRAY)

    // 2. Under FPS: Bullets & Walls count in a vertical box
    bullets_text := fmt.caprintf("Bullets: %d", data.bullet_count, allocator = context.temp_allocator)
    walls_text := fmt.caprintf("Walls: %d", data.wall_count, allocator = context.temp_allocator)
    raylib.DrawText(bullets_text, 10, 35, 14, raylib.GRAY)
    raylib.DrawText(walls_text, 10, 52, 14, raylib.GRAY)

    // 3. Top Middle: Time Survived in MM:SS format
    total_seconds := int(data.time_survived)
    minutes := total_seconds / 60
    seconds := total_seconds % 60
    time_text := fmt.caprintf("%02d:%02d", minutes, seconds, allocator = context.temp_allocator)
    time_width := raylib.MeasureText(time_text, 22)
    time_x := i32(data.map_width) / 2 - time_width / 2
    raylib.DrawText(time_text, time_x, 10, 22, raylib.DARKGRAY)

    // 4. Top Right: Frame Time (ms per frame)
    ms_per_frame := data.delta_time * 1000.0
    ms_text := fmt.caprintf("%.2f ms", ms_per_frame, allocator = context.temp_allocator)
    ms_width := raylib.MeasureText(ms_text, 20)
    ms_x := i32(data.map_width) - ms_width - 10
    raylib.DrawText(ms_text, ms_x, 10, 20, raylib.DARKGRAY)

    // Instructions at bottom
    raylib.DrawText("Use WASD or Arrows to move the Blue Player dot", 10, i32(data.map_height) - 25, 16, raylib.DARKGRAY)
}

