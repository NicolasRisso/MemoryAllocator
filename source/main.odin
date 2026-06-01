package main

import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import raylib "vendor:raylib"

main :: proc() {
    // 1. Initialize Level Allocator (Arena)
    // We use a static virtual arena for the level. It gets cleared on map load.
    err_level := virtual.arena_init_static(&g_level_arena, 2 * mem.Megabyte)
    if err_level != nil {
        fmt.eprintfln("Fatal Error: Failed to initialize level arena")
        return
    }
    defer virtual.arena_destroy(&g_level_arena)

    // Initialize HUD Allocator
    // Used specifically for HUD elements, text, etc.
    g_hud_arena: virtual.Arena
    err_hud := virtual.arena_init_static(&g_hud_arena, 1 * mem.Megabyte)
    if err_hud != nil {
        fmt.eprintfln("Fatal Error: Failed to initialize HUD arena")
        return
    }
    defer virtual.arena_destroy(&g_hud_arena)

    // 2. Load the initial map
    map_path : string = "maps/default.json"
    if !load_level(map_path) {
        fmt.println("Fatal Error: Failed to load map:", map_path)
        return
    }

    // 3. Initialize Raylib window based on JSON map specifications
    raylib.InitWindow(i32(g_state.map_width), i32(g_state.map_height), "Bullet Dodge Arcade Game - Base Loader")
    defer raylib.CloseWindow()

    raylib.SetTargetFPS(60)

    // Palette Colors
    color_bg       := raylib.Color{225, 225, 225, 255} // Light Gray
    color_wall     := raylib.Color{80, 80, 80, 255}    // Dark Gray
    color_spawner  := raylib.Color{230, 45, 45, 255}   // Red
    color_player   := raylib.Color{40, 80, 180, 255}   // Blue

    fmt.println("Map loaded successfully!")
    fmt.printf("Resolution: %dx%d, Player Speed: %.1f, Wall Thickness: %.1f\n", 
        g_state.map_width, g_state.map_height, g_state.player_speed, g_state.wall_thickness)

    // Main Game Loop
    for !raylib.WindowShouldClose() {
        // Delta time
        dt := raylib.GetFrameTime()

        // 4. Update phase (Simple player movement to show interaction)
        move_dir := raylib.Vector2{0, 0}
        if raylib.IsKeyDown(.W) || raylib.IsKeyDown(.UP)    do move_dir.y -= 1
        if raylib.IsKeyDown(.S) || raylib.IsKeyDown(.DOWN)  do move_dir.y += 1
        if raylib.IsKeyDown(.A) || raylib.IsKeyDown(.LEFT)  do move_dir.x -= 1
        if raylib.IsKeyDown(.D) || raylib.IsKeyDown(.RIGHT) do move_dir.x += 1

        if raylib.Vector2Length(move_dir) > 0 {
            move_dir = raylib.Vector2Normalize(move_dir)
            g_state.player.position += move_dir * g_state.player_speed * dt
        }

        // Keep player inside screen margins as a basic constraint
        margin := g_state.player.radius
        if g_state.player.position.x < margin do g_state.player.position.x = margin
        if g_state.player.position.y < margin do g_state.player.position.y = margin
        if g_state.player.position.x > f32(g_state.map_width) - margin  do g_state.player.position.x = f32(g_state.map_width) - margin
        if g_state.player.position.y > f32(g_state.map_height) - margin do g_state.player.position.y = f32(g_state.map_height) - margin

        // 5. Render phase
        raylib.BeginDrawing()
        raylib.ClearBackground(color_bg)

        // Draw walls as thick Dark Gray lines
        for i in 0..<g_state.wall_count {
            w := &g_state.walls[i]
            raylib.DrawLineEx(w.pos1, w.pos2, g_state.wall_thickness, color_wall)
        }

        // Draw spawners as Red circles
        for i in 0..<g_state.spawner_count {
            s := &g_state.spawners[i]
            raylib.DrawCircleV(s.position, 6.0, color_spawner)
        }

        // Draw player as a Blue circle
        raylib.DrawCircleV(g_state.player.position, g_state.player.radius, color_player)

        // 6. Draw HUD using the specific HUD allocator
        hud_allocator := virtual.arena_allocator(&g_hud_arena)
        
        // We can pass the HUD allocator explicitly to our formatting functions
        fps_text := fmt.caprintf("FPS: %d", raylib.GetFPS(), allocator = hud_allocator)
        info_text := fmt.caprintf("Loaded Map: %s (Walls: %d, Spawners: %d)", 
            map_path, g_state.wall_count, g_state.spawner_count, allocator = hud_allocator)
        
        raylib.DrawText(fps_text, 10, 10, 20, raylib.DARKGRAY)
        raylib.DrawText(info_text, 10, 35, 16, raylib.DARKGRAY)
        raylib.DrawText("Use WASD or Arrows to move the Blue Player dot", 10, i32(g_state.map_height) - 25, 16, raylib.DARKGRAY)

        // Clear HUD allocator each frame
        free_all(hud_allocator)

        raylib.EndDrawing()

        // 7. Clear the single-frame Temp Allocator at the end of the frame
        free_all(context.temp_allocator)
    }
}
