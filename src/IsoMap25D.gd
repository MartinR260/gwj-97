@tool

class_name IsoMap25D
extends GridMap

@abstract class Display:
	extends GridMap

	var _map: IsoMap25D
	var _tile_id: int

	@abstract func bake_reset() -> void
	@abstract func bake(pos: Vector3i) -> void

	@abstract func build_reset() -> void
	@abstract func build(offset: Vector2i) -> void

	@abstract func render_preview(src: Image, dst: Image, offset: Vector2i) -> void

	func _init(map: IsoMap25D, tile_id: int) -> void:
		_map = map
		_tile_id = tile_id

		mesh_library = MeshLibrary.new()
		position += Vector3(0, 1, 1) * 0.01 * tile_id
		position += Vector3(0, 0, map._mesh_h / 2)
		position += Vector3(0, -map._mesh_h / 4, -map._mesh_h / 4)
		cell_size = map.cell_size
		cell_center_x = false
		cell_center_y = false
		cell_center_z = false
		map.add_child(self)

class AutoTileDisplay:
	extends Display

	var _passed: Dictionary[Vector3i, bool] = {}
	var _down: Vector3i

	func _bake_pos(pos: Vector3i) -> void:
		if pos in _passed: return
		_passed[pos] = true

		var mask := 0

		# if _down == Vector3i.UP:
		# 	if _map._has_id(pos, _tile_id): mask |= 4
		# 	if _map._has_id(pos + Vector3i.RIGHT, _tile_id): mask |= 8
		# 	if _map._has_id(pos + _down, _tile_id): mask |= 1
		# 	if _map._has_id(pos + _down + Vector3i.RIGHT, _tile_id): mask |= 2
		# else:
		if _map._has_id(pos, _tile_id): mask |= 1
		if _map._has_id(pos + Vector3i.RIGHT, _tile_id): mask |= 2
		if _map._has_id(pos + _down, _tile_id): mask |= 4
		if _map._has_id(pos + _down + Vector3i.RIGHT, _tile_id): mask |= 8

		set_cell_item(pos, mask)

	func bake_reset() -> void:
		clear()
		_passed.clear()
	func bake(pos: Vector3i) -> void:
		_bake_pos(pos)
		_bake_pos(pos - Vector3i.RIGHT)
		_bake_pos(pos - _down)
		_bake_pos(pos - _down - Vector3i.RIGHT)

	func build_reset() -> void:
		mesh_library.clear()
	func build(offset: Vector2i):
		mesh_library.clear()

		for sprite_i in _NEIGHBOR_MAP:
			var sprite_pos := _NEIGHBOR_MAP[sprite_i]
			_map._make_display_mesh_item(mesh_library, sprite_i, offset + sprite_pos * _map.tile_size)

	func render_preview(src: Image, dst: Image, offset: Vector2i) -> void:
		var half_w := _map.tile_size.x >> 1
		var rem_w := _map.tile_size.x - half_w

		# 3 * _map.tile_size.y + half_h

		dst.blend_rect(src, Rect2i(
			Vector2i(1 * _map.tile_size.x + half_w, 0) + offset,
			Vector2i(rem_w, _map.tile_size.y)
		), Vector2i(0, 0))
		dst.blend_rect(src, Rect2i(
			Vector2i(3 * _map.tile_size.x, 2 * _map.tile_size.y) + offset,
			Vector2i(half_w, _map.tile_size.y)
		), Vector2i(rem_w, 0))

	func _init(map: IsoMap25D, tile_id: int) -> void:
		super._init(map, tile_id)

		position += Vector3(map._mesh_w / 2, -map._mesh_h / 2, 0)

		match _map.tiles[tile_id].kind:
			Tile25D.Kind.WALL:
				_down = Vector3i.DOWN
				position += Vector3(0, -map._mesh_h / 2, -map._mesh_h / 2)
			Tile25D.Kind.FLOOR:
				_down = Vector3i.BACK


class SimpleDisplay:
	extends Display

	func bake_reset() -> void:
		clear()
	func bake(pos: Vector3i) -> void:
		set_cell_item(pos, 0)

	func build_reset() -> void:
		mesh_library.clear()
	func build(offset: Vector2i):
		_map._make_display_mesh_item(mesh_library, 0, offset)

	func render_preview(src: Image, dst: Image, offset: Vector2i) -> void:
		dst.blend_rect(src, Rect2i(offset, _map.tile_size), Vector2i.ZERO)

	func _init(map: IsoMap25D, tile_id: int) -> void:
		super._init(map, tile_id)
		position += Vector3(0, -map._mesh_h / 4, -map._mesh_h / 4)

# Maps a mask to its sprite index
# Bits of the values here are as follows:
# & (1 << 0): Top-left
# & (1 << 1): Top-right
# & (1 << 2): Bottom-left
# & (1 << 3): Bottom-right
const _NEIGHBOR_MAP: Dictionary[int, Vector2i] = {
	# 0b0000: Vector2i(0, 3),
	0b0001: Vector2i(3, 3),
	0b0010: Vector2i(0, 2),
	0b0011: Vector2i(1, 2),
	0b0100: Vector2i(0, 0),
	0b0101: Vector2i(3, 2),
	0b0110: Vector2i(2, 3),
	0b0111: Vector2i(3, 1),
	0b1000: Vector2i(1, 3),
	0b1001: Vector2i(0, 1),
	0b1010: Vector2i(1, 0),
	0b1011: Vector2i(2, 2),
	0b1100: Vector2i(3, 0),
	0b1101: Vector2i(2, 0),
	0b1110: Vector2i(1, 1),
	0b1111: Vector2i(2, 1),
}

@export var texture: Texture2D
@export var tile_size := Vector2i(16, 16)
@export var tiles: Array[Tile25D]
@export var shader: Shader
@export var preview: bool:
	set(value):
		if value == preview: return
		preview = value
		_build()

var _material := ShaderMaterial.new()

var _tile_w: int:
	get: return tile_size.x
var _tile_h: int:
	get: return tile_size.y

var _ratio: float:
	get: return float(_tile_w) / _tile_h

var _mesh_w: float:
	get:
		if _ratio < 1: return _ratio
		else: return 1
var _mesh_h: float:
	get:
		if _ratio < 1: return 1.414213562373095
		else: return _ratio * 1.414213562373095


var _displays: Array[Display] = []
# var _auto_tile_displays: Dictionary[int, AutoTileDisplay] = {}
# var _simple_layer := SimpleDisplay.new(self)

var _prev_process := 0.
var _time := 0.

@export_tool_button("Build") var refresh = _build
@export_tool_button("Bake") var bake = _bake

func _make_display_mesh_item(lib: MeshLibrary, slot: int, offset: Vector2i) -> void:
	var arr_mesh = []
	arr_mesh.resize(Mesh.ARRAY_MAX)

	var uva := Vector2(offset) / Vector2(texture.get_size())
	var uvs := Vector2(tile_size) / Vector2(texture.get_size())

	var vs := Vector3(_mesh_w, _mesh_h / 2, _mesh_h / 2)

	arr_mesh[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 3, 0, 2])
	arr_mesh[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(0, 1, 0) * vs,
		Vector3(1, 1, 0) * vs,
		Vector3(1, 0, 1) * vs,
		Vector3(0, 0, 1) * vs,
	])
	arr_mesh[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		# Vector2(0, 1) * uvs + uva,
		# Vector2(1, 1) * uvs + uva,
		# Vector2(1, 0) * uvs + uva,
		# Vector2(0, 0) * uvs + uva,
		Vector2(0, 0) * uvs + uva,
		Vector2(1, 0) * uvs + uva,
		Vector2(1, 1) * uvs + uva,
		Vector2(0, 1) * uvs + uva,
	])

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr_mesh)
	mesh.surface_set_material(0, _material)

	var prev_tex := AtlasTexture.new()
	prev_tex.atlas = texture
	prev_tex.region = Rect2(offset, tile_size)

	lib.create_item(slot)
	lib.set_item_mesh(slot, mesh)
	lib.set_item_preview(slot, prev_tex)
	# self.mesh_library.set_item_shapes(disp_item_id, [BoxShape3D.new(), Transform3D.IDENTITY.scaled(cell_size)])

func _has_id(pos: Vector3i, id: int) -> bool:
	var curr := get_cell_item(pos)

	for i in 64:
		if curr == id: return true
		if curr == INVALID_CELL_ITEM: return false

		curr = tiles[curr].above

	assert(false, "recursion too deep")
	return false

func _build():
	for display in _displays: display.free()
	_displays = []

	if mesh_library == null: mesh_library = MeshLibrary.new()
	else: mesh_library.clear()

	cell_size = Vector3(_mesh_w, _mesh_h, _mesh_h)
	# visible = false

	_material.shader = shader
	_material.set_shader_parameter("tex", texture)

	for tile_id in len(tiles):
		var tile := tiles[tile_id]

		var display: Display

		match tile.kind:
			Tile25D.Kind.FLOOR, Tile25D.Kind.WALL: display = AutoTileDisplay.new(self, tile_id)
			Tile25D.Kind.SIMPLE: display = SimpleDisplay.new(self, tile_id)

		_displays.append(display)

		var pos := tile.offset * tile_size

		display.build(pos)

	var tex_img := texture.get_image()
	tex_img.decompress()

	for tile_id in len(tiles):
		var disp_img := Image.create_empty(tile_size.x, tile_size.y, false, tex_img.get_format())

		var stack: Array[int] = []

		var iter_id := tile_id
		for i in 16:
			if iter_id == INVALID_CELL_ITEM: break
			if iter_id > tile_id: print("illegal layering at ", tile_id)
			stack.append(iter_id)
			iter_id = tiles[iter_id].above

		for i in len(stack):
			var curr_id := stack[len(stack) - i - 1]
			var curr_tile := tiles[curr_id]
			var curr_pos := curr_tile.offset * tile_size
			_displays[curr_id].render_preview(tex_img, disp_img, curr_pos)

		var disp_tex := ImageTexture.new()
		disp_tex.set_image(disp_img)

		var material := StandardMaterial3D.new()
		material.albedo_texture = disp_tex
		material.uv1_scale = Vector3(3, 2, 1)
		material.transparency = BaseMaterial3D.Transparency.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

		var disp_mesh := BoxMesh.new()
		disp_mesh.size = Vector3(_mesh_w, _mesh_h, _mesh_h)
		disp_mesh.material = material

		mesh_library.create_item(tile_id)
		if preview: mesh_library.set_item_mesh(tile_id, disp_mesh)
		mesh_library.set_item_preview(tile_id, disp_tex)

	_bake()

func _bake_pos(pos: Vector3i, id: int):
	_displays[id].bake(pos)
func _bake():
	for display in _displays: display.bake_reset()

	for pos in self.get_used_cells():
		var curr := get_cell_item(pos)
		for i in 64:
			if curr == INVALID_CELL_ITEM: break
			_displays[curr].bake(pos)
			curr = tiles[curr].above

func _process(delta: float) -> void:
	_time += delta
	if _time - _prev_process < .1: return
	_prev_process = _time

	_bake()
	pass
func _ready() -> void:
	_build()
	_bake()
