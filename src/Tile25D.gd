class_name Tile25D
extends Resource

enum Kind {
	# 16-piece autotile sprite, floor-wise
	FLOOR,
	# 16-piece autotile sprite, wall-wise
	WALL,
	# A single aligned sprite
	SIMPLE,
}


# Measured not in pixels, but `tile_size`-s
@export var offset: Vector2i
@export var must_draw: bool = false
@export var kind: Kind = Kind.SIMPLE
# If >0, this will be an overlay over another node type
@export var above: int = -1
