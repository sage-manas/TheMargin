class_name Npc
extends Node2D
## A drawn character. Stands at its feet position; blinks; can show a short
## thought ("...?", "!") above its head when the story reacts to the player.

var npc_id := ""
var _kind := "neighbor"
var _blink := 0.0
var _emote := ""
var _emote_t := 0.0


func setup(def: Dictionary) -> void:
	npc_id = def["id"]
	_kind = def.get("sprite", "neighbor")
	var at: Array = def["at"]
	position = Vector2(at[0], at[1])
	_blink = randf_range(1.5, 3.5)


func emote(text: String, duration := 3.0) -> void:
	_emote = text
	_emote_t = duration
	Audio.play("emote")
	queue_redraw()


func _process(delta: float) -> void:
	var was := _blink < 0.0
	_blink -= delta
	if _blink < -0.14:
		_blink = randf_range(2.0, 4.5)
	if _emote_t > 0.0:
		_emote_t -= delta
		if _emote_t <= 0.0:
			_emote = ""
			queue_redraw()
	if (_blink < 0.0) != was:
		queue_redraw()


func _draw() -> void:
	var height := Figures.NEIGHBOR_HEIGHT
	if _kind == "nib":
		Figures.nib(self, Vector2.ZERO, -1, "idle", 0.0, _blink < 0.0)
		height = Figures.NIB_HEIGHT
	else:
		Figures.neighbor(self, Vector2.ZERO, _blink < 0.0)
	if _emote != "":
		var w := ComicFont.measure(_emote) + 8
		var r := Rect2(roundf(-w / 2.0) - 8, -height - 17, w, 12)
		Ink.rounded_box(self, r, Palette.BUBBLE, Palette.INK, 5.0)
		# Thought-bubble puffs trailing down to the head.
		Ink.ellipse(self, Vector2(r.end.x - 4, r.end.y + 2.5), Vector2(1.4, 1.2), Palette.BUBBLE, Palette.INK, 0.7)
		Ink.ellipse(self, Vector2(r.end.x - 2, r.end.y + 5.0), Vector2(0.8, 0.7), Palette.BUBBLE, Palette.INK, 0.6)
		ComicFont.draw(self, r.position + Vector2(4, 2.5), _emote, Palette.INK)
