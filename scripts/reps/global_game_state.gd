extends GlobalGameStateCore
class_name GlobalGameState

func _enter_tree() -> void:
    if __SignalBus.on_pickup_tool_blueprint.connect(_handle_pickup_tool_blueprint) != OK:
        push_error("Failed to connect pickup tool blueprint")
    if __SignalBus.on_pickup_tool_key.connect(_handle_pickup_key) != OK:
        push_error("Failed to connect pickup tool key")
    if __SignalBus.on_request_rest.connect(_handle_request_rest) != OK:
        push_error("Failed to connect request rest")
    if __SignalBus.on_spawn_room_placed.connect(_handle_spawn_room_placed) != OK:
        push_error("Failed to connect spawn room placed")

var added_blueprints: Array[ToolBlueprint.Blueprint]
var collected_keys: Array[ToolKey.KeyVariant]

var player_spawn_coords: Vector3i = Vector3i(22, 0, 22)
var room_to_player_coords_offset: Vector3i:
    get():
        if !_has_spawned:
            return room_to_player_coords_offset

        return player_spawn_coords - _spawn_room_coords

var next_room_spawn_coords: Vector3i:
    get():
        if !_has_spawned:
            return player_spawn_coords - room_to_player_coords_offset
        if _request_rest_different_room:
            return _request_rest_coords - room_to_player_coords_offset
        return _spawn_room_coords

var _has_spawned: bool = false
var _spawn_room: Room3D
var _spawn_room_coords: Vector3i

var _request_rest_different_room: bool
## Only valid if a different room
var _request_rest_coords: Vector3i

func _handle_pickup_tool_blueprint(blueprint: ToolBlueprint.Blueprint) -> void:
    if !added_blueprints.has(blueprint) && blueprint != ToolBlueprint.Blueprint.NONE:
        added_blueprints.append(blueprint)

func _handle_pickup_key(key: ToolKey.KeyVariant) -> void:
    if !collected_keys.has(key) && key != ToolKey.KeyVariant.NONE:
        collected_keys.append(key)

func _handle_request_rest(bed: Node3D, coords: Vector3i) -> void:
    var room: Room3D = Room3D.find_room(bed)
    if room == null:
        push_warning("Rest request in %s is outside room" % [bed])
        _request_rest_different_room = false
        return

    _request_rest_coords = coords
    _request_rest_different_room = room != _spawn_room

func _handle_spawn_room_placed(room: Room3D, room_coords: Vector3i, player_coords: Vector3i) -> void:
    _has_spawned = true
    _spawn_room = room
    _request_rest_different_room = false
    _request_rest_coords = player_coords
    player_spawn_coords = player_coords
    _spawn_room_coords = room_coords
