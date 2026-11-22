extends RefCounted

# These are authored puzzle modules, not random crate placements. Adjacency
# WFC builds the campaign topology; Sokoban maps need a verified push solution.
const TILE_FLOOR := 0
const TILE_WALL := 1
const LEVELS := [
	{
		"id": "vault_one",
		"title": "A PRIMEIRA CARGA",
		"rows": [
			"#########",
			"#       #",
			"#  .    #",
			"#       #",
			"# $  @  #",
			"#       #",
			"#     P #",
			"#########",
		],
		"push_par": 3,
		"move_par": 9,
	},
	{
		"id": "split_vault",
		"title": "DUAS ROTAS, DUAS CARGAS",
		"rows": [
			"###########",
			"#         #",
			"#   #     #",
			"#  .# .   #",
			"#   #     #",
			"# $$      #",
			"# @       #",
			"#       P #",
			"###########",
		],
		"push_par": 8,
		"move_par": 14,
	},
]


func is_special_floor(number: int) -> bool:
	# Existing 5th-floor bosses and 3rd/4th-in-cycle puzzle/Guardian milestones
	# remain intact. Other sixth-floor milestones use these box-puzzle modules.
	return number > 0 and number % 6 == 0 and number % 5 not in [0, 3, 4]


func get_title(number: int) -> String:
	var module_index := posmod(int(number / 6) - 1, LEVELS.size())
	return str(LEVELS[module_index].title)


func generate(number: int, seed_value: int) -> Dictionary:
	var module_index := posmod(int(number / 6) - 1, LEVELS.size())
	var template: Dictionary = LEVELS[module_index]
	var rows: Array = template.rows
	var height := rows.size()
	var width: int = str(rows[0]).length()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mirror_x := rng.randi_range(0, 1) == 1
	var mirror_y := rng.randi_range(0, 1) == 1
	var grid: Array = []
	for y in height:
		var row: Array[int] = []
		row.resize(width)
		row.fill(TILE_WALL)
		grid.append(row)
	var start := Vector2i.ZERO
	var portal := Vector2i.ZERO
	var goals: Array[Vector2i] = []
	var boxes: Array[Vector2i] = []
	for source_y in height:
		for source_x in width:
			var point := Vector2i(width - 1 - source_x if mirror_x else source_x, height - 1 - source_y if mirror_y else source_y)
			var cell := str(rows[source_y]).substr(source_x, 1)
			if cell != "#":
				grid[point.y][point.x] = TILE_FLOOR
			match cell:
				"@": start = point
				"P": portal = point
				".": goals.append(point)
				"$": boxes.append(point)
	return {
		"id": str(template.id),
		"title": str(template.title),
		"grid": grid,
		"size": Vector2i(width, height),
		"start": start,
		"portal": portal,
		"goals": goals,
		"boxes": boxes,
		"push_par": int(template.push_par),
		"move_par": int(template.move_par),
		"mirror_x": mirror_x,
		"mirror_y": mirror_y,
	}
