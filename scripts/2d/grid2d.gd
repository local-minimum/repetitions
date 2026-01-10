extends Node2D
class_name Grid2D

@export var tile_size: Vector2:
    set(value):
        tile_size = value
        if show_grid:
            queue_redraw()
            
@export var extent: Rect2i:
    set(value):
        extent = value
        if show_grid:
            queue_redraw()
            
@export_group("Drawing")
@export var show_grid: bool:
    set(value):
        show_grid = value
        queue_redraw()
        
@export var line_width: float = 1:
    set(value):
        line_width = value
        if show_grid:
            queue_redraw()
            
@export var line_color: Color = Color.MIDNIGHT_BLUE:
    set(value):
        line_color = value
        if show_grid:
            queue_redraw()

func is_inside_grid(global_point: Vector2, tolerance: float = 0.0) -> bool:
    var local: Vector2 = to_local(global_point)
    return (
        local.x + tolerance >= extent.position.x * tile_size.x &&
        local.x - tolerance < extent.end.x * tile_size.x &&
        local.y + tolerance >= extent.position.y * tile_size.y &&
        local.y - tolerance < extent.end.y * tile_size.y
    )
    
func get_closest_coordinates(global_point: Vector2) -> Vector2i:
    var local: Vector2 = to_local(global_point)
    var coords: Vector2i = Vector2i(roundi(local.x / tile_size.x), roundi(local.y / tile_size.y))
    
    return RectUtils.clamp_pointi(extent, coords)

func get_global_point(coordinates: Vector2i, overflow: bool = false) -> Vector2:
    if !overflow:
        coordinates = RectUtils.clamp_pointi(extent, coordinates)
    
    return to_global(
        Vector2(
            coordinates.x * tile_size.x,
            coordinates.y * tile_size.y,
        )
    )
    
func get_local_cell_rect(coordinates: Vector2i, overflow: bool = false) -> Rect2:
    if !overflow:
        coordinates = RectUtils.clamp_pointi(extent, coordinates)
    
    return Rect2(
        Vector2(
            coordinates.x * tile_size.x,
            coordinates.y * tile_size.y,
        ),
        tile_size,
    )
    
func _ready() -> void:
    if show_grid:
        queue_redraw()

func _draw() -> void:
    if !show_grid:
        return
    
    for row: int in range(extent.position.y, extent.end.y):
        draw_line(
            Vector2(extent.position.x * tile_size.x, row * tile_size.y), 
            Vector2(extent.end.x * tile_size.x, row * tile_size.y),
            line_color,
            line_width,
        )
    
    for col: int in range(extent.position.x, extent.end.x):
        draw_line(
            Vector2(col * tile_size.x, extent.position.y * tile_size.y), 
            Vector2(col * tile_size.x, extent.end.y * tile_size.y),
            line_color,
            line_width,
        ) 
