class_name SpatialHashGrid
extends RefCounted

const CELL_SIZE := 2.5
var _cells: Dictionary = {}

func clear() -> void:
	_cells.clear()

func _key(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor(x / CELL_SIZE)), int(floor(z / CELL_SIZE)))

func insert(pos: Vector3, item) -> void:
	var k := _key(pos.x, pos.z)
	if not _cells.has(k):
		_cells[k] = [item]
	else:
		(_cells[k] as Array).append(item)

func query_radius(pos: Vector3, radius: float) -> Array:
	var result: Array = []
	var r_cells := int(ceil(radius / CELL_SIZE))
	var center := _key(pos.x, pos.z)
	for dx in range(-r_cells, r_cells + 1):
		for dz in range(-r_cells, r_cells + 1):
			var k := Vector2i(center.x + dx, center.y + dz)
			if _cells.has(k):
				result.append_array(_cells[k])
	return result
