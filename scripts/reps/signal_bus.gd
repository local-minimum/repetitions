extends SignalBusCore
class_name SignalBus

@warning_ignore_start("unused_signal")
signal on_physics_player_ready(player: PhysicsGridPlayerController)
signal on_physics_player_removed(player: PhysicsControllerStepCaster)

signal on_ready_planner(terminal: PlannerTerminal, player: PhysicsGridPlayerController, elevation: int, allowance: int)
signal on_update_planning(planner: DungeonPlanner, remaining_rooms: int)
signal on_hover_blueprint_room_enter(room: BlueprintRoom)
signal on_hover_blueprint_room_exit(room: BlueprintRoom)
signal on_blueprint_room_move_start(room: BlueprintRoom)
signal on_blueprint_room_position_updated(room: BlueprintRoom, coordinates: Vector2i, valid_coordinates: bool)
signal on_blueprint_room_dropped(room: BlueprintRoom, drag_origin: Vector2, drag_origin_angle: float)
signal on_blueprint_room_placed(room: BlueprintRoom)
signal on_complete_dungeon_plan(elevation: int, rooms: Array[BlueprintRoom])
signal on_elevation_plan_sealed(elevation: int)

signal on_pickup_tool(tool: Tool.ToolType)
signal on_drop_tool(tool: Tool.ToolType)
signal on_request_tool(tool: Tool.ToolType, receipient: Node3D)

signal on_use_pickax(target: Node3D, hack_direction: CardinalDirections.CardinalDirection, point: Vector3)
signal on_trophy_stolen_from_terminal(terminal: PlannerTerminal)
@warning_ignore_restore("unused_signal")
