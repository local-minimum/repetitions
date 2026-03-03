extends EquippedTool

func execute_action(target: Node3D, caster: ShapeCast3D) -> void:
    var dir: CardinalDirections.CardinalDirection = CardinalDirections.node_planar_rotation_to_direction(_player)
    __SignalBus.on_use_pickax.emit(target, dir, caster.get_collision_point(0))
