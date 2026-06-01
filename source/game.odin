package main

import raylib "vendor:raylib"
import "core:math"

game_update :: proc(frame_data: ^Frame_Data) {
    dt := frame_data.delta_time

    // 1. Handle Input
    move_dir := raylib.Vector2{0, 0}
    if raylib.IsKeyDown(.W) || raylib.IsKeyDown(.UP)    do move_dir.y -= 1
    if raylib.IsKeyDown(.S) || raylib.IsKeyDown(.DOWN)  do move_dir.y += 1
    if raylib.IsKeyDown(.A) || raylib.IsKeyDown(.LEFT)  do move_dir.x -= 1
    if raylib.IsKeyDown(.D) || raylib.IsKeyDown(.RIGHT) do move_dir.x += 1

    if raylib.Vector2Length(move_dir) > 0 {
        move_dir = raylib.Vector2Normalize(move_dir)
        g_state.player.position += move_dir * g_state.player_speed * dt
    }

    // 2. Map Border Constraints
    margin := g_state.player.radius
    if g_state.player.position.x < margin do g_state.player.position.x = margin
    if g_state.player.position.y < margin do g_state.player.position.y = margin
    if g_state.player.position.x > f32(g_state.map_width) - margin  do g_state.player.position.x = f32(g_state.map_width) - margin
    if g_state.player.position.y > f32(g_state.map_height) - margin do g_state.player.position.y = f32(g_state.map_height) - margin

    // 3. Wall Collision
    player_pos := g_state.player.position
    player_radius := g_state.player.radius
    wall_radius := g_state.wall_thickness * 0.5
    total_radius := player_radius + wall_radius

    for i in 0..<g_state.wall_count {
        wall := &g_state.walls[i]
        
        a := wall.pos1
        b := wall.pos2
        
        ab := b - a
        ap := player_pos - a
        
        ab_sq := (ab.x * ab.x) + (ab.y * ab.y)
        if ab_sq == 0.0 do continue
        
        t := ((ap.x * ab.x) + (ap.y * ab.y)) / ab_sq
        if t < 0.0 do t = 0.0
        if t > 1.0 do t = 1.0
        
        closest := a + ab * t
        
        diff := player_pos - closest
        dist_sq := (diff.x * diff.x) + (diff.y * diff.y)
        
        if dist_sq < total_radius * total_radius && dist_sq > 0.0001 {
            dist := f32(math.sqrt(dist_sq))
            penetration := total_radius - dist
            
            normal := diff / dist
            player_pos += normal * penetration
        }
    }
    
    g_state.player.position = player_pos
}

game_draw_world :: proc() {
    color_wall     := raylib.Color{80, 80, 80, 255}    // Dark Gray
    color_spawner  := raylib.Color{230, 45, 45, 255}   // Red
    color_player   := raylib.Color{40, 80, 180, 255}   // Blue

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
}
