extends RefCounted

# A private PRNG and incremental cache make the schedule deterministic from
# the campaign seed. It never consumes the WFC/enemy RNG or needs a save field.
# Guard/boss milestones and the existing optional-current floor stay intact.
var seed_value := 0
var initialized := false
var random := RandomNumberGenerator.new()
var events: Dictionary = {}
var cursor := 3
var previous := "sequence"


func _reset(seed_number: int) -> void:
	seed_value = seed_number
	initialized = true
	random.seed = seed_number ^ 0x2c174b31
	events = {3: "sequence"}
	cursor = 3
	previous = "sequence"


func _reserved(number: int) -> bool:
	return number % 5 in [0, 4] or number % 20 == 6


func family_for(seed_number: int, number: int) -> String:
	if not initialized or seed_number != seed_value:
		_reset(seed_number)
	while cursor < number:
		var proposed := cursor + random.randi_range(3, 9)
		# Move the event to the nearest available floor without exceeding its
		# 3–9 spacing. Every such window contains a non-reserved floor.
		var next := proposed
		if _reserved(next):
			var found := false
			for distance in range(1, 10):
				for candidate in [proposed + distance, proposed - distance]:
					if candidate - cursor >= 3 and candidate - cursor <= 9 and not _reserved(candidate):
						next = candidate
						found = true
						break
				if found:
					break
		var options: Array[String] = ["sequence", "sokoban", "switches", "hybrid", "quiet"]
		if next >= 11:
			options.append("mechanism")
		if next >= 16:
			options.append("circuit")
		options.erase(previous)
		var chosen: String = options[random.randi_range(0, options.size() - 1)]
		events[next] = chosen
		cursor = next
		previous = chosen
	return str(events.get(number, ""))
