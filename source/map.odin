package main

import "core:mem"
import "core:mem/virtual"
import rl "vendor:raylib"

Bullet_Type :: enum {
    Bouncer,
    Bulldozer,
    Constructor,
}

Bullet :: struct {
    pos:    rl.Vector2,
    vel:    rl.Vector2,
    radius: f32,
    type:   Bullet_Type,
}

Wall :: struct {
    p1:           rl.Vector2,
    p2:           rl.Vector2,
    invulnerable: bool,
}

Bullet_Spawner :: struct {
    pos:             rl.Vector2,
    spawn_frequency: f32,
    velocity:        f32,
    bullet_type:     Bullet_Type,
    spawn_timer:     f32,
}

Player :: struct {
    pos:    rl.Vector2,
    radius: f32,
}

State :: struct {
    map_width:      i32,
    map_height:     i32,
    wall_thickness: f32,
    player_speed:   f32,
    player:         Player,
    bullets:        [dynamic]Bullet,
    walls:          [dynamic]Wall,
    spawners:       [dynamic]Bullet_Spawner,
    
    // Core game metrics
    time_survived:  f64,
    is_game_over:   bool,
}

// Global Level Memory Arena and Game State Pointer
g_level_arena: virtual.Arena
g_state: ^State

// Initializes the growing virtual memory arena for level play sessions
init_memory :: proc() {
    err := virtual.arena_init_growing(&g_level_arena)
    assert(err == nil, "Failed to initialize Level virtual memory arena")
}

// Fully decommits and destroys the Level memory arena on shutdown
cleanup_memory :: proc() {
    virtual.arena_destroy(&g_level_arena)
}

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

    // 3. Create a temporary growing arena specifically for JSON parsing overhead
    json_arena: virtual.Arena
    err_arena := virtual.arena_init_growing(&json_arena)
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

    // Allocate dynamic arrays using the Level Arena allocator
    g_state.walls = make([dynamic]Wall, level_allocator)
    g_state.spawners = make([dynamic]Bullet_Spawner, level_allocator)
    g_state.bullets = make([dynamic]Bullet, level_allocator)

    // Populate the permanent State walls from the JSON walls
    for jw in json_map.walls {
        w := Wall{
            p1 = rl.Vector2{jw.x1, jw.y1},
            p2 = rl.Vector2{jw.x2, jw.y2},
            invulnerable = jw.invulnerable,
        }
        append(&g_state.walls, w)
    }

    // Populate the permanent State spawners from the JSON spawners
    for js in json_map.bullet_spawners {
        type := Bullet_Type.Bouncer
        if js.bullet_type == "bulldozer" {
            type = .Bulldozer
        } else if js.bullet_type == "constructor" {
            type = .Constructor
        }

        s := Bullet_Spawner{
            pos = rl.Vector2{js.x, js.y},
            spawn_frequency = js.spawn_frequency,
            velocity = js.velocity,
            bullet_type = type,
            spawn_timer = 0.0,
        }
        append(&g_state.spawners, s)
    }

    // Spawn player at map center
    g_state.player.pos = rl.Vector2{f32(g_state.map_width) / 2, f32(g_state.map_height) / 2}
    g_state.player.radius = 12.0

    return true
}
