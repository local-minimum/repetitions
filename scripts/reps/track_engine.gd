@tool

extends TrackFollow
class_name TrackEngine

@export var speed: float = 0.25
@export var delay_start: int = 2000

func _process(delta: float) -> void:
    if Engine.is_editor_hint() || Time.get_ticks_msec() < delay_start:
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

    if _position.at_edge:
        var next_track: Track = current_track.get_next_track(_position.at_start)
        if next_track != null:
            if next_track != current_track && current_track.is_mirrored_connection_direction(next_track, _position.at_start):
                travel_forward = !travel_forward
            off = current_track.get_offset_overshoot(_position.offset_distance)
            if !travel_forward:
                off = next_track.get_offset_from_end(off)

            current_track = next_track
            _position = current_track.get_offset_position_global(off, true)
        else:
            # TODO: Handle getting to a stop better
            current_track = null

    _sync_position(true)
