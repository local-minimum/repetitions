extends Area3D
class_name TrackEngineEffect

@export var _disable_and_hide_on_spawn: bool = true

@export var _visibility_toggles: Array[Node3D]
@export var _process_toggles: Array[Node3D]

@export var _affect_door: DoorConfigurationOptions
@export var _forced_door_state: DoorConfigurationOptions.DoorState
@export var _finalize_door: bool = true

@export var _oneshot: bool = true

func _enter_tree() -> void:
    if body_entered.connect(_handle_body_entered) != OK:
        push_error("Failed to connect body entered")

    if _disable_and_hide_on_spawn:
        for node: Node3D in _visibility_toggles:
            node.hide()
        for node: Node3D in _process_toggles:
            node.set_process(false)

func _handle_body_entered(body: Node3D) -> void:
    _handle_track_engine(TrackEngine.find_in_parent(body))

func _handle_track_engine(engine: TrackEngine) -> void:
    if engine == null:
        return

    for node: Node3D in _visibility_toggles:
        node.show()
    for node: Node3D in _process_toggles:
        node.set_process(true)

    if _affect_door != null && _forced_door_state != DoorConfigurationOptions.DoorState.UNDECIDED:
        _affect_door.force_door_version(_forced_door_state, _finalize_door)

    if _oneshot:
        queue_free()
