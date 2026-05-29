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
    map_width:      i32,
    map_height:     i32,
    wall_thickness: f32,
    player_speed:   f32,
    player:         Player,
    
    walls:          [MAX_WALLS]Wall,
    wall_count:     int,
    spawners:       [MAX_SPAWNERS]Bullet_Spawner,
    spawner_count:  int,
    bullets:        [MAX_BULLETS]Bullet,
    bullet_count:   int,

    // Core game metrics
    time_survived:  f64,
    is_game_over:   bool,
}

// Global Level Memory Arena and Game State Pointer
g_level_arena: virtual.Arena
g_state: ^State

// Loads a map, resetting all previous map entities at zero cost
load_map :: proc(filepath: string) -> bool {
    level_allocator := virtual.arena_allocator(&g_level_arena)
    
    // 1. Wipe the entire Level Arena. This frees previous State, bullets, walls, etc.
    free_all(level_allocator)

    // 2. Allocate the State struct itself inside the clean Level Arena
    g_state = new(State, level_allocator)
    if g_state == nil {
        return false
    }

    // 3. Create a temporary static arena specifically for JSON parsing overhead
    json_arena: virtual.Arena
    err_arena := virtual.arena_init_static(&json_arena, 2 * mem.Megabyte)
    if err_arena != nil {
        return false
    }
    defer virtual.arena_destroy(&json_arena)
    json_allocator := virtual.arena_allocator(&json_arena)

    // 4. Parse the JSON using the temporary JSON arena allocator
    json_map, ok := parse_map_json(filepath, json_allocator)
    if !ok {
        return false
    }

    // 5. Transfer configurations into the permanent Level State struct
    g_state.map_width = json_map.map_width
    g_state.map_height = json_map.map_height
    g_state.wall_thickness = json_map.wall_thickness
    g_state.player_speed = json_map.player_speed

    g_state.wall_count = 0
    // Populate the permanent State walls from the JSON walls
    for jw in json_map.walls {
        if g_state.wall_count >= int(MAX_WALLS) do break
        w := Wall{
            pos1 = raylib.Vector2{jw.x1, jw.y1},
            pos2 = raylib.Vector2{jw.x2, jw.y2},
            invulnerable = jw.invulnerable,
        }
        g_state.walls[g_state.wall_count] = w
        g_state.wall_count += 1
    }

    g_state.spawner_count = 0
    // Populate the permanent State spawners from the JSON spawners
    for js in json_map.bullet_spawners {
        if g_state.spawner_count >= int(MAX_SPAWNERS) do break
        type := Bullet_Type.Bouncer
        if js.bullet_type == "bulldozer" {
            type = .Bulldozer
        } else if js.bullet_type == "constructor" {
            type = .Constructor
        }

        s := Bullet_Spawner{
            position = raylib.Vector2{js.x, js.y},
            spawn_frequency = js.spawn_frequency,
            velocity = js.velocity,
            bullet_type = type,
            spawn_timer = 0.0,
        }
        g_state.spawners[g_state.spawner_count] = s
        g_state.spawner_count += 1
    }

    // Spawn player at map center
    g_state.player.position = raylib.Vector2{f32(g_state.map_width) / 2, f32(g_state.map_height) / 2}
    g_state.player.radius = 12.0

    return true
}
