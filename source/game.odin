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

    // 3. Player Wall Collision
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

    // 4. Update Time Survived
    if !g_state.is_game_over {
        g_state.time_survived += f64(dt)
    }

    // 5. Update Spawners and Spawn Bullets (random directions)
    for i in 0..<g_state.spawner_count {
        s := &g_state.spawners[i]
        s.spawn_timer += dt
        if s.spawn_timer >= s.spawn_frequency {
            s.spawn_timer = 0.0
            
            if g_state.bullet_count < MAX_BULLETS {
                angle_deg := raylib.GetRandomValue(0, 359)
                angle := f32(angle_deg) * math.PI / 180.0
                dir := raylib.Vector2{ math.cos(angle), math.sin(angle) }
                
                bullet := Bullet{
                    position = s.position,
                    velocity = dir * s.velocity,
                    radius = 4.0,
                    type = s.bullet_type,
                }
                
                g_state.bullets[g_state.bullet_count] = bullet
                g_state.bullet_count += 1
            }
        }
    }

    // 6. Update Bullets and Collision
    b_idx := 0
    for b_idx < int(g_state.bullet_count) {
        b := &g_state.bullets[b_idx]
        b.position += b.velocity * dt
        
        // Out of bounds check
        out_margin := f32(100.0)
        if b.position.x < -out_margin || b.position.y < -out_margin || 
           b.position.x > f32(g_state.map_width) + out_margin || 
           b.position.y > f32(g_state.map_height) + out_margin {
            g_state.bullets[b_idx] = g_state.bullets[g_state.bullet_count - 1]
            g_state.bullet_count -= 1
            continue
        }

        bullet_destroyed := false
        
        // Check collision with walls
        for w_idx in 0..<g_state.wall_count {
            w := &g_state.walls[w_idx]
            a := w.pos1
            b_seg := w.pos2
            
            ab := b_seg - a
            ap := b.position - a
            
            ab_sq := ab.x * ab.x + ab.y * ab.y
            if ab_sq == 0.0 do continue
            
            t := (ap.x * ab.x + ap.y * ab.y) / ab_sq
            if t < 0.0 do t = 0.0
            if t > 1.0 do t = 1.0
            
            closest := a + ab * t
            
            diff := b.position - closest
            dist_sq := diff.x * diff.x + diff.y * diff.y
            
            total_collision_radius := b.radius + g_state.wall_thickness * 0.5
            if dist_sq < total_collision_radius * total_collision_radius {
                // Collision!
                impact_point := closest
                collision_normal := raylib.Vector2{0, 0}
                dist := f32(math.sqrt(dist_sq))
                if dist > 0.0001 {
                    collision_normal = diff / dist
                } else {
                    perp_norm := raylib.Vector2{ -ab.y, ab.x }
                    collision_normal = raylib.Vector2Normalize(perp_norm)
                }

                if b.type == .Bouncer {
                    // Bounce elastically
                    dot_prod := b.velocity.x * collision_normal.x + b.velocity.y * collision_normal.y
                    b.velocity = b.velocity - 2.0 * dot_prod * collision_normal
                    b.position = impact_point + collision_normal * (total_collision_radius + 0.1)
                } else if b.type == .Bulldozer {
                    if w.invulnerable {
                        // Bounce off invulnerable wall and keep alive
                        dot_prod := b.velocity.x * collision_normal.x + b.velocity.y * collision_normal.y
                        b.velocity = b.velocity - 2.0 * dot_prod * collision_normal
                        b.position = impact_point + collision_normal * (total_collision_radius + 0.1)
                    } else {
                        // Destroy wall by swapping with the last wall
                        g_state.walls[w_idx] = g_state.walls[g_state.wall_count - 1]
                        g_state.wall_count -= 1
                        
                        // Destroy bullet
                        g_state.bullets[b_idx] = g_state.bullets[g_state.bullet_count - 1]
                        g_state.bullet_count -= 1
                        bullet_destroyed = true
                    }
                } else if b.type == .Constructor {
                    // Spawn perpendicular wall centered at impact point
                    perp := raylib.Vector2{ -b.velocity.y, b.velocity.x }
                    perp = raylib.Vector2Normalize(perp) * 30.0 // L/2 = 30.0
                    
                    if g_state.wall_count < MAX_WALLS {
                        new_wall := Wall{
                            pos1 = impact_point + perp,
                            pos2 = impact_point - perp,
                            invulnerable = false,
                        }
                        g_state.walls[g_state.wall_count] = new_wall
                        g_state.wall_count += 1
                    }
                    
                    // Destroy bullet
                    g_state.bullets[b_idx] = g_state.bullets[g_state.bullet_count - 1]
                    g_state.bullet_count -= 1
                    bullet_destroyed = true
                }
                break // collision handled, stop checking other walls for this bullet
            }
        }
        
        if !bullet_destroyed {
            b_idx += 1
        }
    }
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

    // Draw bullets as colored circles
    for i in 0..<g_state.bullet_count {
        b := &g_state.bullets[i]
        color := raylib.YELLOW
        if b.type == .Bulldozer {
            color = raylib.PURPLE
        } else if b.type == .Constructor {
            color = raylib.GREEN
        }
        raylib.DrawCircleV(b.position, b.radius, color)
    }

    // Draw player as a Blue circle
    raylib.DrawCircleV(g_state.player.position, g_state.player.radius, color_player)
}
