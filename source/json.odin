package main

import "core:encoding/json"
import "core:os"
import "core:fmt"
import "core:mem"

JSON_Wall :: struct {
    x1:           f32,
    y1:           f32,
    x2:           f32,
    y2:           f32,
    invulnerable: bool,
}

JSON_Bullet_Spawner :: struct {
    x:               f32,
    y:               f32,
    spawn_frequency: f32,
    velocity:        f32,
    bullet_type:     string,
}

JSON_Map :: struct {
    map_width:       i32,
    map_height:      i32,
    wall_thickness:  f32,
    player_speed:    f32,
    walls:           []JSON_Wall,
    bullet_spawners: []JSON_Bullet_Spawner,
}

// Parses a JSON map file using the specified allocator for all allocations
parse_map_json :: proc(filepath: string, allocator: mem.Allocator) -> (JSON_Map, bool) {
    // Read the entire file using the provided allocator
    data, err := os.read_entire_file(filepath, allocator)
    if err != nil {
        fmt.eprintf("Error: Failed to read map file from path: %s (error: %v)\n", filepath, err)
        return {}, false
    }

    // Unmarshal JSON into the target struct using the allocator
    map_data: JSON_Map
    err_unmarshal := json.unmarshal(data, &map_data, allocator = allocator)
    if err_unmarshal != nil {
        fmt.eprintf("Error: Failed to unmarshal JSON: %v\n", err_unmarshal)
        return {}, false
    }

    return map_data, true
}
