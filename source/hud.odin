package main

import "core:fmt"
import raylib "vendor:raylib"

Frame_Data :: struct {
    delta_time: f32,
    fps: i32,
    map_path: string,
    wall_count: u8,
    spawner_count: u8,
    map_height: u32,
}

hud_draw :: proc(data: ^Frame_Data) {
    fps_text := fmt.caprintf("FPS: %d (dt: %.4f)", data.fps, data.delta_time, allocator = context.temp_allocator)
    info_text := fmt.caprintf("Loaded Map: %s (Walls: %d, Spawners: %d)", 
        data.map_path, data.wall_count, data.spawner_count, allocator = context.temp_allocator)
    
    raylib.DrawText(fps_text, 10, 10, 20, raylib.DARKGRAY)
    raylib.DrawText(info_text, 10, 35, 16, raylib.DARKGRAY)
    raylib.DrawText("Use WASD or Arrows to move the Blue Player dot", 10, i32(data.map_height) - 25, 16, raylib.DARKGRAY)
}
