extends Resource
class_name DraftOption

enum DraftProbability { FREQUENT, DEFAULT, UNCOMMON, RARE }
@export_file_path("*.tscn") var _blueprint_room_path: String

@export var draft_probability_class: DraftProbability = DraftProbability.DEFAULT
var draft_probability: float:
    get():
        match draft_probability_class:
            DraftProbability.FREQUENT:
                return 1.5
            DraftProbability.DEFAULT:
                return 1.0
            DraftProbability.UNCOMMON:
                return 0.5
            DraftProbability.RARE:
                return 0.1
            _:
                push_error("Unhandled probability class %s in %s" % [DraftProbability.find_key(draft_probability_class), resource_path])                
                return 1.0
                
@export var draftable_count: int = 1
var drafted_count: int = 0

var consumed: bool:
    get():
        return draftable_count < draftable_count

var _blueprint_scene: PackedScene:
    get():
        if _blueprint_scene == null:
            _blueprint_scene = load(_blueprint_room_path)
        return _blueprint_scene

func instantiate_blueprint_room() -> BlueprintRoom:   
    var room: BlueprintRoom = _blueprint_scene.instantiate()
    return room

func _to_string() -> String:
    return "<DraftOption %s %s %s/%s>" % [_blueprint_room_path, DraftProbability.find_key(draft_probability_class), drafted_count, draftable_count]
