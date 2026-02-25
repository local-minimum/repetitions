extends Area3D
class_name TracksAutoConnector

@export var connection_id: String
@export var track: Track
@export var track_start_connection: bool
@export var free_after_connecting: bool = true

func _enter_tree() -> void:
    if area_entered.connect(_handle_area_entered) != OK:
        push_error("Failed to connect area entered")

func _handle_area_entered(area: Area3D) -> void:
    if area is TracksAutoConnector:
        handle_connection(area as TracksAutoConnector)

func handle_connection(other: TracksAutoConnector) -> void:
    if connection_id != other.connection_id:
        return

    var a_connections: Array[Track] = (
        track.start_connections if track_start_connection else track.end_connections
    )
    var b_connections: Array[Track] = (
        other.track.start_connections if other.track_start_connection else other.track.end_connections
    )

    if !a_connections.has(other.track):
        a_connections.append(other.track)
    if !b_connections.has(track):
        b_connections.append(track)

    if free_after_connecting:
        queue_free()
