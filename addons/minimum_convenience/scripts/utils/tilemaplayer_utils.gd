class_name TileMapLayerUtils

## Local space bounding box
static func _get_tile_bbox(local_coords: Vector2i, tile_size: Vector2) -> Rect2:
    return Rect2(Vector2(tile_size.x * local_coords.x, tile_size.y * local_coords.y), tile_size)

## Local space bounding box for content of tile map layer    
static func bounding_box(layer: TileMapLayer) -> Rect2:
    if layer == null:
        return Rect2()
        
    var size: Vector2i = layer.tile_set.tile_size
    var local_logical_rect: Rect2i = layer.get_used_rect() if layer != null else Rect2i()
    return Rect2(local_logical_rect.position * size, local_logical_rect.size * size)

## Perimeter of tile map layer, assuming one contigious mass
static func perimeter(layer: TileMapLayer) -> PackedVector2Array:
    if layer == null:
        return []
        
    var local_coords: Array[Vector2i] = layer.get_used_cells()
    if local_coords.is_empty():
        return []
    
    if local_coords.size() == 1:
        return PackedVector2Array(RectUtils.corners(bounding_box(layer)))
        
    local_coords.sort_custom(func (a: Vector2i, b: Vector2i) -> bool: return a.y < b.y || a.y == b.y && a.x < b.y)
    var direction: CardinalDirections.CardinalDirection = CardinalDirections.CardinalDirection.EAST
    var current_coords: Vector2i = local_coords[0]
    var visited_coords: Array[Vector2i] = []
    var points: PackedVector2Array = [_get_tile_bbox(current_coords, layer.tile_set.tile_size).position]
    var pos_x: bool = true
    var pos_y: bool = true
    
    while !visited_coords.has(current_coords): 
        # Update direction
        var updated_direction: bool = false
        var yaw_ccw: CardinalDirections.CardinalDirection = CardinalDirections.yaw_ccw(direction)[0]
        if local_coords.has(CardinalDirections.translate2d(current_coords, yaw_ccw)):
            direction = yaw_ccw
            updated_direction = true
            match direction:
                CardinalDirections.CardinalDirection.EAST:
                    pos_x = false
                    pos_y = true
                CardinalDirections.CardinalDirection.NORTH:
                    pos_x = true
                    pos_y = true
                CardinalDirections.CardinalDirection.WEST:
                    pos_x = true
                    pos_y = false
                CardinalDirections.CardinalDirection.SOUTH:
                    pos_x = false
                    pos_y = false
            
        elif local_coords.has(CardinalDirections.translate2d(current_coords, direction)):
            # We are just continuing on a straight line
            pass
            
        else:
            var yaw_cw: CardinalDirections.CardinalDirection = CardinalDirections.yaw_cw(direction)[0]
            if local_coords.has(CardinalDirections.translate2d(current_coords, yaw_cw)):
                direction = yaw_cw
                updated_direction = true
                match direction:
                    CardinalDirections.CardinalDirection.EAST:
                        pos_x = true
                        pos_y = true
                    CardinalDirections.CardinalDirection.NORTH:
                        pos_x = true
                        pos_y = false
                    CardinalDirections.CardinalDirection.WEST:
                        pos_x = false
                        pos_y = false
                    CardinalDirections.CardinalDirection.SOUTH:
                        pos_x = false
                        pos_y = true
                                     
            else:
                push_error("[TileMapLayer Utils] Constructing the perimeter accidentally ended up on %s when going %s from %s which is outside the tilemap" % [
                    CardinalDirections.translate2d(current_coords, yaw_cw),
                    CardinalDirections.name(yaw_cw),
                    points,
                ])
                return []    
                     
        # Add point
        var tile_bbox: Rect2 = _get_tile_bbox(current_coords, layer.tile_set.tile_size)
        if updated_direction:
            # print_debug("Going %s to %s" % [CardinalDirections.name(direction), current_coords])
            
            if !points.append(Vector2(
                tile_bbox.position.x if pos_x else tile_bbox.end.x,
                tile_bbox.position.y if pos_y else tile_bbox.end.y,
            )):
                push_warning("Failed to append outline points!")
        
        visited_coords.append(current_coords)                        
        current_coords = CardinalDirections.translate2d(current_coords, direction) 
    return points
