extends Node
class_name DirtMagazine

@export_file var _block_solid_path: String
@export_file var _block_dug_one_path: String
@export_file var _block_dug_two_straight_path: String
@export_file var _block_dug_two_bend_path: String
@export_file var _block_dug_three_path: String
@export_file var _block_dug_four_path: String

var _block_solid: PackedScene:
    get():
        if _block_solid == null:
            _block_solid = load(_block_solid_path)
        return _block_solid

var _block_dug_one: PackedScene:
    get():
        if _block_dug_one == null:
            _block_dug_one = load(_block_dug_one_path)
        return _block_dug_one

var _block_dug_two_straight: PackedScene:
    get():
        if _block_dug_two_straight == null:
            _block_dug_two_straight = load(_block_dug_two_straight_path)
        return _block_dug_two_straight

var _block_dug_two_bend: PackedScene:
    get():
        if _block_dug_two_bend == null:
            _block_dug_two_bend = load(_block_dug_two_bend_path)
        return _block_dug_two_bend

var _block_dug_three: PackedScene:
    get():
        if _block_dug_three == null:
            _block_dug_three = load(_block_dug_three_path)
        return _block_dug_three

var _block_dug_four: PackedScene:
    get():
        if _block_dug_four == null:
            _block_dug_four = load(_block_dug_four_path)
        return _block_dug_four
