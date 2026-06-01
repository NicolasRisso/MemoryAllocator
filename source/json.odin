package main

import "core:encoding/json"
import "core:os"
import "core:fmt"
import "core:mem"

JSON_Wall :: struct {
    x1, y1, x2, y2: f32,
    invulnerable: bool,
}

JSON_Bullet_Spawner :: struct {
    x, y: f32,
    spawn_frequency: f32,
    velocity: f32,
    bullet_type: string,
}

JSON_Map :: struct {
    map_width: u32,
    map_height: u32,
    wall_thickness: f32,
    player_speed: f32,
    walls: []JSON_Wall,
    bullet_spawners: []JSON_Bullet_Spawner,
}

parse_map_json :: proc(filepath: string, allocator: mem.Allocator) -> (JSON_Map, bool) {
    // Read the entire file using the provided allocator
    raw_data, err_reading := os.read_entire_file(filepath, allocator)
    if err_reading != nil {
        fmt.eprintf("Error: Failed to read map file from path: %s (error: %v)\n", filepath, err_reading)
        return {}, false
    }

    // Unmarshal JSON into the target struct using the allocator
    map_data: JSON_Map
    err_unmarshal := json.unmarshal(raw_data, &map_data, allocator = allocator)
    if err_unmarshal != nil {
        fmt.eprintf("Error: Failed to unmarshal JSON: %v\n", err_unmarshal)
        return {}, false
    }

    return map_data, true
}
