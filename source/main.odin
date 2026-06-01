package main

import "core:fmt"
import "core:mem"
import "core:mem/virtual"

import raylib "vendor:raylib"

// Palette Colors
color_bg :: raylib.Color{225, 225, 225, 255} // Light Gray
color_wall :: raylib.Color{80, 80, 80, 255}    // Dark Gray
color_spawner :: raylib.Color{230, 45, 45, 255}   // Red
color_player :: raylib.Color{40, 80, 180, 255}   // Blue

main :: proc() {
    // 1. Initialize Level Allocator (Arena)
    // We use a static virtual arena for the level. It gets cleared on map load.
    err_level := virtual.arena_init_static(&g_level_arena, size_of(State) + 64)
    if err_level != nil {
        fmt.eprintfln("Fatal Error: Failed to initialize level arena")
        return
    }
    defer virtual.arena_destroy(&g_level_arena)

    // 2. Load the initial map
    map_path : string = "maps/default.json"
    if !load_level(map_path) {
        fmt.println("Fatal Error: Failed to load map:", map_path)
        return
    }

    // 3. Initialize Raylib window based on JSON map specifications
    raylib.InitWindow(i32(g_state.map_width), i32(g_state.map_height), "Bullet Dodge Arcade Game")
    defer raylib.CloseWindow()

    raylib.SetTargetFPS(60)

    fmt.println("Map loaded successfully!")
    fmt.printf("Resolution: %dx%d, Player Speed: %.1f, Wall Thickness: %.1f\n", g_state.map_width, g_state.map_height, g_state.player_speed, g_state.wall_thickness)

    // Main Game Loop
    for !raylib.WindowShouldClose() {
        frame_data := new(Frame_Data, context.temp_allocator)
        frame_data.delta_time = raylib.GetFrameTime()
        frame_data.fps = raylib.GetFPS()
        frame_data.map_path = map_path
        frame_data.wall_count = g_state.wall_count
        frame_data.spawner_count = g_state.spawner_count
        frame_data.map_height = g_state.map_height

        // Update phase
        game_update(frame_data)

        // Render phase
        raylib.BeginDrawing()
        raylib.ClearBackground(color_bg)

        game_draw_world()

        hud_draw(frame_data)

        raylib.EndDrawing()

        // 7. Clear the single-frame Temp Allocator at the end of the frame
        free_all(context.temp_allocator)
    }
}
