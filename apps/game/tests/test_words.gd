extends RefCounted
## Word library and interaction verbs (GDD §4.2, TDD §3.6).


func test_library_is_data_driven(t) -> void:
	t.eq(WordLibrary.category("OPEN"), "state", "OPEN category")
	t.eq(WordLibrary.get_def("SHUT").get("open"), false, "SHUT closes")
	t.eq(WordLibrary.category("UP"), "motion", "UP category")
	t.ok(not WordLibrary.exists("BANANA"), "unknown words do not exist")
	for w: String in WordLibrary.all_words():
		t.ok(RegEx.create_from_string("^[A-Z]{1,12}$").search(w) != null, "word id format: " + w)
		t.ok(WordLibrary.category(w) != "", "every word has a category: " + w)


func test_verbs(t) -> void:
	t.eq(WordSlot.verb_for("", "OPEN", true, false), "take", "empty hand takes a loose word")
	t.eq(WordSlot.verb_for("", "OPEN", false, false), "", "fixed words stay put")
	t.eq(WordSlot.verb_for("", "", true, false), "", "nothing to take from a gap")
	t.eq(WordSlot.verb_for("OPEN", "", true, true), "place", "place into an accepting gap")
	t.eq(WordSlot.verb_for("OPEN", "SHUT", true, true), "swap", "swap with a loose word")
	t.eq(WordSlot.verb_for("OPEN", "SHUT", false, true), "", "cannot swap a fixed word")
	t.eq(WordSlot.verb_for("UP", "", true, false), "", "category not accepted")


func test_slot_categories(t) -> void:
	var holder := _Holder.new()
	var any := WordSlot.make("b:0", "", true, [], holder, null)
	var door := WordSlot.make("d:label", "", true, ["state"], holder, null)
	t.ok(any.accepts_word("UP"), "sentence gaps accept anything")
	t.ok(door.accepts_word("OPEN"), "doors accept state words")
	t.ok(not door.accepts_word("UP"), "doors refuse motion words")
	door.put("OPEN")
	t.eq(holder.changes, 1, "holder notified on put")
	t.eq(door.take(), "OPEN", "take returns the word")
	t.eq(door.word, "", "slot empty after take")


func test_bubble_parsing(t) -> void:
	var speaker := Node2D.new()
	var b := SpeechBubble.new()
	b.setup({"id": "nb", "at": [0, 0], "text": "THIS DOOR WON'T *OPEN*.|A ** GAP."}, speaker)
	t.eq(b.slots.size(), 2, "two slots")
	t.eq(b.slots[0].id, "nb:0", "slot id")
	t.eq(b.slots[0].word, "OPEN", "bold word")
	t.eq(b.slots[1].word, "", "empty gap")
	b.free()
	speaker.free()


class _Holder:
	extends RefCounted
	var changes := 0

	func on_slot_changed(_s: WordSlot) -> void:
		changes += 1
