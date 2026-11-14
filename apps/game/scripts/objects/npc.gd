class_name Npc
extends Node2D
## A drawn character. Stands at its feet position; blinks; can show a short
## thought ("...?", "!") above its head when the story reacts to the player.
## `when` (Conditions) says when they are there, so one character can stand
## in a doorway by day and lie asleep in bed at night (GDD §4.7). A `solid`
## character blocks Nib's way. Pose "asleep" lies down with closed eyes.

var npc_id := ""
var _kind := "neighbor"
var when := ""
var pose := "stand"
var solid := false
var panel: ComicPanel
var bubble: SpeechBubble
var _body: StaticBody2D
var _blink := 0.0
var _emote := ""
var _emote_t := 0.0


func setup(def: Dictionary) -> void:
	npc_id = def["id"]
	_kind = def.get("sprite", "neighbor")
	when = def.get("when", "")
	pose = def.get("pose", "stand")
	solid = def.get("solid", false)
	if solid:
		# A body the size of a person in a doorway: Nib can't walk through.
		_body = StaticBody2D.new()
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(10, 22)
		cs.shape = shape
		cs.position = Vector2(0, -11)
		_body.add_child(cs)
		add_child(_body)
	var at: Array = def["at"]
	position = Vector2(at[0], at[1])
	_blink = randf_range(1.5, 3.5)


## Shows or hides the character (and their speech) as their condition says.
func set_present(on: bool) -> void:
	visible = on
	if bubble:
		bubble.visible = on
	if _body:
		_body.collision_layer = 1 if on else 0


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
	if (_blink < 0.0) != was or pose == "asleep":
		queue_redraw()


func _draw() -> void:
	var height := Figures.NEIGHBOR_HEIGHT
	if pose == "asleep":
		# Lying on their back (in bed), eyes shut, a Z drifting up.
		draw_set_transform(Vector2.ZERO, -PI / 2.0, Vector2.ONE)
		Figures.neighbor(self, Vector2.ZERO, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var t := Time.get_ticks_msec() / 1000.0
		ComicFont.draw(self, Vector2(16 + fmod(t, 2.0) * 3.0, -10 - fmod(t, 2.0) * 4.0), "Z", Color(Palette.INK, 1.0 - fmod(t, 2.0) / 2.0), true)
		return
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
