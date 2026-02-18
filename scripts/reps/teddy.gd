extends Node3D
class_name Teddy

func _enter_tree() -> void:
    if __SignalBus.on_physics_player_ready.connect(_handle_player_ready) != OK:
        push_error("Failed to connect physics player ready")

func _ready() -> void:
    _start_of_day_dialogues(PhysicsGridPlayerController.last_connected_player)

func _handle_player_ready(player: PhysicsGridPlayerController) -> void:
    _start_of_day_dialogues(player)

var _greeted: bool
static var _said_sleeptalker: bool
static var _did_only_look_last_time: bool

func _start_of_day_dialogues(player: PhysicsGridPlayerController) -> void:
    if _greeted || player == null:
        return

    _greeted = true

    if __GlobalGameState.game_day == 0:
        _talk(player, [tr("TEDDY_FIRST_GREETING").format({"emoji": "😴"})])
    elif !_said_sleeptalker && __GlobalGameState.game_day > 2 && randf() < 0.1:
        _talk(player, [tr("TEDDY_SLEEPTALKING").format({"emoji": "🫠"})])
        _said_sleeptalker = true
    elif _did_only_look_last_time && randf() < 0.3:
        _talk(player, [])
        _did_only_look_last_time = true

func _talk(player: PhysicsGridPlayerController, messages: Array[String]) -> void:
        await _init_conversation(player)

        await get_tree().create_timer(0.5).timeout
        if !messages.is_empty():
            print_debug(messages[0])
            await get_tree().create_timer(1).timeout

        _end_conversation()

func _init_conversation(player: PhysicsGridPlayerController, look: bool = true, look_ease_duration: float = 0.6) -> void:
        player.cinematic = true
        if look:
            player.focus_on(self, 0.7, look_ease_duration)
        await get_tree().create_timer(look_ease_duration).timeout

func _end_conversation() -> void:
    var player: PhysicsGridPlayerController = PhysicsGridPlayerController.last_connected_player
    player.defocus_on(self)
    player.cinematic = false
