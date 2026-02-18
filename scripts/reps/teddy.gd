extends Node3D
class_name Teddy

@export var look_ease_duration: float = 0.6
@export var look_away_ease_duration: float = 0.3

func _enter_tree() -> void:
    if __SignalBus.on_physics_player_ready.connect(_handle_player_ready) != OK:
        push_error("Failed to connect physics player ready")

    if __SignalBus.on_look_at_shapesbox.connect(_handle_look_at_shapesbox) != OK:
        push_error("Failed to connect look at shapesbox")

    if __SignalBus.on_before_deposited_tool_key.connect(_handle_before_deposit_key) != OK:
        push_error("Failed to connect before deposited key")

    if __SignalBus.on_blocked_door_interaction.connect(_handle_interact_with_blocked_door) != OK:
        push_error("Failed to connec to blocked door interaction")

func _ready() -> void:
    _start_of_day_dialogues(PhysicsGridPlayerController.last_connected_player)

func _handle_player_ready(player: PhysicsGridPlayerController) -> void:
    _start_of_day_dialogues(player)

func _handle_look_at_shapesbox() -> void:
    _setup_dialogic("shape sorting toy", PhysicsGridPlayerController.last_connected_player)

func _handle_before_deposit_key(_total: int, _key: ToolKey.KeyVariant) -> void:
    # TODO
    pass

func _handle_interact_with_blocked_door(door: InteractionBody3D) -> void:
    if (
        Room3D.find_room(door) == __GlobalGameState.current_player_room &&
        __GlobalGameState.current_player_room == Room3D.find_room(self)
    ):
        var attempts: int = Dialogic.VAR.get_variable("Teddy.attempted_blocked_doors", 0)
        if !Dialogic.VAR.set_variable(
            "Teddy.attempted_blocked_doors",
            attempts + 1,
        ):
            push_error("Failed to increment attempted blocked doors")

        _setup_dialogic("blocked door", PhysicsGridPlayerController.last_connected_player)

var _greeted: bool

func _start_of_day_dialogues(player: PhysicsGridPlayerController) -> void:
    if _greeted || player == null:
        return

    _greeted = true
    _setup_dialogic("wakup", player)

func _setup_dialogic(label: String, player: PhysicsGridPlayerController) -> void:
    player.add_cinematic_blocker(self)

    if !Dialogic.VAR.set_variable("Teddy.rng", randf()):
        push_error("Failed to set variable")

    if Dialogic.signal_event.connect(_handle_signal_event) != OK:
        push_error("Failed to connect signal event")

    if Dialogic.timeline_ended.connect(_end_conversation, CONNECT_ONE_SHOT) != OK:
        push_error("Failed to connect end timeline")

    if !Dialogic.start("teddy", label):
        push_error("Failed to start dialog")
        player.remove_cinematic_blocker(self)

func _handle_signal_event(evt: Variant) -> void:
    if evt is String:
        match evt:
            "look_at":
                PhysicsGridPlayerController.last_connected_player.focus_on(self, 0.7, look_ease_duration)
                Dialogic.paused = true
                await get_tree().create_timer(look_ease_duration).timeout
                Dialogic.paused = false
            "look_away":
                PhysicsGridPlayerController.last_connected_player.defocus_on(self, look_away_ease_duration)

func _end_conversation() -> void:
    var player: PhysicsGridPlayerController = PhysicsGridPlayerController.last_connected_player
    player.defocus_on(self, look_away_ease_duration)
    player.remove_cinematic_blocker(self)
    Dialogic.signal_event.disconnect(_handle_signal_event)
