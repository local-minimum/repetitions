@tool

extends TrackFollow
class_name TrackEngine

@export var speed: float = 0.25

func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        return

    if current_track == null:
        return

    if _position == null:
        snap_to_track(true)
        return

    #var prev: float = _position.offset_distance
    var off: float = _position.offset_distance + (delta * (1.0 if travel_forward else -1.0) * speed)
    _position = current_track.get_offset_position_global(off, true)
    #print_debug("%s: %s -> %s == %s" % [prev, delta, _position.offset_distance, off])

    _sync_position(true)
