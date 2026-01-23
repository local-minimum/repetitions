extends TextureRect
class_name PlannerTerminalIcon

@export var _variants: Array[Texture2D]
@export var _default_modulate_color: Color
@export var _zero_modulate_color: Color
@export var _neg_modulate_color: Color

var credits: int:
    set(value):
        var icon_value: int = clampi(value, 0, _variants.size() - 1)
        texture = _variants[icon_value]
        tooltip_text = tr("UI_REMAINING_CREDITS_ROOMS").format({"remaining_count": value})

        if value > 0:
            modulate = _default_modulate_color
        elif value == 0:
            modulate = _zero_modulate_color      
        else:
            modulate = _neg_modulate_color
            
        credits = value
