import haxe.Json;
import love.filesystem.FilesystemModule as Fs;
import components.Transform;
import components.Rail;
import editor.Prefab;
import math.Vec3;
import math.Mat4;
import math.Quat;

import World.WorldTile;

import components.Drawable;
import components.Drawable.CollisionType;
//import components.Drawable.ShaderType;
import components.Trigger;

import love.image.ImageModule as Li;

typedef TileData = {
	var x: Int;
	var y: Int;
	var entities: Array<{
		id:        Int,
		collision: Int,
		model:     String,
		pos:       Array<Float>,
		rot:       Array<Float>,
		scale:     Array<Float>,
		rails:     Array<Array<Float>>,
		trigger:   { cb: String, type: Int, range: Float, max_angle: Float, enabled: Bool },
		prefab:    String
		// sounds: Array<String>
	}>;
}

typedef ZoneData = {
	var version: Int;
	var tiles: Array<TileData>;
}

typedef WorldData = {
	var version: Int;
	// var height_map: String;
	// var height_scale: Int;
	var maps: Array<String>; // paths of tile data files
}

class Zone {
	static var map_version: Int = 1;

	static function load_tile(entities: Array<Entity>, data: TileData) {
		var start = entities.length;

		var max_id: Int = 0;
		max_id = Std.int(Math.max(max_id, data.entities.length));
		// max_id = Std.int(Math.max(max_id, data.spawns.length));
		for (i in 0...max_id) {
			entities.push({});
		}

		var rails: Array<Rail> = [];

		for (entity in data.entities) {
			var target = entities[entity.id+start];

			var is_static = true; // later: store this in data
			var tx = new Transform(
				new Vec3(entity.pos[0], entity.pos[1], entity.pos[2]),
				new Vec3(),
				new Quat(entity.rot[0], entity.rot[1], entity.rot[2], entity.rot[3]),
				new Vec3(entity.scale[0], entity.scale[1], entity.scale[2]),
				is_static
			);
			tx.orientation.normalize();
			tx.tile_x = data.x;
			tx.tile_y = data.y;
			tx.update();
			target.transform = tx;

			if (entity.rails.length > 0) {
				target.rails = [];

				// Create rails
				for (rail in entity.rails) {
					var start = tx.mtx * new Vec3(rail[0], rail[1], rail[2]);
					var end   = tx.mtx * new Vec3(rail[3], rail[4], rail[5]);
					var r     = new Rail(start, end, tx.mtx);
					target.rails.push(r);
					rails.push(r);
				}
			}

			// Connect rails together
			var threshold = 0.0125;
			for (k in rails) {
				for (i in rails) {
					if (k == i) { continue; }

					if (Vec3.distance(k.capsule.a, i.capsule.a) < threshold || Vec3.distance(k.capsule.a, i.capsule.b) < threshold) {
						k.prev = i;
					}

					if (Vec3.distance(k.capsule.b, i.capsule.a) < threshold || Vec3.distance(k.capsule.b, i.capsule.b) < threshold) {
						k.next = i;
					}
				}
			}

			var collidable = CollisionType.createByIndex(entity.collision);
			//var shader = ShaderType.Basic;

			if (entity.model.length != 0) {
				target.drawable = new Drawable(entity.model, collidable, Basic);
			}

			if (entity.trigger != null) {
				target.trigger = new Trigger(entity.trigger.cb, TriggerType.createByIndex(entity.trigger.type), entity.trigger.range, entity.trigger.max_angle, entity.trigger.enabled);
			}

			World.add(target);
			World.refresh_entity(null, World.get_tile(data.x, data.y), target, true);
		}
	}

	static function load_map(data: ZoneData, filename: String) {
		var entities: Array<Entity> = [];
		for (tile in data.tiles) {
			var real = World.get_tile(tile.x, tile.y);
			real.filename = filename;
			load_tile(entities, tile);
		}
	}

	static function load_world(data: WorldData) {
		for (map in data.maps) {
			var saved = Fs.read(map);
			var data: ZoneData = Json.parse(saved.contents);
			load_map(data, map);
		}
	}

	public static var HEIGHTMAP_TILE = "<heightmap>";

	public static function load(path: String) {
		var tx = World.tiles_x;
		var ty = World.tiles_y;
		//var ts = World.tile_size;
		var n = tx*ty;
		var tiles: Array<Entity> = [];

		var tex = Li.newImageData("assets/textures/heightmap_2x1.png");

		inline function tile_entity(x: Int, y: Int, height: Float): Entity {
			var tx = new Transform(new Vec3(0, 0, height), new Vec3(), new Quat(), new Vec3(1, 1, 1), true);
			tx.tile_x = x;
			tx.tile_y = y;
			tx.update();

			var d = new components.Drawable(HEIGHTMAP_TILE, None);
			d.mesh = editor.HeightmapTerrain.generate_tile(tex, Mat4.translate(tx.position), tx.tile_x, tx.tile_y);
			d.shader = Terrain;

			return {
				transform: tx,
				drawable: d
			};
		}

		for (i in 0...n) {
			var x = i % World.tiles_x;
			var y = Std.int(i / World.tiles_x);
			var e = tile_entity(x, y, -30);
			tiles.push(e);
			World.refresh_entity(null, World.get_tile(x, y), e, true);
		}

		World.new_entities(path, tiles);

		var saved = Fs.read(path);
		if (saved.contents != null) {
			var data: WorldData = Json.parse(saved.contents);
			load_world(data);
		}
	}

	static function save_zone(tiles: Array<WorldTile>, filename: String) {
		var data: ZoneData = {
			version: map_version,
			tiles: []
		};

		for (tile in tiles) {
			var tdata: TileData = {
				x: tile.x,
				y: tile.y,
				entities: [],
			};

			var id = 0;

			for (e in tile.entities) {
				// skip the player and enemy entities, we don't want doppelgangers
				if (e.player != null) {
					continue;
				}

				if (e.drawable != null && e.drawable.filename == HEIGHTMAP_TILE) {
					continue;
				}

				if (e.transform != null) {
					var _pos = e.transform.position;
					var _rot = e.transform.orientation;
					var _sca = e.transform.scale;
					var mesh = "";
					var coll = CollisionType.None;
					var rail_data: Array<Array<Float>> = [];
					var trigger = null;

					if (e.drawable != null) {
						mesh = e.drawable.filename;
						coll = e.drawable.collision;
					}

					if (e.rails != null) {
						var inv = e.transform.mtx.copy();
						inv.invert();
						for (rail in e.rails) {
							var start = inv * rail.capsule.a;
							var end = inv * rail.capsule.b;
							rail_data.push([
								start.x, start.y, start.z,
								end.x, end.y, end.z
							]);
						}
					}

					if (e.trigger != null) {
						trigger = {
							cb:        e.trigger.cb,
							type:      e.trigger.type.getIndex(),
							range:     e.trigger.range,
							max_angle: e.trigger.max_angle,
							enabled:   e.trigger.enabled
						};
					}

					tdata.entities.push({
						id:        id,
						model:     mesh,
						collision: coll.getIndex(),
						pos:       [ _pos[0], _pos[1], _pos[2] ],
						rot:       [ _rot[0], _rot[1], _rot[2], _rot[3] ],
						scale:     [ _sca[0], _sca[1], _sca[2] ],
						rails:     rail_data,
						trigger:   trigger,
						prefab:    e.prefab_path
					});
				}

				id += 1;
			}

			data.tiles.push(tdata);
		}

		var out = Json.stringify(data);
		Fs.createDirectory("assets/maps/zones");
		// trace(filename, out);
		// Fs.remove(filename);
		Fs.write(filename, out);
	}

	public static function get_zones(): Map<String, Array<WorldTile>> {
		var zones = new Map<String, Array<WorldTile>>();
		var tiles = World.tiles;

		for (tile in tiles) {
			if (!zones.exists(tile.filename)) {
				zones[tile.filename] = [];
			}
			var zone = zones[tile.filename];
			if (zone.indexOf(tile) < 0) {
				zone.push(tile);
			}
		}

		return zones;
	}

	public static function save(filename: String) {
		var zones = get_zones();

		Fs.createDirectory("assets/maps");

		var zone_paths = [];
		for (zone in zones) {
			zone_paths.push(zone[0].filename);
			save_zone(zone, zone[0].filename);
		}

		var data: WorldData = {
			version: map_version,
			// height_map: String;
			// height_scale: Int;
			maps: zone_paths
		};

		var out = Json.stringify(data);
		// trace(filename, out);
		// Fs.remove(filename);
		Fs.write(filename, out);
	}
}
