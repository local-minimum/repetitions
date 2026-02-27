@tool
extends TrackFollow
class_name TrackCarriage

@export var upstream_follow: TrackFollow
@export var downstream_carriage: TrackCarriage

var _engine: TrackEngine:
    get():
        if upstream_follow is TrackEngine:
            return upstream_follow
        if upstream_follow is TrackCarriage:
            return (upstream_follow as TrackCarriage)._engine
        return null

func calculate_position_and_rotation(
        track: Track,
        off: float,
        upstream_moving_in_track_forwards_direction: bool,
        upstream_reversing: bool) -> void:
    var track_point: Track.PointData = track.get_offset_position_global(off, true)

    var sync_position: bool = true
    reversing = upstream_reversing
    moving_in_track_forwards_direction = upstream_moving_in_track_forwards_direction
    current_track = track

    if track_point.at_edge:
        match track.get_connection_mode(track_point):
            Track.ConnectionMode.TRACK:
                var next_track: Track = track.get_next_track(track_point.at_start)
                if next_track != null:
                    track_point = manage_track_transition(next_track, track_point)
                else:
                    _engine.stop_engine()

            Track.ConnectionMode.STOP:
                var e: TrackEngine = _engine
                e.stop_engine()

            Track.ConnectionMode.NONE:
                # We left the track, lets just keep moving backwards then
                track = null
                if upstream_follow != null:
                    var d_engine_connector: Vector3 = upstream_follow.downstream_connector.global_position - global_position
                    var d_connector: Vector3 = upstream_connector.global_position - global_position
                    var a: float = d_connector.signed_angle_to(d_engine_connector, global_basis.y)
                    global_basis = global_basis.rotated(global_basis.y, a * 0.1)

                    d_engine_connector = upstream_follow.downstream_connector.global_position - global_position
                    d_connector = upstream_connector.global_position - global_position
                    a = d_connector.signed_angle_to(d_engine_connector, global_basis.x)
                    global_basis = global_basis.rotated(global_basis.x, a * 0.1)

                    var transl: Vector3 = upstream_follow.downstream_connector.global_position - upstream_connector.global_position
                    #print_debug("To align our connectors %s needs to move %s" % [self, transl])
                    global_position += transl
                    sync_position = false
                    #print_debug("Carriage is moving outside the track")

    if sync_position:
        #print_debug("Synking position of %s to %s @ %s" % [self, current_track, position.offset_distance])
        _sync_position(track_point)

        # This fucks everything up when switching tracks
        # var d_engine_connector: Vector3 = upstream_follow.downstream_connector.global_position - global_position
        # var d_connector: Vector3 = upstream_connector.global_position - global_position
        # var a: float = d_connector.signed_angle_to(d_engine_connector, global_basis.y)
        # print_debug("%s needs rotate %s" % [self, a])
        # global_basis = global_basis.rotated(global_basis.y, a * 0.1)

        # d_engine_connector = upstream_follow.downstream_connector.global_position - global_position
        # d_connector= upstream_connector.global_position - global_position
        # a = d_connector.signed_angle_to(d_engine_connector, global_basis.x)
        # print_debug("%s needs rotate %s" % [self, a])
        # global_basis = global_basis.rotated(global_basis.x, a * 0.25)


    if downstream_carriage != null:
        var next_track_off_distance: float = global_distance_to_downstream_connector + downstream_carriage.global_distance_to_upstream_connector
        if moving_in_track_forwards_direction != reversing:
            next_track_off_distance *= -1
        #print_debug("Asking %s to place itself at off %s (delta %s)" % [downstream_carriage, off + next_track_off_distance, next_track_off_distance])
        downstream_carriage.calculate_position_and_rotation(
            track,
            off + next_track_off_distance,
            moving_in_track_forwards_direction,
            reversing,
        )
