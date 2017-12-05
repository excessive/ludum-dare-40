package editor;

#if imgui

import imgui.Widget;
import imgui.Window;
import love.filesystem.FilesystemModule as Fs;
import haxe.Json;
import math.Vec3;
import math.Quat;

import components.Transform;
import components.Drawable;
import components.Rail;

typedef EntitySaveData = {
	id:        Int,
	collision: Int,
	model:     String,
	pos:       Array<Float>,
	rot:       Array<Float>,
	scale:     Array<Float>,
	rails:     Array<Array<Float>>
}

typedef PrefabData = {
	keep_positions: Bool,
	entities: Array<EntitySaveData>
}

class Prefab {
	static var group:        Array<Entity> = [];
	static var selected:     Null<Entity>  = null;
	static var tmp_filename: String        = "";
	static var keep_positions = false;

	public static function draw(_sel: Null<Entity>) {
		selected = _sel;

		var size = Window.get_content_region_max();

		if (group.length > 0) {
			tmp_filename = Widget.input_text("Filename", tmp_filename);
			if (Widget.checkbox("Keep Positions", keep_positions)) {
				keep_positions = !keep_positions;
			}
			Widget.same_line(100);
			if (Widget.button("Save##save_prefab") && tmp_filename.length > 0) {
				save(tmp_filename);
				tmp_filename = "";
				keep_positions = false;
				clear();
			}
		}

		var prefabs = get_prefabs();
		var i = 0;
		for (prefab in prefabs) {
			Widget.text(prefab);
			Widget.same_line(size[0] - 50);
			if (Widget.button('Load##$i', 50)) {
				load(Editor.cursor.as_absolute(), prefab);
			}
			i++;
		}
	}

	static var BASE_DIRECTORY = "assets/prefabs/";
	static var FILE_SUFFIX = ".fab";
	static var FILE_TILE_SUFFIX = ".tile.fab";

	static var prefab_cache: Array<String>;

	static function collect(path): Array<String> {
		var ret = [];
		var items = Fs.getDirectoryItems(path);

		lua.PairTools.ipairsEach(items, function(i: Int, file: String) {
			ret.push(file);
		});

		return ret;
	}

	// Center of group
	public static function get_center(): Vec3 {
		var center = new Vec3();

		for (e in group) {
			center += e.transform.position;
		}

		center /= group.length;

		return center;
	}

	public static function is_empty(): Bool {
		return group.length == 0;
	}

	public static function get_prefabs(): Array<String> {
		if (prefab_cache != null) {
			return prefab_cache;
		}
		var files = collect(BASE_DIRECTORY);
		prefab_cache = files;
		return files;
	}

	public static function add(e: Entity) {
		if (e.player == null && e.transform != null) {
			group.push(e);
		}
	}

	public static function remove(e: Entity) {
		group.remove(e);
	}

	public static function clear() {
		group = [];
	}

	static function load(base_position: Vec3, filename: String) {
		var saved = Fs.read(BASE_DIRECTORY+filename);
		var data: PrefabData = Json.parse(saved.contents);

		var vtile = World.virtual_tile_at(base_position);
		var tile  = vtile.world_tile;

		var rails: Array<Rail> = [];

		var position = data.keep_positions? new Vec3() : base_position;

		var loc: Entity = {
			parent: {
				entity: null,
				name: filename,
			},
			transform: new Transform(position)
		};

		for (entity in data.entities) {
			var target: Entity = {
				parent: {
					entity: loc,
					name: null
				}
			};

			target.prefab_path = filename;
			var is_static = true; // TODO: store this in data

			var tx = new Transform(
				new Vec3(entity.pos[0], entity.pos[1], entity.pos[2]) + position,
				new Vec3(),
				new Quat(entity.rot[0], entity.rot[1], entity.rot[2], entity.rot[3]),
				new Vec3(entity.scale[0], entity.scale[1], entity.scale[2]),
				is_static
			);
			tx.orientation.normalize();
			tx.tile_x = tile.x;
			tx.tile_y = tile.y;
			tx.update();

			target.transform = tx;

			if (entity.rails.length > 0) {
				target.rails = [];
				for (rail in entity.rails) {
					var start = tx.mtx * new Vec3(rail[0], rail[1], rail[2]);
					var end   = tx.mtx * new Vec3(rail[3], rail[4], rail[5]);
					var r     = new Rail(start, end);
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
			if (entity.model.length != 0) {
				target.drawable = new Drawable(entity.model, collidable, Basic);
			}

			World.add(target);
			World.refresh_entity(null, vtile.world_tile, target, true);
		}
	}

	public static function save(filename: String) {
		if (group.length == 0) {
			return;
		}
		get_prefabs();
		var full_name = filename;
		if (keep_positions) {
			full_name += FILE_TILE_SUFFIX;
		}
		else {
			full_name += FILE_SUFFIX;
		}
		prefab_cache.push(full_name);

		var data: PrefabData = {
			keep_positions: keep_positions,
			entities: []
		};

		var center = get_center();

		if (keep_positions) {
			center *= 0;
		}

		var id = 0;
		for (e in group) {
			var _pos = e.transform.position - center;
			var _rot = e.transform.orientation;
			var _sca = e.transform.scale;
			var mesh = "";
			var coll = CollisionType.None;
			var rail_data: Array<Array<Float>> = [];

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

			data.entities.push({
				model: mesh,
				id: id,
				collision: coll.getIndex(),
				pos:   [ _pos[0], _pos[1], _pos[2] ],
				rot:   [ _rot[0], _rot[1], _rot[2], _rot[3] ],
				scale: [ _sca[0], _sca[1], _sca[2] ],
				rails: rail_data
			});
			id++;
		}

		var out = Json.stringify(data);
		Fs.createDirectory(BASE_DIRECTORY);
		trace(filename, out);
		// Fs.remove(filename);
		Fs.write(BASE_DIRECTORY+full_name, out);
	}
}

#end
