extends Control
class_name PlannerTerminalIcon

@export var _target: TextureRect

@export var _variants: Array[Texture2D]
@export var _default_modulate_color: Color
@export var _zero_modulate_color: Color
@export var _neg_modulate_color: Color

var credits: int:
    set(value):
        var icon_value: int = clampi(value, 0, _variants.size() - 1)
        _target.texture = _variants[icon_value]
        _target.tooltip_text = tr("UI_REMAINING_CREDITS_ROOMS").format({"remaining_count": value})

        if value > 0:
            _target.modulate = _default_modulate_color
        elif value == 0:
            _target.modulate = _zero_modulate_color
        else:
            _target.modulate = _neg_modulate_color

        credits = value
