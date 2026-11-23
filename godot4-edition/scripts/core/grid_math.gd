class_name GridMath
extends RefCounted

const TILE: float = 48.0
const VIEWPORT_W: float = 960.0
const VIEWPORT_H: float = 540.0
const WORLD_ORIGIN_Y: float = 468.0

static func gx_to_px(gx: float) -> float:
	return gx * TILE

static func px_to_gx(px: float) -> float:
	return px / TILE

static func gy_to_py(gy: float, h_tiles: float = 0.0) -> float:
	return WORLD_ORIGIN_Y - (gy + h_tiles) * TILE

static func py_to_gy(py: float, h_tiles: float = 0.0) -> float:
	return (WORLD_ORIGIN_Y - py) / TILE - h_tiles

static func aabb_overlap(a: Rect2, b: Rect2) -> bool:
	return (
		a.position.x < b.position.x + b.size.x
		and a.position.x + a.size.x > b.position.x
		and a.position.y < b.position.y + b.size.y
		and a.position.y + a.size.y > b.position.y
	)
