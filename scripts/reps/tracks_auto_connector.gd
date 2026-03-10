extends Area3D
class_name TracksAutoConnector

@export var connection_id: String
@export var track: Track
@export var track_start_connection: bool

var _used: bool

func _enter_tree() -> void:
    if area_entered.connect(_handle_area_entered) != OK:
        push_error("Failed to connect area entered")

func _handle_area_entered(area: Area3D) -> void:
    if area is TracksAutoConnector:
        handle_connection(area as TracksAutoConnector)
    else:
        print_debug("%s ignores touching %s" % [self, area])

func handle_connection(other: TracksAutoConnector) -> void:
    if _used:
        print_debug("Already used up!")
        return

    if connection_id != other.connection_id:
        push_warning("%s touched %s but '%s' != '%s'" % [self, other, connection_id, other.connection_id])
        return

    if track == null:
        push_error("No track configured for %s" % [self])
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

    if track_start_connection:
        track.start_mode = Track.ConnectionMode.TRACK
    else:
        track.end_mode = Track.ConnectionMode.TRACK

    if other.track_start_connection:
        other.track.start_mode = Track.ConnectionMode.TRACK
    else:
        other.track.end_mode = Track.ConnectionMode.TRACK

    queue_free()
    other.queue_free()

    _used = true
    other._used = true
    print_debug("Freeing %s and %s after connecting %s -> %s and %s -> %s" % [
        self,
        other,
        "start" if track_start_connection else "end",
        other.track,
        "other.start" if other.track_start_connection else "other.end",
        track,
    ])
