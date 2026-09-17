class_name TileSet25D
extends Resource

@export var tiles: Array[Tile25D]:
	set(value):
		if tiles == value: return
		if tiles != null:
			for tile in tiles:
				tile.changed.disconnect(emit_changed)

		tiles = value
		for tile in tiles:
			tile.changed.connect(emit_changed)
		emit_changed()
@export var tile_size: Vector2i = Vector2i(16, 16):
	set(value):
		if tile_size == value: return
		tile_size = value
		emit_changed()
