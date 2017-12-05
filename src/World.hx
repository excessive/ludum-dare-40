import systems.*;
import math.*;
import components.Drawable.CollisionType;
import components.Player;
import love.filesystem.FilesystemModule as Fs;
import utils.Assert.assert;

import Profiler.SegmentColor;

class VirtualTile {
	public var world_tile: WorldTile;
	public var x: Int;
	public var y: Int;

	public function new(base, x, y) {
		this.world_tile = base;
		this.x = x;
		this.y = y;
	}

	public inline function offset(): Vec3 {
		var scale = World.tile_size;
		return new Vec3(scale*x, scale*y, 0.0);
	}

	public inline function offset_from(other: VirtualTile): Vec3 {
		var scale = World.tile_size;
		return new Vec3(scale*(x - other.x), scale*(y - other.y), 0.0);
	}

	public function get_triangles(min: Vec3, max: Vec3): Array<Triangle> {
		var push = this.offset();
		var tris = world_tile.get_triangles(min - push, max - push);
		var final_tris = [];
		for (tri in tris) {
			var t = new Triangle(
				tri.v0 + push,
				tri.v1 + push,
				tri.v2 + push,
				tri.vn
			);
			final_tris.push(t);
		}

		return final_tris;
	}

	public static function from_real(tile: WorldTile) {
		return new VirtualTile(tile, tile.x, tile.y);
	}
}

class WorldTile {
	var tri_octree: Octree<Triangle>;
	public var entities: Array<Entity>;

	public var x: Int;
	public var y: Int;

	static var octree_looseness = 1.0;

	public var filename: String;

	public function new(_x: Int, _y: Int) {
		var mid = new Vec3(World.tile_size/2, World.tile_size/2, World.tile_size/2);
		tri_octree = new Octree(World.tile_size, mid, 2.0, octree_looseness);
		entities = [];
		x = _x;
		y = _y;

		filename = 'assets/maps/zones/tile_${x}x${y}.fresh';
	}

	public function get_triangles(min: Vec3, max: Vec3): Array<Triangle> {
		var size = max - min;
		var center = min + size / 2;
		var tris = tri_octree.get_colliding(new Bounds(center, size));

		return tris;
	}

	public function get_triangles_frustum(frustum: Frustum): Array<Triangle> {
		return tri_octree.get_colliding_frustum(frustum);
	}

	public function add_triangle(xt: Triangle) {
		var min = xt.min();
		var max = xt.max();
		tri_octree.add(xt, Bounds.from_extents(min, max));
	}

	// TODO: fix casting ray across tiles
	function cast_ray(ray: Ray, fn: Vec3->Void) {
		tri_octree.cast_ray(ray, function(r, entries) {
			for (entry in entries) {
				if (Intersect.ray_aabb(ray, entry.bounds) != null) {
					var hit = Intersect.ray_triangle(ray, entry.data);
					if (hit != null) {
						fn(hit.point);
					}
				}
			}
			return false;
		});
	}

	public function nearest_hit(ray: Ray): Null<{triangle: Triangle, point: Vec3, distance: Float}> {
		var nearest: Float = 1e20;
		var closest_tri: Null<Triangle> = null;
		var closest_hit: Null<Vec3> = null;
		tri_octree.cast_ray(ray, function(r, entries) {
			for (entry in entries) {
				if (Intersect.ray_aabb(ray, entry.bounds) != null) {
					var hit = Intersect.ray_triangle(ray, entry.data);
					if (hit != null) {
						var d = Vec3.distance(ray.position, hit.point);
						if (d < nearest) {
							nearest = d;
							closest_tri = entry.data;
							closest_hit = hit.point;
						}
					}
				}
			}
			return false;
		});

		if (closest_hit == null || closest_tri == null) {
			return null;
		}

		return {
			distance: nearest,
			triangle: closest_tri,
			point: closest_hit
		};
	}
}

class World {
	// TODO: move this elsewhere
	static var player: Player;

	static var entities: Array<Entity>;
	static var systems: Array<System>;

	static var path: String = "assets/maps/world.fresh";
	static var is_local_map: Bool = false;

	public static var kill_z: Float = -21;
	public static var tiles_x: Int = 10;
	public static var tiles_y: Int = 5;
	public static var tile_size: Int = 100;

	// only exposed so the editor can use it, do not use otherwise
	public static var tiles: Array<WorldTile>;

	public static function tile_at(world_pos: Vec3): WorldTile {
		var xw = world_pos.x % (tiles_x * tile_size);
		var yw = world_pos.y % (tiles_y * tile_size);

		var x = Std.int(xw / tile_size);
		var y = Std.int(yw / tile_size);

		var idx = y * tiles_x + x;

		assert(tiles[idx] != null, "invalid tile");

		return tiles[idx];
	}

	public static function virtual_tile_at(world_pos: Vec3): VirtualTile {
		var x = Math.floor(world_pos.x / tile_size);
		var y = Math.floor(world_pos.y / tile_size);
		var real = tile_at(world_pos);
		return new VirtualTile(real, x, y);
	}

	public static function to_local(world_pos: Vec3) {
		return new Vec3(
			Utils.wrap(world_pos.x, World.tile_size),
			Utils.wrap(world_pos.y, World.tile_size),
			world_pos.z
		);
	}

	public static function to_world(local_pos: Vec3, tile_x: Int, tile_y: Int): Vec3 {
		return new Vec3(
			local_pos.x + tile_x * tile_size,
			local_pos.y + tile_y * tile_size,
			local_pos.z
		);
	}

	// TODO: multiple tiles
	public static function nearest_hit(ray: Ray): Null<{triangle: Triangle, point: Vec3, distance: Float}> {
		var tile = tile_at(ray.position);
		var local_ray = new Ray(to_local(ray.position), ray.direction);
		return tile.nearest_hit(local_ray);
	}

	public static function is_local() {
		return is_local_map;
	}

	static var movement: Movement;

	public static function init(p: Player) {
		player = p;
		movement = new Movement(true);

		tiles = [];
		var n = tiles_x*tiles_y;
		for (i in 0...n) {
			var x: Int = i % World.tiles_x;
			var y: Int = Std.int(i / World.tiles_x);
			tiles.push(new WorldTile(x, y));
		}

		// NOTE: As of Haxe 3.4.2, with the Lua target it's unreliable to ref
		// these as static members of the classes as { filter: Foo.filter, ... }.
		// see this bug: https://github.com/HaxeFoundation/haxe/issues/6368
		systems = [
			new Loader(),
			p,
			new PlayerController(true),
			movement,
			new Animation(),
			new Trigger(true),
			new Audio(),
			new Hud(),
			new Render(),
			new WeatherSystem()
		];

		Trigger.register_signals();
	}

	public static function get_adjacent_tiles(center: Vec3): Array<VirtualTile> {
		var origin_tile = World.virtual_tile_at(center);
		var half_tile = new Vec3(World.tile_size/2, World.tile_size/2, 0);
		var t_min = center - half_tile;
		var t_max = center + half_tile;
		var adjacent_tiles = [
			origin_tile,
			virtual_tile_at(new Vec3(center.x, t_min.y, 0.0)),
			virtual_tile_at(new Vec3(center.x, t_max.y, 0.0)),
			virtual_tile_at(new Vec3(t_min.x, center.y, 0.0)),
			virtual_tile_at(new Vec3(t_max.x, center.y, 0.0)),
			virtual_tile_at(new Vec3(t_min.x, t_min.y, 0.0)),
			virtual_tile_at(new Vec3(t_min.x, t_max.y, 0.0)),
			virtual_tile_at(new Vec3(t_max.x, t_min.y, 0.0)),
			virtual_tile_at(new Vec3(t_max.x, t_max.y, 0.0))
		];
		var unique_tiles: Array<VirtualTile> = [];

		for (t in adjacent_tiles) {
			var found = false;
			for (unique in unique_tiles) {
				if (t.x == unique.x && t.y == unique.y) {
					found = true;
					break;
				}
			}
			if (!found) {
				unique_tiles.push(t);
			}
		}
		return unique_tiles;
	}

	public static function get_triangles(min: Vec3, max: Vec3): Array<Triangle> {
		var size = max - min;
		var center = min + size / 2;
		var tris = [];
		var nearby = get_adjacent_tiles(center);

		var half_tile = new Vec3(World.tile_size/2, World.tile_size/2, 100);
		for (t in nearby) {
			// tile boundaries
			// var _min = new Vec3(0, 0, center.z - 5) + t.offset();
			// var _max = new Vec3(World.tile_size, World.tile_size, center.z + 5) + t.offset();
			// Debug.aabb(_min, _max, 0, 0, 1);

			var tile_tris = t.get_triangles(min, max);
			for (tri in tile_tris) {
				// Debug.triangle(tri, 1, 0, 1);
				tris.push(tri);
			}
		}
		return tris;
	}

	public static var visible_tiles: Array<VirtualTile> = [];
	public static function get_triangles_frustum(frustum: Frustum): Array<Triangle> {
		var tris = [];
		for (vtile in visible_tiles) {
			var tile = vtile.world_tile;

			// BUG: frustum isn't in the same coordinate space
			// TODO: don't use every triangle in a tile for this
			// var tmp_tris = tile.get_triangles_frustum(frustum);
			var tmp_tris = tile.get_triangles(new Vec3(0, 0, -1000), new Vec3(tile_size, tile_size, 1000));
			for (t in tmp_tris) {
				tris.push(new Triangle(
					to_world(t.v0, vtile.x, vtile.y),
					to_world(t.v1, vtile.x, vtile.y),
					to_world(t.v2, vtile.x, vtile.y),
					t.vn
				));
			}
		}
		return tris;
	}

	// TODO: handle triangles which span n>1 tiles
	public static function add_triangles(tile: WorldTile, xform: Mat4, tris: Array<Triangle>) {
		for (t in tris) {
			var xt = new Triangle(
				xform * t.v0,
				xform * t.v1,
				xform * t.v2,
				xform * t.vn
			);
			var min = xt.min();
			var max = xt.max();
			tile.add_triangle(xt);
		}
	}

	public static function new_entities(new_path: String, new_entities: Array<Entity>) {
		entities = new_entities;
		path = new_path;

		is_local_map = Fs.getRealDirectory(path).indexOf(Fs.getSaveDirectory()) >= 0;
		rebuild_octree();
	}

	public static function reload() {
		Zone.load(path);
	}

	public static function rebuild_octree() {
		// wipe octree, reload relevant models...
		for (e in entities) {
			if (e.drawable == null || e.transform == null) {
				continue;
			}
			if (e.drawable.collision == CollisionType.Triangle) {
				e.drawable.mesh = null;
			}
		}
	}

	public static function save() {
		Zone.save(path);
		is_local_map = Fs.getRealDirectory(path).indexOf(Fs.getSaveDirectory()) >= 0;

		rebuild_octree();
	}

	public static function refresh_entity(old_tile: WorldTile, new_tile: WorldTile, e: Entity, add: Bool) {
		if (!add) {
			// tiles need a map for the entity list to do this fast
			// ...probably
			old_tile.entities.remove(e);
		}
		new_tile.entities.push(e);
	}

	public static inline function add(to_add: Entity) {
		entities.push(to_add);
	}

	public static function remove(to_remove: Entity) {
		entities.remove(to_remove);
		var d = to_remove.drawable;
		if (to_remove.transform != null && d != null && d.mesh != null) {
			// tiles need a map for the entity list to do this fast
			var tile = tile_at(to_remove.transform.as_absolute());
			tile.entities.remove(to_remove);
			movement.remove(to_remove);
		}
	}

	public static function get_tile(x: Float, y: Float): WorldTile {
		var tx = Math.floor(x);
		var ty = Math.floor(y);
		assert(tx >= 0 && ty >= 0 && tx < tiles_x && ty < tiles_y, "Invalid tile index");
		var idx = ty * tiles_x + tx;
		assert(tiles[idx] != null, "Invalid tile for valid index");
		return tiles[idx];
	}

	static function render_triangle(frustum, vis_tiles: Array<VirtualTile>, mx: Float, my: Float, w: Float, h: Float, x0: Float, y0: Float, x1: Float, y1: Float, x2: Float, y2: Float) {
		// calculate working area
		var minimum_x = Math.floor(Utils.min(Utils.min(x0, x1), x2));
		var minimum_y = Math.floor(Utils.min(Utils.min(y0, y1), y2));
		var maximum_x = Math.ceil(Utils.max(Utils.max(x0, x1), x2));
		var maximum_y = Math.ceil(Utils.max(Utils.max(y0, y1), y2));

		// rasterize
		for (y in minimum_y...maximum_y) {
			for (x in minimum_x...maximum_x) {
				// determine barycentric coordinates
				var w0 = (x2 - x1) * (y - y1) - (y2 - y1) * (x - x1);
				var w1 = (x0 - x2) * (y - y2) - (y0 - y2) * (x - x2);
				var w2 = (x1 - x0) * (y - y0) - (y1 - y0) * (x - x0);

				// disabled until we can do conservative rasterization
				if (w0 >= 0 && w1 >= 0 && w2 >= 0) {
					var vx = Math.floor(mx+x);
					var vy = Math.floor(my+y);
					inline function wrap(v: Float, limit: Float): Int {
						return Math.floor(Utils.wrap(v, limit));
					}
					var tx = wrap(vx, tiles_x);
					var ty = wrap(vy, tiles_y);
					var tile = get_tile(tx, ty);

					var min = new Vec3(vx * tile_size, vy * tile_size, -1000);
					var max = new Vec3(min.x + tile_size, min.y + tile_size, 1000);
					if (Intersect.aabb_frustum(Bounds.from_extents(min, max), frustum)) {
						vis_tiles.push(new VirtualTile(tile, vx, vy));
					}
				}
			}
		}
	}

	public static function update_visible(world_tri: Triangle, frustum: Frustum) {
		visible_tiles = [];

		// offset to align pixel centers to corners
		var offset = new Vec3(-0.5, -0.5, 0) * 0;
		var tile_tri = new Triangle(
			world_tri.v0 / World.tile_size + offset,
			world_tri.v1 / World.tile_size + offset,
			world_tri.v2 / World.tile_size + offset,
			world_tri.vn
		);

		// ghetto approximation of conservative rasterization
		var center = tile_tri.v0 + tile_tri.v1 + tile_tri.v2;
		center /= 3;
		var expand = 2.5;
		tile_tri.v0 = center + (tile_tri.v0 - center) * expand;
		tile_tri.v1 = center + (tile_tri.v1 - center) * expand;
		tile_tri.v2 = center + (tile_tri.v2 - center) * expand;

		var min = tile_tri.min();
		var max = tile_tri.max();

		var w = max.x - min.x;
		var h = max.y - min.y;

		render_triangle(
			frustum,
			visible_tiles,
			min.x, min.y,
			w, h,
			tile_tri.v0.x - min.x, tile_tri.v0.y - min.y,
			tile_tri.v1.x - min.x, tile_tri.v1.y - min.y,
			tile_tri.v2.x - min.x, tile_tri.v2.y - min.y
		);

		var tile_over = tile_at(Render.camera.position);
		var found = false;

		for (vt in visible_tiles) {
			if (vt.world_tile == tile_over) {
				found = true;
				break;
			}
		}

		if (!found) {
			visible_tiles.push(new VirtualTile(tile_over, tile_over.x, tile_over.y));
		}

		// imgui.Widget.value("vis tiles", visible_tiles.length);
	}

	public static function filter(only_visible: Bool, fn: Entity->Bool): Array<Entity> {
		var relevant = [];
		assert(only_visible == false, "only visible is nyi");

		var set = entities;
		// var set = only_visible ? visible_entities : entities;
		for (entity in set) {
			if (fn(entity)) {
				relevant.push(entity);
			}
		}
		return relevant;
	}

	static var borked: Array<Dynamic> = [];
	static var current_bork: Dynamic = null;

	public static var time:     Float = 0;
	public static var tickrate: Float = 1 / 120;

	static function update_systems(systems: Array<System>, dt: Float) {
		function log(err) {
			if (borked.indexOf(current_bork) >= 0) {
				return;
			}

			borked.push(current_bork);
			Log.write(Log.Level.System, "Error: " + err);
		}

		for (system in systems) {
			var relevant = [];
			Profiler.push_block(system.PROFILE_NAME, system.PROFILE_COLOR);

			for (entity in entities) {
				if (system.filter(entity)) {
					relevant.push(entity);

					if (system.process != null) {
						current_bork = system.process;
						try {
							system.process(entity, dt);
						}
						catch(err: String) {
							log(err);
						}
					}
				}
			}

			if (system.update != null) {
				current_bork = system.update;
				try {
					system.update(relevant, dt);
				}
				catch (err: String) {
					log(err);
				}
			}

			Profiler.pop_block();
		}
	}

	public static function update(dt: Float) {
		Profiler.push_block("world update", SegmentColor.World);

		time += dt;

		var variable = systems.filter(function(s) return !s.fixed_tick);
		var fixed = systems.filter(function(s) return s.fixed_tick);

		while (time >= tickrate) {
			time -= tickrate;
			if (time / tickrate > 1) {
				// imgui.ImGui.new_frame();
				// Debug.draw(true);
			}
			update_systems(fixed, tickrate);
		}

		update_systems(variable, dt);

		Profiler.pop_block();
	}
}
