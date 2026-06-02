package main

import "core:mem"
import "core:mem/virtual"
import "core:path/filepath"
import "core:fmt"
import "core:strings"
import "core:os"
import rl "vendor:raylib"

Menu_State :: struct {
    map_files: []string,
    active_idx: i32,
    edit_mode: bool,
    options_string: string,
}

g_menu_state: Menu_State
g_gui_arena: virtual.Arena

menu_init :: proc() -> bool {
    err := virtual.arena_init_static(&g_gui_arena, 64 * 1024)
    if err != nil {
        fmt.eprintln("Failed to initialize GUI arena")
        return false
    }
    
    menu_refresh_map_list()
    return true
}

menu_destroy :: proc() {
    virtual.arena_destroy(&g_gui_arena)
}

menu_refresh_map_list :: proc() {
    allocator := virtual.arena_allocator(&g_gui_arena)
    free_all(allocator)
    
    g_menu_state.map_files = nil
    g_menu_state.options_string = ""
    
    handle, err := os.open("maps")
    if err != nil {
        fmt.eprintln("Error opening maps directory:", err)
        return
    }
    defer os.close(handle)
    
    files, dir_err := os.read_directory(handle, -1, allocator)
    if dir_err != nil {
        fmt.eprintln("Error reading maps directory:", dir_err)
        return
    }
    
    count := 0
    for f in files {
        if f.type == .Regular && strings.has_suffix(f.name, ".json") {
            count += 1
        }
    }
    
    if count == 0 do return
    
    g_menu_state.map_files = make([]string, count, allocator)
    idx := 0
    for f in files {
        if f.type == .Regular && strings.has_suffix(f.name, ".json") {
            g_menu_state.map_files[idx] = fmt.aprintf("maps/%s", f.name, allocator = allocator)
            idx += 1
        }
    }
    
    name_list := make([]string, count, context.temp_allocator)
    for path, i in g_menu_state.map_files {
        _, name_list[i] = filepath.split(path)
    }
    
    g_menu_state.options_string = strings.join(name_list, ";", allocator)
}

menu_update_and_draw :: proc() -> (selected_path: string, should_load: bool) {
    // Draw Title
    title: cstring = "BULLET DODGE ARCADE"
    title_width := rl.MeasureText(title, 32)
    rl.DrawText(title, 400 - title_width / 2, 100, 32, rl.DARKGRAY)
    
    subtitle: cstring = "Select a map to start playing"
    sub_width := rl.MeasureText(subtitle, 18)
    rl.DrawText(subtitle, 400 - sub_width / 2, 150, 18, rl.GRAY)
    
    // Dropdown bounds
    bounds := rl.Rectangle{ 300, 220, 200, 30 }
    
    if len(g_menu_state.map_files) == 0 {
        rl.DrawText("No maps found in maps/ directory!", 300, 220, 16, rl.RED)
        return "", false
    }
    
    options_cstr := strings.clone_to_cstring(g_menu_state.options_string, allocator = context.temp_allocator)
    
    prev_edit_mode := g_menu_state.edit_mode
    
    // If open and mouse clicked outside, close dropdown
    if g_menu_state.edit_mode && rl.IsMouseButtonPressed(.LEFT) {
        mouse_pos := rl.GetMousePosition()
        total_bounds := rl.Rectangle{
            x = bounds.x,
            y = bounds.y,
            width = bounds.width,
            height = bounds.height * f32(1 + len(g_menu_state.map_files)),
        }
        if !rl.CheckCollisionPointRec(mouse_pos, total_bounds) {
            g_menu_state.edit_mode = false
        }
    }
    
    // Draw raygui dropdown
    if rl.GuiDropdownBox(bounds, options_cstr, &g_menu_state.active_idx, g_menu_state.edit_mode) {
        g_menu_state.edit_mode = !g_menu_state.edit_mode
        
        // Refresh maps on opening dropdown
        if g_menu_state.edit_mode && !prev_edit_mode {
            menu_refresh_map_list()
        }
        
        // On selection (closing)
        if !g_menu_state.edit_mode {
            if g_menu_state.active_idx >= 0 && g_menu_state.active_idx < i32(len(g_menu_state.map_files)) {
                path := g_menu_state.map_files[g_menu_state.active_idx]
                return path, true
            }
        }
    }
    
    return "", false
}
