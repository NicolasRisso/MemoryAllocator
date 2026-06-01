package main

import "core:mem"
import "core:mem/virtual"
import raylib "vendor:raylib"

MAX_WALLS: u8 : 255
MAX_SPAWNERS: u8 : 16 
MAX_BULLETS: u16 : 1024

Bullet_Type :: enum {
    Bouncer,
    Bulldozer,
    Constructor,
}

Bullet :: struct {
    position: raylib.Vector2,
    velocity: raylib.Vector2,
    radius: f32,
    type: Bullet_Type,
}

Wall :: struct {
    pos1: raylib.Vector2,
    pos2: raylib.Vector2,
    invulnerable: bool,
}

Bullet_Spawner :: struct {
    position: raylib.Vector2,
    spawn_frequency: f32,
    velocity: f32,
    bullet_type: Bullet_Type,
    spawn_timer: f32,
}

Player :: struct {
    position: raylib.Vector2,
    radius: f32,
}

Level :: struct {
    walls: [MAX_WALLS]Wall,
    spawners: [MAX_SPAWNERS]Bullet_Spawner,
    bulelts: [MAX_BULLETS]Bullet
}

State :: struct {
    map_width:      u32,
    map_height:     u32,
    wall_thickness: f32,
    player_speed:   f32,
    player:         Player,
    
    walls:          [MAX_WALLS]Wall,
    wall_count:     u8,
    spawners:       [MAX_SPAWNERS]Bullet_Spawner,
    spawner_count:  u8,
    bullets:        [MAX_BULLETS]Bullet,
    bullet_count:   u16,

    // Core game metrics
    time_survived:  f64,
    is_game_over:   bool,
}

// Global Level Memory Arena and Game State Pointer
g_level_arena: virtual.Arena
g_state: ^State

// Loads a map, resetting all previous map entities at zero cost
load_level :: proc(filepath: string) -> bool {
    
    // 1. Make static arena and allocate the state
    level_allocator := virtual.arena_allocator(&g_level_arena)
    free_all(level_allocator)
    g_state = new(State, level_allocator)
    if g_state == nil do return false

    // 2. Json Growing Arena
    json_arena: virtual.Arena
    err_arena := virtual.arena_init_growing(&json_arena)
    if err_arena != nil do return false
    json_allocator := virtual.arena_allocator(&json_arena)

    // 3. Clears json arena when method is over
    defer virtual.arena_destroy(&json_arena)

    // 4. Parse the JSON using the temporary JSON arena allocator
    json_map, json_result := parse_map_json(filepath, json_allocator)
    if !json_result do return false

    // 5. Transfer configurations into the permanent Level State struct
    g_state.map_width = json_map.map_width
    g_state.map_height = json_map.map_height
    g_state.wall_thickness = json_map.wall_thickness
    g_state.player_speed = json_map.player_speed

    // Populate the permanent State walls from the JSON walls
    g_state.wall_count = 0
    for json_wall in json_map.walls {
        if g_state.wall_count >= MAX_WALLS do break
        wall := Wall{
            pos1 = json_wall.pos1,
            pos2 = json_wall.pos1,
            invulnerable = json_wall.invulnerable,
        }
        g_state.walls[g_state.wall_count] = wall
        g_state.wall_count += 1
    }

    // Populate the permanent State spawners from the JSON spawners
    g_state.spawner_count = 0
    for json_spawner in json_map.bullet_spawners {
        if g_state.spawner_count >= MAX_SPAWNERS do break
        type := Bullet_Type.Bouncer
        if json_spawner.bullet_type == "bulldozer" {
            type = .Bulldozer
        } else if json_spawner.bullet_type == "constructor" {
            type = .Constructor
        }

        spawner := Bullet_Spawner{
            position = json_spawner.pos,
            spawn_frequency = json_spawner.spawn_frequency,
            velocity = json_spawner.velocity,
            bullet_type = type,
            spawn_timer = 0.0,
        }
        g_state.spawners[g_state.spawner_count] = spawner
        g_state.spawner_count += 1
    }

    // Spawn player at map center
    g_state.player.position = raylib.Vector2{f32(g_state.map_width) / 2, f32(g_state.map_height) / 2}
    g_state.player.radius = 12.0

    return true
}
