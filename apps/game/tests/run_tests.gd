extends Node
## Minimal headless test runner (ADR-0005). Run from apps/game:
##   godot --headless --fixed-fps 60 res://tests/test_runner.tscn
## Discovers tests/test_*.gd, calls every `test_*` method with a context
## (awaiting coroutines), prints a summary and exits non-zero on failure.

const DIR := "res://tests/"


class Ctx:
	extends RefCounted
	var root: Node
	var failures: Array[String] = []
	var checks := 0

	func ok(cond: bool, msg := "") -> void:
		checks += 1
		if not cond:
			failures.append(msg if msg != "" else "expected true")

	func eq(a: Variant, b: Variant, msg := "") -> void:
		checks += 1
		if typeof(a) != typeof(b) and not ((a is int or a is float) and (b is int or b is float)):
			failures.append("%s: %s (%s) != %s (%s)" % [msg, a, type_string(typeof(a)), b, type_string(typeof(b))])
		elif a != b:
			failures.append("%s: %s != %s" % [msg, a, b])

	func frames(n: int) -> void:
		for i in n:
			await root.get_tree().physics_frame


func _ready() -> void:
	WordLibrary.load_words()
	SaveManager.delete_save()
	var only := OS.get_environment("TEST_FILTER")
	var passed := 0
	var failed := 0
	var files := DirAccess.get_files_at(DIR)
	files.sort()
	for f in files:
		if not (f.begins_with("test_") and f.ends_with(".gd")):
			continue
		# A suite that doesn't parse would otherwise stop _ready and hang the run.
		var script: GDScript = load(DIR + f)
		if script == null or not script.can_instantiate():
			failed += 1
			print("  FAIL  %s (does not load)" % f.get_basename())
			continue
		var suite: Object = script.new()
		for m in suite.get_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_") or (only != "" and not name.contains(only)):
				continue
			var ctx := Ctx.new()
			ctx.root = self
			await suite.call(name, ctx)
			if ctx.failures.is_empty():
				passed += 1
				print("  ok    %s.%s (%d checks)" % [f.get_basename(), name, ctx.checks])
			else:
				failed += 1
				print("  FAIL  %s.%s" % [f.get_basename(), name])
				for msg in ctx.failures:
					print("        - " + msg)
		if suite is Node:
			suite.free()
	SaveManager.delete_save()
	print("\n%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
