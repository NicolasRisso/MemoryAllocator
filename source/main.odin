package main

import "core:fmt"
import rl "vendor:raylib"

main :: proc() {
    // 1. Initialize level-session virtual memory arena
    init_memory()
    defer cleanup_memory()

    // 2. Load the initial map
    map_path := "maps/default.json"
    if !load_map(map_path) {
        fmt.println("Fatal Error: Failed to load map:", map_path)
        return
    }

    // 3. Initialize Raylib window based on JSON map specifications
    rl.InitWindow(g_state.map_width, g_state.map_height, "Bullet Dodge Arcade Game - Base Loader")
    defer rl.CloseWindow()

    rl.SetTargetFPS(60)

    // Palette Colors
    color_bg       := rl.Color{225, 225, 225, 255} // Light Gray
    color_wall     := rl.Color{80, 80, 80, 255}    // Dark Gray
    color_spawner  := rl.Color{230, 45, 45, 255}   // Red
    color_player   := rl.Color{40, 80, 180, 255}   // Blue

    fmt.println("Map loaded successfully!")
    fmt.printf("Resolution: %dx%d, Player Speed: %.1f, Wall Thickness: %.1f\n", 
        g_state.map_width, g_state.map_height, g_state.player_speed, g_state.wall_thickness)

    // Main Game Loop
    for !rl.WindowShouldClose() {
        // Delta time
        dt := rl.GetFrameTime()

        // 4. Update phase (Simple player movement to show interaction)
        move_dir := rl.Vector2{0, 0}
        if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP)    do move_dir.y -= 1
        if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN)  do move_dir.y += 1
        if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT)  do move_dir.x -= 1
        if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) do move_dir.x += 1

        if rl.Vector2Length(move_dir) > 0 {
            move_dir = rl.Vector2Normalize(move_dir)
            g_state.player.pos += move_dir * g_state.player_speed * dt
        }

        // Keep player inside screen margins as a basic constraint
        margin := g_state.player.radius
        if g_state.player.pos.x < margin do g_state.player.pos.x = margin
        if g_state.player.pos.y < margin do g_state.player.pos.y = margin
        if g_state.player.pos.x > f32(g_state.map_width) - margin  do g_state.player.pos.x = f32(g_state.map_width) - margin
        if g_state.player.pos.y > f32(g_state.map_height) - margin do g_state.player.pos.y = f32(g_state.map_height) - margin

        // 5. Render phase
        rl.BeginDrawing()
        rl.ClearBackground(color_bg)

        // Draw walls as thick Dark Gray lines
        for w in g_state.walls {
            rl.DrawLineEx(w.p1, w.p2, g_state.wall_thickness, color_wall)
        }

        // Draw spawners as Red circles
        for s in g_state.spawners {
            rl.DrawCircleV(s.pos, 6.0, color_spawner)
        }

        // Draw player as a Blue circle
        rl.DrawCircleV(g_state.player.pos, g_state.player.radius, color_player)

        // 6. Draw HUD utilizing context.temp_allocator for formatted strings
        // This validates that string allocations on the frame loop do not leak.
        fps_text := fmt.ctprintf("FPS: %d", rl.GetFPS())
        info_text := fmt.ctprintf("Loaded Map: %s (Walls: %d, Spawners: %d)", 
            map_path, len(g_state.walls), len(g_state.spawners))
        
        rl.DrawText(fps_text, 10, 10, 20, rl.DARKGRAY)
        rl.DrawText(info_text, 10, 35, 16, rl.DARKGRAY)
        rl.DrawText("Use WASD or Arrows to move the Blue Player dot", 10, g_state.map_height - 25, 16, rl.DARKGRAY)

        rl.EndDrawing()

        // 7. Clear context.temp_allocator at the end of the frame
        free_all(context.temp_allocator)
    }
}
