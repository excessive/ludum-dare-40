package systems;

import love.audio.Source;
import love.audio.AudioModule as La;

import iqm.Iqm;
import iqm.Iqm.IqmFile;
import anim9.Anim9;
import math.Vec3;
import math.Mat4;
import math.Utils;
import math.Triangle;
import utils.CacheResource;

import components.Drawable.CollisionType;

typedef LoadOpts = {
	var save_triangles: Bool;
}

class Loader extends System {
	override function filter(e: Entity) {
		if (e.drawable != null) {
			return true;
		}
		return false;
	}

	static function convert(t: lua.Table<Int, Dynamic>) {
		var tris = [];
		lua.PairTools.ipairsEach(t, function(i, v) {
			var v0 = new Vec3(v[1].position[1], v[1].position[2], v[1].position[3]);
			var v1 = new Vec3(v[2].position[1], v[2].position[2], v[2].position[3]);
			var v2 = new Vec3(v[3].position[1], v[3].position[2], v[3].position[3]);
			var t = new Triangle(v0, v1, v2, new Vec3());
			t.vn = t.normal();
			tris.push(t);
		});
		return tris;
	}

	static function load_mesh(filename: String, options: LoadOpts) {
		Log.write(Log.Level.System, "load mesh " + filename);
		return Iqm.load(filename, options.save_triangles, false);
	}

	static function load_source(filename: String, ignore: Bool) {
		return La.newSource(filename);
	}

	var static_meshes = new CacheResource<IqmFile, LoadOpts>(load_mesh);
	var audio_sources = new CacheResource<Source, Bool>(load_source);

	override function process(e: Entity, dt: Float) {
		if (e.sound != null) {
			if (e.sound.loaded == null) {
				e.sound.loaded = new Map<String, Source>();
				for (k in e.sound.sounds.keys()) {
					e.sound.loaded[k] = audio_sources.load(e.sound.sounds[k], false);
				}
			}
		}
		if (e.drawable != null) {
			if (e.drawable.mesh == null) {
				var actor = e.drawable.collision == CollisionType.Triangle;
				e.drawable.mesh = static_meshes.load(e.drawable.filename, { save_triangles: actor });
				if (actor) {
					var tris = convert(e.drawable.mesh.triangles);
					var xform = new Mat4();
					e.transform.update();
					if (e.transform != null) {
						xform *= Mat4.scale(e.transform.scale);
						xform *= Mat4.rotate(e.transform.orientation);
						xform *= Mat4.translate(e.transform.position);
					}
					var tile = World.get_tile(e.transform.tile_x, e.transform.tile_y);
					World.add_triangles(tile, xform, tris);
				}
			}
		}
		if (e.attachments != null) {
			for (attach in e.attachments) {
				if (attach.mesh == null) {
					Log.write(Log.Level.System, "load mesh " + attach.filename);
					attach.mesh = Iqm.load(attach.filename);
				}
			}
		}
		if (e.animation != null) {
			if (e.animation.timeline == null) {
				var data = Iqm.load_anims(e.animation.filename);
				e.animation.timeline = new Anim9(data);
				var tl = e.animation.timeline;
				if (tl != null && e.animation.anims.length > 0) {
					for (f in e.animation.anims) {
						tl.add_animation(Iqm.load_anims(f));
					}
				}
				if (tl != null) {
					var run = tl.new_track("skate");
					tl.play(run);
				}
				else {
					untyped __lua__("for k, v in pairs(data.frames) do print(k, v) end");
				}
			}
		}
	}
}
