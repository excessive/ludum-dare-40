package render;

import love.graphics.Mesh;
import math.Vec3;
import math.Utils;

import love.math.MathModule as Lm;
import lua.Table;

class Grass {
	static var scale_samples = false;
	public static function scatter(instances: Array<Table<Int, Dynamic>>, camera: Camera, models: Array<Mesh>, tile_offset: Vec3, seed: Int, count: Int, min: Float, max: Float, density: Float, scale_range: Float) {
		inline function area(p0, p1, p2) {
			var a = Vec3.distance(p0, p1);
			var b = Vec3.distance(p1, p2);
			var c = Vec3.distance(p2, p0);
			var s = (a + b + c) / 2;
			return Math.sqrt(s * (s-a) * (s-b) * (s-c));
		}
		inline function area2(p0: Vec3, p1: Vec3, p2: Vec3) {
			var ab = p0 - p1;
			var ac = p0 - p2;
			var pg = Vec3.cross(ab, ac);
			return pg.length() / 2.0;
		}

		var buffer = (max - min) / 3;
		var proj = camera.projection.copy();
		proj.set_clips(0.1, (max+buffer)/10);

		// BUG: near/far planes are wrong, far seems too far by 1/near?
		var frustum = (camera.view * proj).to_frustum();

		Profiler.push_block("grass tri query");
		var range = new Vec3(scale_range, scale_range, scale_range);
		var tris = World.get_triangles(camera.position - range, camera.position + range);
		// var tris = World.get_triangles_frustum(frustum);
		Profiler.pop_block();

		Profiler.push_block("grass scatter");
		var p = new Vec3(0, 0, 0);
		var wu = Vec3.up();
		for (tri in tris) {
			var p0 = tri.v0;// + tile_offset;
			var p1 = tri.v1;// + tile_offset;
			var p2 = tri.v2;// + tile_offset;
			var n = tri.vn;
			// Widget.value("area vs", area(p0, p1, p2) / area2(p0, p1, p2));

			var up = Vec3.dot(n, wu);
			if (up < 0.5) {
				continue;
			}

			var blade_limit = 250;
			// var blade_scale = (c0[1] / 255 + c1[1] / 255 + c2[1] / 255) / 3
			var blade_scale = 1.0;

			var samples = Std.int(area2(p0, p1, p2) * density * blade_scale);
			samples = Std.int(Utils.min(samples, blade_limit));

			if (scale_samples) {
				var falloff = 0.5;
				var td = Vec3.distance(p0, camera.position);
				td = Utils.min(td, Vec3.distance(p1, camera.position));
				td = Utils.min(td, Vec3.distance(p2, camera.position));
				td = Utils.min(1.0 - td / scale_range, 1);
				td = Math.pow(td, falloff);

				samples = Std.int(samples * td);
			}

			var rng = Lm.newRandomGenerator(seed);
			for (i in 0...samples) {
				var u = rng.random();
				var v = (1.0 - u) * rng.random();
				var w = 1 - u - v;

				p.x = u * p0[0] + v * p1[0] + w * p2[0];
				p.y = u * p0[1] + v * p1[1] + w * p2[1];
				p.z = u * p0[2] + v * p1[2] + w * p2[2];

				// make sure to calculate this, or our randoms will get screwed up after continues.
				// var scale = Utils.min(Math.pow(Math.max(blade_scale, 0.5) + Lm.random() / 3, falloff), 1.0);

				var d = Vec3.distance(p, camera.position);
				if (d >= max + buffer || d < min) {
					continue;
				}

				var sc = Math.sqrt(1 - d / (scale_range / 2));
				sc *= (up - 0.5) * 2;
				if (d > max) {
					sc *= 1.0 - (d - max) / buffer;
				}
				if (sc < 0.1) {
					continue;
				}

				var model = models[i % models.length];

				if (instances.length <= count) {
					var t = lua.Table.create();
					t[1] = p[0];
					t[2] = p[1];
					t[3] = p[2];
					t[4] = sc;
					t[5] = cast model;
					instances.push(t);
				}
				else {
					instances[count][1] = p[0];
					instances[count][2] = p[1];
					instances[count][3] = p[2];
					instances[count][4] = sc;
					instances[count][5] = cast model;
				}
				count++;
			}
		}
		Profiler.pop_block();
		return count;
	}
}
