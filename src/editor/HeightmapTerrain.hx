package editor;

import utils.Assert.assert;

import iqm.Iqm;
import iqm.Iqm.IqmFile;
import iqm.Iqm.MeshData;
// import iqm.Iqm.Bounds;
import lua.Table;

import love.image.ImageData;
import love.graphics.GraphicsModule as Lg;
import love.graphics.Mesh;

import math.Triangle;
import math.Vec3;
import math.Mat4;

class HeightmapTerrain {
	public static var terrain: IqmFile;
	public static var HEIGHT_SCALE: Float = 25;

	static function to_iqmfile(mesh: Mesh, indices: Int) {
		var info: MeshData = {
			first: 1,
			last: indices,
			count: indices,
			material: "Material",
			name: "Terrain"
		};
		var file: IqmFile = {
			mesh: mesh,
			bounds: Table.create(),
			meshes: Table.create([info]),
			has_joints: false,
			has_anims: false,
			triangles: null
		}
		return file;
	}

	public static function generate_tile(texture: ImageData, xform: Mat4, tx: Int, ty: Int): IqmFile {
		// var verts_per_tile = 6;
		var verts_per_tile = 11;

		var tile_verts_x = verts_per_tile;
		var tile_verts_y = verts_per_tile;

		var w = texture.getWidth();
		var h = texture.getHeight();

		// tile width in pixels
		var pw = w/World.tiles_x;
		var ph = h/World.tiles_y;

		// tile offset into texture
		var x_offset = tx*pw;
		var y_offset = ty*ph;

		var verts: Table<Int, Dynamic> = Table.create();
		var i = 1;
		for (y in 0...tile_verts_y) {
			for (x in 0...tile_verts_x) {
				var x_pct = x / (tile_verts_x-1);
				var y_pct = y / (tile_verts_y-1);
				var pixel = texture.getPixel(
					(x_offset + x_pct * pw) % w,
					(y_offset + y_pct * ph) % h
				);
				var pos_x = x_pct*World.tile_size;
				var pos_y = y_pct*World.tile_size;
				var pos_z = pixel.r/255*HEIGHT_SCALE;
				var v: Table<Int, Float> = untyped __lua__(
					"{ {0}, {1}, {2}, {3}, {4}, {5}, {6}, {7}, {8}, {9}, {10}, {11} }",
					// x, y, z, u, v
					pos_x, pos_y, pos_z, x_pct, y_pct,
					// nx, ny, nz
					0, -1, 0,
					// r, g, b, a
					255, 255, 255, 255
				);
				verts[i] = v;
				i++;
			}
		}

		var triangles: Array<Triangle> = [];

		var indices: Table<Int, Int> = Table.create();
		i = 1;
		var dummy = new Vec3(0, 0, 0);
		for (y in 0...tile_verts_y-1) {
			for (x in 0...tile_verts_x-1) {
				var start = Std.int(y * tile_verts_x + x) + 1;
				indices[i] = start;                    i++;
				indices[i] = start + 1;                i++;
				indices[i] = start + tile_verts_x;     i++;
				indices[i] = start + 1;                i++;
				indices[i] = start + 1 + tile_verts_x; i++;
				indices[i] = start + tile_verts_x;     i++;

				var a = verts[indices[i-6]];
				var b = verts[indices[i-5]];
				var c = verts[indices[i-4]];
				var d = verts[indices[i-2]];
				var t1 = new Triangle(
					new Vec3(a[1], a[2], a[3]),
					new Vec3(b[1], b[2], b[3]),
					new Vec3(c[1], c[2], c[3]),
					dummy
				);
				t1.vn = t1.normal();
				var t2 = new Triangle(
					new Vec3(b[1], b[2], b[3]),
					new Vec3(d[1], d[2], d[3]),
					new Vec3(c[1], c[2], c[3]),
					dummy
				);
				t2.vn = t2.normal();

				a[5] = t1.vn.x;
				a[6] = t1.vn.y;
				a[7] = t1.vn.z;

				b[5] = t1.vn.x;
				b[6] = t1.vn.y;
				b[7] = t1.vn.z;

				c[5] = t2.vn.x;
				c[6] = t2.vn.y;
				c[7] = t2.vn.z;

				d[5] = t2.vn.x;
				d[6] = t2.vn.y;
				d[7] = t2.vn.z;

				triangles.push(t1);
				triangles.push(t2);
			}
		}

		// assert(Std.int(i % 6) == 0, "bad mojo");
		var fmt = untyped __lua__('{
			{ "VertexPosition", "float", 3 },
			{ "VertexTexCoord", "float", 2 },
			{ "VertexNormal", "float", 3 },
			{ "VertexColor", "byte", 4 }
		}');
		var mesh = Lg.newMesh(fmt, i-1, Triangles, Static);
		mesh.setVertices(verts);
		mesh.setVertexMap(indices);

		var tile = World.get_tile(tx, ty);
		World.add_triangles(tile, xform, triangles);

		return to_iqmfile(mesh, i-1);
	}

	public static function init() {
		// var tex = Li.newImageData("assets/textures/heightmap.png");
	}
}
