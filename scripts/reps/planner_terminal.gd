extends Node3D
class_name PlannerTerminal

@export var _interaction_body: InteractionBody3D
@export var _plans_for_relative_elevation: int = 0
@export var _placement_allowance: int = 4:
    get():
        return _placement_allowance + trophy_bonus

var is_overused: bool:
    get():
        return _placed_rooms > _placement_allowance

var trophy_bonus: int = 0
var _placed_rooms: int = 0

var _terminal_active: bool

func _enter_tree() -> void:
    if __SignalBus.on_complete_dungeon_plan.connect(_handle_complete_dungeon_plan) != OK:
        push_error("Failed to connect complete dungeon plan")
    if __SignalBus.on_blueprint_room_placed.connect(_handle_room_placed) != OK:
        push_error("Failed to connect blueprint room place")

func _exit_tree() -> void:
    __SignalBus.on_blueprint_room_placed.disconnect(_handle_room_placed)
    __SignalBus.on_complete_dungeon_plan.disconnect(_handle_complete_dungeon_plan)

func _handle_room_placed(_room: BlueprintRoom) -> void:
    if _terminal_active:
        _placed_rooms += 1
        print_debug("%s Registed placement of %s (%s / %s)" % [self, _room, _placed_rooms, _placement_allowance])

func _handle_complete_dungeon_plan(_elevation: int, _rooms: Array[BlueprintRoom]) -> void:
    if _terminal_active:
        print_debug("%s no longer active %s / %s rooms placed" % [self, _placed_rooms, _placement_allowance])
    _terminal_active = false
    _interaction_body.interactable = true

func _on_screen_body_execute_interaction() -> void:
    var builder: DungeonBuilder = DungeonBuilder.find_builder_in_tree(self)
    var coords: Vector3i = builder.get_closest_coordinates(global_position)
    __SignalBus.on_ready_planner.emit(self, PhysicsGridPlayerController.last_connected_player, coords.y + _plans_for_relative_elevation, maxi(0, _placement_allowance - _placed_rooms))
    _terminal_active = true
    _interaction_body.interactable = false
