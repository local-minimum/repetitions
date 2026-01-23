extends Control

@export var _icon: TextureRect
@export var _title: Label
@export var _rarity: Label
@export var _pool_stats: Label
@export var _type_tags: Label


func _ready() -> void:
    hide()


func show_tooltip(option: DraftOption) -> void:
    # TODO: If / when we have icons for rooms we show it here
    _icon.hide()
    
    _title.text = tr(option.room_name_key)
    _rarity.text = tr(DraftOption.prob_name_key(option.draft_probability_class))
    _pool_stats.text = "%s/%s" % [option.drafted_count, option.draftable_count]
    _type_tags.text = " | ".join(option.type.humanized_categories())
