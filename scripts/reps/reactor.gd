extends Node3D

@export var detection_area: Area3D

func _on_area_3d_body_entered(body: Node3D) -> void:
    var player: PhysicsGridPlayerController = _get_player(body)
    if player != null:
        player.gridless = true

func _on_area_3d_body_exited(body: Node3D) -> void:
    var player: PhysicsGridPlayerController = _get_player(body)
    if player != null:
        player.gridless = false

func _get_player(body: Node3D) -> PhysicsGridPlayerController:
    while body != null:
        if body is PhysicsGridPlayerController:
            return body as PhysicsGridPlayerController
    
        body = body.get_parent_node_3d()
        
    return null
