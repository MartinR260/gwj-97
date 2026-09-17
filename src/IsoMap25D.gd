@tool

class_name IsoMap25D
extends GridMap

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
const _DOWN_MAP: Dictionary[Tile25D.Kind, Vector3i] = {
	Tile25D.Kind.FLOOR: Vector3i.FORWARD,
	Tile25D.Kind.WALL: Vector3i.DOWN,
}

@export var texture: Texture2D
@export var tile_size := Vector2i(16, 16)
@export var tiles: Array[Tile25D]
@export var shader: Shader

var _tile_w: int:
	get: return tile_size.x
var _tile_h: int:
	get: return tile_size.y

var _half_w: int:
	get: return tile_size.x >> 1
var _half_h: int:
	get: return tile_size.y >> 1

var _rem_w: int:
	get: return _tile_w - _half_w
# Pythagorean theorem, solving for c=1 and a=b (aka a^2 + b^2 = 1)
# This ensures the tile retains its proportions, even though it is a diagonal rectangle
var _rem_h: int:
	get: return _tile_h - _half_h

var _ratio: float:
	get: return float(_tile_w) / _tile_h

var _mesh_w: float:
	get:
		if _ratio < 1: return _ratio
		else: return 1
var _mesh_h: float:
	get:
		if _ratio < 1: return 0.7071067811865475
		else: return _ratio * 0.7071067811865475


var _id_to_data: Dictionary[int, Tile25D] = {}
var _real_mesh_lib := MeshLibrary.new()
# var _real_grid := GridMap.new()

@export_tool_button("Refresh") var refresh = _rebuild_libs
@export_tool_button("Bake") var bake = _bake

# Map of grid IDs to a bunch of bs

func _get_kind(pos: Vector3i) -> Tile25D:
	var mesh_cell := get_cell_item(pos)
	if mesh_cell == INVALID_CELL_ITEM: return null
	return _id_to_data[mesh_cell]

class TiledGrid:
	extends GridMap
	var _map: IsoMap25D
	var _us: int
	var _passed: Dictionary[Vector3i, bool] = {}

	func bake_pos(pos: Vector3i, down: Vector3i, us: Tile25D) -> void:
		if pos in _passed: return
		_passed[pos] = true

		var ul: Tile25D = _map._get_kind(pos)
		var ur: Tile25D = _map._get_kind(pos + Vector3i.RIGHT)
		var bl: Tile25D = _map._get_kind(pos + down)
		var br: Tile25D = _map._get_kind(pos + Vector3i.RIGHT + down)

		var mask := 0
		if ul != null && _us == ul.tile_id.x: mask |= 1
		if ur != null && _us == ur.tile_id.x: mask |= 2
		if bl != null && _us == bl.tile_id.x: mask |= 4
		if br != null && _us == br.tile_id.x: mask |= 8

		set_cell_item(pos, us.real[mask])

	func reset() -> void:
		clear()
		_passed.clear()

	func _init(map: IsoMap25D, us: Tile25D) -> void:
		mesh_library = map._real_mesh_lib
		position = Vector3(map._mesh_w / 2, -map._mesh_h / 2, -map._mesh_h)
		cell_size = Vector3(map._mesh_w, map._mesh_h, map._mesh_h * 2)
		map.add_child(self)

		_map = map
		_us = us.tile_id.x

func _rebuild_libs():
	if mesh_library == null: mesh_library = MeshLibrary.new()

	# var dummy_mesh := ImmediateMesh.new()

	mesh_library.clear()
	_real_mesh_lib.clear()

	var tex_img := texture.get_image()
	tex_img.decompress()

	cell_size = Vector3(_mesh_w, _mesh_h, _mesh_h * 2)
	# visible = false

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tex", texture)

	for tile_idx in len(tiles):
		var tile := tiles[tile_idx]

		for variant_idx in len(tile.variants):
			var variant_id := tile.variants[variant_idx]

			var p := variant_id * tile_size * 4

			# Takes the four corners that makes a all-air bordering tile and puts it in one texture
			# Rather inefficient, but has to be done exactly once, so leave me alone!!
			var disp_img := Image.create_empty(_tile_w, _tile_h, false, tex_img.get_format())

			disp_img.blit_rect(tex_img, Rect2i(
				Vector2i(p.x + 1 * _tile_w + _half_w, p.y + 3 * _tile_h + _half_h),
				Vector2i(_rem_w, _rem_h)
			), Vector2i(0, 0))
			disp_img.blit_rect(tex_img, Rect2i(
				Vector2i(p.x + 0, p.y + _half_h),
				Vector2i(_half_w, _rem_h)
			), Vector2i(_rem_w, 0))
			disp_img.blit_rect(tex_img, Rect2i(
				Vector2i(p.x + _half_w, p.y + 2 * _tile_h),
				Vector2i(_rem_w, _half_h)
			), Vector2i(0, _rem_h))
			disp_img.blit_rect(tex_img, Rect2i(
				Vector2i(p.x + 3 * _tile_w, p.y + 3 * _tile_h),
				Vector2i(_half_w, _half_h)
			), Vector2i(_rem_w, _rem_h))

			var disp_tex := ImageTexture.new()
			disp_tex.set_image(disp_img)

			var disp_mesh := BoxMesh.new()
			disp_mesh.size = Vector3i.ZERO

			var disp_item_id := mesh_library.get_last_unused_item_id()
			mesh_library.create_item(disp_item_id)
			mesh_library.set_item_mesh(disp_item_id, disp_mesh)
			mesh_library.set_item_preview(disp_item_id, disp_tex)

			_id_to_data[disp_item_id] = Tile25D.new()
			_id_to_data[disp_item_id].tile_id = Vector2i(tile_idx, variant_idx)
			_id_to_data[disp_item_id].meta = tile
			_id_to_data[disp_item_id].real = []
			_id_to_data[disp_item_id].real.resize(16)

			for sprite_i in _NEIGHBOR_MAP:
				var sprite_pos := _NEIGHBOR_MAP[sprite_i]
				# material.ao_enabled = false
				# material.rim_enabled = false
				# material.detail_enabled = false
				# material.normal_enabled = false
				# material.emission_enabled = false
				# material.emission_enabled = false

				var arr_mesh = []
				arr_mesh.resize(Mesh.ARRAY_MAX)

				var uva := Vector2(p + sprite_pos * tile_size) / Vector2(texture.get_size())
				var uvs := Vector2(tile_size) / Vector2(texture.get_size())

				arr_mesh[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 3, 0, 2])
				arr_mesh[Mesh.ARRAY_VERTEX] = PackedVector3Array([
					Vector3(-self._mesh_w / 2, -self._mesh_h / 2, -self._mesh_h / 2),
					Vector3(self._mesh_w / 2, -self._mesh_h / 2, -self._mesh_h / 2),
					Vector3(self._mesh_w / 2, self._mesh_h / 2, self._mesh_h / 2),
					Vector3(-self._mesh_w / 2, self._mesh_h / 2, self._mesh_h / 2)
				])
				arr_mesh[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
					Vector2(0, 1) * uvs + uva,
					Vector2(1, 1) * uvs + uva,
					Vector2(1, 0) * uvs + uva,
					Vector2(0, 0) * uvs + uva
				])

				var mesh := ArrayMesh.new()
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr_mesh)
				mesh.surface_set_material(0, material.duplicate())

				var preview := AtlasTexture.new()
				preview.atlas = texture
				preview.region = Rect2(p + sprite_pos * tile_size, tile_size)

				var real_item_id := _real_mesh_lib.get_last_unused_item_id()
				_real_mesh_lib.create_item(real_item_id)
				_real_mesh_lib.set_item_mesh(real_item_id, mesh)
				_real_mesh_lib.set_item_preview(real_item_id, preview)
				_id_to_data[disp_item_id].real[sprite_i] = real_item_id
				# self.mesh_library.set_item_shapes(disp_item_id, [BoxShape3D.new(), Transform3D.IDENTITY.scaled(cell_size)])

	_bake()

var _layers: Dictionary[int, TiledGrid] = {}

func _get_layer(us: Tile25D) -> TiledGrid:
	if us.tile_id.x in _layers: return _layers[us.tile_id.x]
	print("MAKE GRID FOR ", us.tile_id.x)

	var res := TiledGrid.new(self, us)
	_layers[us.tile_id.x] = (res)
	return res

func _bake_pos(us: Tile25D, down: Vector3i, pos: Vector3i) -> void:
	_get_layer(us).bake_pos(pos, down, us)

func _bake():
	for id in _layers: _layers[id].reset()

	for us_pos in self.get_used_cells():
		var us := _get_kind(us_pos)
		var down := _DOWN_MAP[us.meta.orientation]
		_bake_pos(us, down, us_pos)
		_bake_pos(us, down, us_pos - Vector3i.RIGHT)
		_bake_pos(us, down, us_pos - down)
		_bake_pos(us, down, us_pos - down - Vector3i.RIGHT)

var _prev_process := 0.
var _time := 0.

func _process(delta: float) -> void:
	_time += delta
	if _time - _prev_process < .1: return
	_prev_process = _time

	_bake()
	pass

func _ready() -> void:
	_rebuild_libs()
	_bake()
