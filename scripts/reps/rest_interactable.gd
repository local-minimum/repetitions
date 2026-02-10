extends StaticBody3D
class_name RestInteractable

@export var _interact_max_sq_dist: float = 4.0
@export_range(-1.0, 1.0, 0.05) var _look_angle_dot_product_threshold: float = 0.0
@export var _bed: Node3D

var coordinates: Vector3i:
    get():
        var builder: DungeonBuilder = DungeonBuilder.active_builder
        if builder == null:
            push_error("Cannot request rest if there's no dungeon builder active")
            return Vector3i.ZERO

        if _bed == null:
            return builder.get_closest_coordinates(self.global_position)

        return builder.get_closest_coordinates(_bed.global_position)

func _enter_tree() -> void:
    if !mouse_entered.is_connected(_handle_mouse_entered) && mouse_entered.connect(_handle_mouse_entered) != OK:
        push_error("Failed to connect mouse entered")
    if !mouse_exited.is_connected(_handle_mouse_exited) && mouse_exited.connect(_handle_mouse_exited) != OK:
        push_error("Failed to connect mouse exited")
    if !input_event.is_connected(_handle_input_event) && input_event.connect(_handle_input_event) != OK:
        push_error("Failed to connect input event")

    _hovered = false

func valid_player_position() -> bool:
    var player: PhysicsGridPlayerController = PhysicsGridPlayerController.last_connected_player
    if player == null:
        return false

    for owner_id: int in get_shape_owners():
        if is_shape_owner_disabled(owner_id):
            continue

        var s_owner: Object = shape_owner_get_owner(owner_id)
        if s_owner is CollisionShape3D:
            var cs: CollisionShape3D = s_owner

            var pt: Vector3 = CollisionShapeUtils.get_closest_point_on_surface_or_inside(player.global_position, cs)
            if pt.distance_squared_to(player.position) <= _interact_max_sq_dist:
                var dir: Vector3 = cs.global_position - player.global_position
                dir.y = 0
                dir = dir.normalized()
                # print_debug("dir %s dot %s gives %s > %s" % [
                #     dir,
                #    -player.camera.global_basis.z,
                #    dir.dot(-player.camera.global_basis.z),
                #    _look_angle_dot_product_threshold
                #])
                if dir.dot(-player.camera.global_basis.z) > _look_angle_dot_product_threshold:
                    return true

    return false

var _valid: bool
var _hovered: bool:
    set(value):
        if value:
            set_physics_process(true)
        else:
            set_physics_process(false)
        _hovered = value

func _handle_mouse_entered() -> void:
    _hovered = true
    if valid_player_position():
        _valid = true
        InputCursorHelper.add_state(self, InputCursorHelper.State.HOVER)
    else:
        _valid = false

func _physics_process(_delta: float) -> void:
    _update_pointer()

func _handle_mouse_exited() -> void:
    _hovered = false
    InputCursorHelper.remove_state(self, InputCursorHelper.State.HOVER)

func _is_interaction(event: InputEvent) -> bool:
    if event.is_action_pressed(&"crawl_search"):
        return true
    if event is not InputEventMouseButton:
        return false

    var mbtn: InputEventMouseButton = event
    return !mbtn.is_echo() && mbtn.button_index == MOUSE_BUTTON_LEFT && mbtn.pressed

func _handle_input_event(_cam: Node, event: InputEvent, _event_position: Vector3, _event_normal: Vector3, _shape_idx: int) -> void:
    if PhysicsGridPlayerController.last_connected_player_cinematic:
        if _valid:
            _valid = false
            InputCursorHelper.remove_state(self, InputCursorHelper.State.HOVER)
        return

    if  _is_interaction(event) && valid_player_position():
        get_viewport().set_input_as_handled()
        _execute_interaction()

func _update_pointer() -> void:
    if PhysicsGridPlayerController.last_connected_player_cinematic:
        return

    var valid: bool = valid_player_position()
    if _valid != valid:
        if valid:
            _valid = true
            InputCursorHelper.add_state(self, InputCursorHelper.State.HOVER)
        else:
            _valid = false
            InputCursorHelper.remove_state(self, InputCursorHelper.State.HOVER)

func _execute_interaction() -> void:
    if DungeonBuilder.active_builder == null:
        push_error("Cannot request rest if there's no dungeon builder active")
        return
    var coords: Vector3i = coordinates
    print_debug("Rest requested in %s at %s" % [_bed, coords])
    __SignalBus.on_request_rest.emit(_bed, coords)
