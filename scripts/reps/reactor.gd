extends Node3D

@export var detection_area: Area3D
@export var exit_area: Area3D

func _on_area_3d_body_entered(body: Node3D) -> void:
    var player: PhysicsGridPlayerController = PhysicsGridPlayerController.find_player_in_tree(body)
    if player != null:
        player.gridless = true

func _on_area_3d_body_exited(body: Node3D) -> void:
    var player: PhysicsGridPlayerController = PhysicsGridPlayerController.find_player_in_tree(body)
    if player != null && is_instance_valid(player):
        player.gridless = false
