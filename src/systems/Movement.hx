package systems;

import math.Vec3;
import math.Mat4;
import math.Bounds;
import World.WorldTile;

@:publicFields
class Movement extends System {
	override function filter(e: Entity) {
		if (e.transform != null && !e.transform.is_static) {
			return true;
		}
		return false;
	}

	var cached = new Map<Entity, Mat4>();

	function remove(e) {
		cached.remove(e);
	}

	function update_cache(e: Entity, last_tile: WorldTile) {
		var d = e.drawable;
		var mtx = e.transform.mtx;
		var add = false;
		if (!cached.exists(e)) {
			cached[e] = mtx.copy();
			add = true;
		}
		else if (cached[e].equal(mtx)) {
			return;
		}
		else {
			cached[e] = mtx.copy();
		}
		// var bounds = d.mesh.bounds.base;
		// var min = new Vec3(bounds.min.x, bounds.min.y, bounds.min.z);
		// var max = new Vec3(bounds.max.x, bounds.max.y, bounds.max.z);
		// var xform_bounds = math.Utils.rotate_bounds(mtx, min, max);
		var current_tile = World.get_tile(e.transform.tile_x, e.transform.tile_y);
		if (last_tile != current_tile || add) {
			World.refresh_entity(last_tile, current_tile, e, add);
		}
		// World.refresh_entity(e, Bounds.from_extents(xform_bounds.min, xform_bounds.max), add);
	}

	override function process(e: Entity, dt: Float) {
		if (e.transform.velocity.lengthsq() > 0) {
			e.transform.position += e.transform.velocity * dt;
			if (e.player == null) {
				e.transform.velocity = e.transform.velocity.scale(0);
			}
		}

		// make sure this is stored before calling transform.update
		var old_tile = World.get_tile(e.transform.tile_x, e.transform.tile_y);
		e.transform.update();

		if (e.camera != null) {
			e.camera.position = e.transform.as_absolute();
		}

		var d = e.drawable;
		if (d != null && d.mesh != null) {
			update_cache(e, old_tile);
		}
	}
}
