extends Resource
class_name DraftOption

enum RoomId {
    UNKNOWN = 0,
    
    START_ROOM = 1,
    
    BROOM_CLOSET = 100,
  
    HALL_1 = 200, 
    HALL_2 = 201, 
    HALL_3 = 202, 
    HALL_4 = 203, 
    HALL_5 = 204,
    
    CELL_1 = 300, 
    CELL_2 = 301, 
    CELL_3 = 302,    
    ROOM_CORNER = 310,
    ROOM_REACTOR = 320,
    ROOM_SHIFTING_WALLS = 330,
    ROOM_BACKROOM = 331,
}

enum DraftProbability { FREQUENT, DEFAULT, UNCOMMON, RARE }
static func prob_name_key(dprob: DraftProbability) -> String:
    return "ENUM_PROBABILITY_%s" % DraftProbability.find_key(dprob)

@export var room_id: RoomId

@export_flags("Room", "Hall") var _type: int:
    set(value):
        type = Type.new(value)
        _type = value        

var type: Type:
    get():
        if type == null:
            type = Type.new(_type)
        return type

class Type:
    enum Categories { NULL = 0, ROOM = 1, HALL = 2}

    @export var room: bool
    var _bits: int
    
    func _init(bits: int) -> void:
        _bits = bits
        
    var categories: Array[Categories]:
        get():
            var cats: Array[Categories]
            
            if (Categories.ROOM & _bits) == Categories.ROOM:
                cats.append(Categories.ROOM)
            if (Categories.HALL & _bits) == Categories.HALL:
                cats.append(Categories.HALL)
        
            return cats
    
    func humanized_categories() -> Array[String]:
        return Array(
            categories.map(func (c: Categories) -> String: return tr("ENUM_ROOM_CATEGORY_%s" % Categories.find_key(c))),
            TYPE_STRING,
            "",
            null,
        )
        
    func has_all(other: Type) -> bool:
        return (_bits & other._bits) == _bits
        

@export var room_name_key: String

@export_file_path("*.tscn") var _blueprint_room_path: String

@export_file_path("*.tscn") var _3d_room_path: String

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
        return drafted_count >= draftable_count

var _blueprint_scene: PackedScene:
    get():
        if _blueprint_scene == null:
            _blueprint_scene = load(_blueprint_room_path)
        return _blueprint_scene

func instantiate_blueprint_room() -> BlueprintRoom:   
    var room: BlueprintRoom = _blueprint_scene.instantiate()
    room.option = self
    return room

var _3d_room_scene: PackedScene:
    get():
        if _3d_room_scene == null:
            _3d_room_scene = load(_3d_room_path)
        return _3d_room_scene

func instantiate_3d_room() -> Node3D:
    var room: Node3D = _3d_room_scene.instantiate()
    return room

func _to_string() -> String:
    return "<DraftOption %s %s %s/%s>" % [_blueprint_room_path, DraftProbability.find_key(draft_probability_class), drafted_count, draftable_count]
