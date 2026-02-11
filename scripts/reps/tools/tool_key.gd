extends Tool
class_name ToolKey

enum KeyVariant { NONE, FLOPPY_KEY}
@export var _variant: KeyVariant = KeyVariant.NONE

func _ready() -> void:
    if _type == ToolType.KEY && _variant != KeyVariant.NONE:
        if __GlobalGameState.deposited_keys.has(_variant):

            queue_free()

func _do_pickup() -> void:
    if _type == ToolType.KEY && _variant != KeyVariant.NONE:
        var player: PhysicsGridPlayerController = PhysicsGridPlayerController.last_connected_player
        player.cinematic = true
        player.focus_on(self, 0.5)

        await get_tree().create_timer(1).timeout

        player.defocus_on(self)
        __SignalBus.on_pickup_tool_key.emit(_variant)
        player.cinematic = false

        queue_free()
