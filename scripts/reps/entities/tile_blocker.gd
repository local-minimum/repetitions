extends Node
class_name TileBlocker

static var _blocks: Dictionary[Node, Array]

static var _SPACE_RESERVATION_LAYER: int = 12

static func block(entity: Node, coordinates: Vector3i, fill_amount: float = 0.9) -> void:
    var dungeon: Dungeon = Dungeon.find_dungeon_in_tree(entity)
    var pos: Vector3 = dungeon.get_global_grid_position_from_coordinates(coordinates)

    var body: StaticBody3D = StaticBody3D.new()
    body.name = "Tile Blocker at %s for %s" % [coordinates, entity.name]
    body.set_collision_layer_value(_SPACE_RESERVATION_LAYER, true)
    body.collision_mask = 0

    var collider: CollisionShape3D = CollisionShape3D.new()

    var box: BoxShape3D = BoxShape3D.new()
    box.size = fill_amount * dungeon.grid_size
    collider.shape = box

    body.add_child(collider)
    dungeon.add_child(body)
    body.global_position = pos + 0.5 * Vector3.UP * dungeon.grid_size

    if !_blocks.has(entity):
        _blocks[entity] = [body] as Array[Node]
    else:
        _blocks[entity].append(body)

static func remove_blocks(entity: Node) -> void:
    if _blocks.has(entity):
        for blockage: Node3D in _blocks[entity]:
            blockage.queue_free()
        if !_blocks.erase(entity):
            _blocks[entity] = []

func _exit_tree() -> void:
    _blocks.clear()
