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

App_State :: enum {
    Menu,
    Playing,
    GameOver,
}

g_app_state: App_State = .Menu

main :: proc() {
    // 1. Initialize Level Allocator (Arena)
    err_level := virtual.arena_init_static(&g_level_arena, size_of(State) + 64)
    if err_level != nil {
        fmt.eprintfln("Fatal Error: Failed to initialize level arena")
        return
    }
    defer virtual.arena_destroy(&g_level_arena)

    // 2. Initialize GUI Menu Allocator
    if !menu_init() {
        fmt.eprintln("Fatal Error: Failed to initialize Menu GUI")
        return
    }
    defer menu_destroy()

    // 3. Initialize Raylib window with default size for Menu
    raylib.InitWindow(800, 600, "Bullet Dodge Arcade Game")
    defer raylib.CloseWindow()

    raylib.SetTargetFPS(60)

    map_path: string = ""

    // Main Game Loop
    for !raylib.WindowShouldClose() {
        switch g_app_state {
        case .Menu:
            // Render phase for menu
            raylib.BeginDrawing()
            raylib.ClearBackground(color_bg)

            selected_path, should_load := menu_update_and_draw()
            if should_load {
                if load_level(selected_path) {
                    map_path = selected_path
                    raylib.SetWindowSize(i32(g_state.map_width), i32(g_state.map_height))
                    g_app_state = .Playing
                    fmt.printf("Loaded level: %s, Resolution: %dx%d\n", map_path, g_state.map_width, g_state.map_height)
                } else {
                    fmt.eprintln("Failed to load map:", selected_path)
                }
            }

            raylib.EndDrawing()

        case .Playing:
            frame_data := new(Frame_Data, context.temp_allocator)
            frame_data.delta_time = raylib.GetFrameTime()
            frame_data.fps = raylib.GetFPS()
            frame_data.map_path = map_path
            frame_data.wall_count = g_state.wall_count
            frame_data.spawner_count = g_state.spawner_count
            frame_data.map_height = g_state.map_height
            frame_data.map_width = g_state.map_width
            frame_data.bullet_count = g_state.bullet_count
            frame_data.time_survived = g_state.time_survived

            // Update phase
            game_update(frame_data)

            // Render phase
            raylib.BeginDrawing()
            raylib.ClearBackground(color_bg)

            game_draw_world()
            hud_draw(frame_data)

            raylib.EndDrawing()

            // Clear the single-frame Temp Allocator
            free_all(context.temp_allocator)

        case .GameOver:
            frame_data := new(Frame_Data, context.temp_allocator)
            frame_data.delta_time = 0.0
            frame_data.fps = raylib.GetFPS()
            frame_data.map_path = map_path
            frame_data.wall_count = g_state.wall_count
            frame_data.spawner_count = g_state.spawner_count
            frame_data.map_height = g_state.map_height
            frame_data.map_width = g_state.map_width
            frame_data.bullet_count = g_state.bullet_count
            frame_data.time_survived = g_state.time_survived

            // Render phase
            raylib.BeginDrawing()
            raylib.ClearBackground(color_bg)

            game_draw_world()
            hud_draw(frame_data)

            // Draw semi-transparent Game Over overlay
            raylib.DrawRectangle(0, 0, i32(g_state.map_width), i32(g_state.map_height), raylib.Color{0, 0, 0, 120})

            go_text: cstring = "GAME OVER"
            go_width := raylib.MeasureText(go_text, 40)
            raylib.DrawText(go_text, i32(g_state.map_width) / 2 - go_width / 2, i32(g_state.map_height) / 2 - 40, 40, raylib.RED)

            sub_text: cstring = "Press any key to return to menu"
            sub_width := raylib.MeasureText(sub_text, 20)
            raylib.DrawText(sub_text, i32(g_state.map_width) / 2 - sub_width / 2, i32(g_state.map_height) / 2 + 10, 20, raylib.LIGHTGRAY)

            raylib.EndDrawing()

            // Clear the single-frame Temp Allocator
            free_all(context.temp_allocator)

            // Check for key press to return to Menu
            if raylib.GetKeyPressed() != .KEY_NULL {
                raylib.SetWindowSize(800, 600)
                g_app_state = .Menu
            }
        }
    }
}
