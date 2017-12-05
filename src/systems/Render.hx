package systems;

import love.graphics.GraphicsModule as Lg;
import backend.Input as PlatformInput;
import love.graphics.Canvas;
import love.graphics.CanvasFormat;
import love.graphics.Shader;

import render.Grass;

import math.Utils;

import editor.Editor;
import editor.Panel;
import editor.Panel.UIPanelCategory;
import render.Helpers.*;

import iqm.Iqm;
import iqm.Iqm.IqmFile;

import love3d.Love3d as L3d;
import ui.LogWindow;

import components.Drawable.ShaderType;

#if imgui
import imgui.Window;
import imgui.Widget;
import imgui.Style;
#end

import math.Vec3;
import math.Quat;
import math.Mat4;

import Profiler.SegmentColor;

typedef Viewport = {
	var x: Float;
	var y: Float;
	var w: Float;
	var h: Float;
}

class Render extends System {
	static var shaders;
	static var camera: Null<Camera>;

	static var main_canvas: Canvas;
	static var canvases: Array<Canvas>;

	static var r: Float = 7.0;
	static var g: Float = 14.0;
	static var b: Float = 16.0;
	static var exposure: Float = 1.5;
	static var vignette: Float = 0.75;

	static var ab: Bool = false;
	static var swap: {
		var r: Float;
		var g: Float;
		var b: Float;
	};

	static var texture: love.graphics.Image;
	static var grass: love.graphics.Mesh;
	static var short_grass: love.graphics.Mesh;

	static var wire_mode = false;

	static var game_aa = 4;

	public static function resize(w: Float, h: Float) {
		main_canvas = L3d.new_canvas(w, h, CanvasFormat.Rg11b10f, game_aa, true);
	}

	public static function gui_resize(w: Float, h: Float) {
		canvases = [
			L3d.new_canvas(w, h, CanvasFormat.Rg11b10f, game_aa, true),
			L3d.new_canvas(w, h, CanvasFormat.Rg11b10f, game_aa, false)
		];
	}

	// static function load_mesh(file: String, _: Bool): IqmFile {
	// 	return Iqm.load(file);
	// }
	// static var res_cache = new utils.CacheResource<IqmFile>(load_mesh);

	static var grid: IqmFile;
	static var cube: IqmFile;
	static var sphere: IqmFile;
	static var cylinder: IqmFile;

	public static function init() {
		Lg.setBackgroundColor(89, 157, 220);
		L3d.prepare();

		Debug.init();

		resize(Lg.getWidth(), Lg.getHeight());
		gui_resize(2, 2);

		swap = {
			r: r,
			g: g,
			b: b
		};

		grid = Iqm.load("assets/models/debug/unit-grid.iqm");
		cube = Iqm.load("assets/models/debug/unit-cube.iqm");
		sphere = Iqm.load("assets/models/debug/unit-sphere.iqm");
		cylinder = Iqm.load("assets/models/debug/unit-cylinder.iqm");

		grass = Iqm.load("assets/models/tall-grass.iqm").mesh;
		short_grass = Iqm.load("assets/models/short-grass.iqm").mesh;

		try {
			shaders = {
				basic:   Lg.newShader("assets/shaders/basic.glsl"),
				sky:     Lg.newShader("assets/shaders/sky.glsl"),
				post:    Lg.newShader("assets/shaders/post.glsl"),
				debug:   Lg.newShader("assets/shaders/debug.glsl"),
				edit:    Lg.newShader("assets/shaders/edit.glsl"),
				terrain: Lg.newShader("assets/shaders/terrain.glsl"),
				grass:   Lg.newShader("assets/shaders/grass.glsl")
			}
		}
		catch (err: String) {
			trace(err);
		}

		var flags = untyped __lua__("{ mipmaps = {0} }", true);
		texture = Lg.newImage("assets/textures/terrain.png", flags);
		texture.setWrap(Repeat, Repeat);
		texture.setMipmapFilter(Linear, 0.9);
		texture.setFilter(Linear, Linear, 16);
	}

	override public function filter(e: Entity) {
		if (e.transform != null) {
			return true;
		}
		return false;
	}

	function send_uniforms(shader: Shader) {
		var w = Lg.getWidth();
		var h = Lg.getHeight();

		var view = new Mat4();
		var proj = Mat4.from_ortho(-w/2, w/2, h/2, -h/2, -500, 500);
		if (camera != null) {
			view = camera.view;
			proj = camera.projection;
			// var curve = Time.sun_brightness;
			var curve = 1.0;
			var threshold = 0.1;
			if (curve > threshold) {
				curve = 1;
			}
			else if (curve > 0) {
				curve = curve / threshold;
			}
			send(shader, "u_clips", new Vec3(camera.near, Utils.max(camera.far*curve, camera.near + 75), 0).unpack());
			send(shader, "u_curvature", camera.far/20);
		}

		// the inverse viewproj is used by the sky shader, and positions screw it up.
		// so we just use the inverse of the view rotation * proj
		var view_rot = view.copy();
		view_rot[14] = 0;
		view_rot[13] = 0;
		view_rot[12] = 0;

		var inv = view_rot * proj;
		inv.invert();

		var ld = Time.sun_direction;
		send(shader, "u_fog_color", new Vec3(1.0*Time.sun_brightness, 2.0*Time.sun_brightness, 3.0*Time.sun_brightness).unpack());
		send(shader, "u_light_direction", ld.unpack());
		send(shader, "u_light_intensity", Time.sun_brightness);
		send(shader, "u_view", view.to_vec4s());
		send(shader, "u_projection", proj.to_vec4s());
		send(shader, "u_inv_view_proj", inv.to_vec4s());
	}

	static var grass_enabled = false;
	static var grass_range: Float = 50;
	static var grass_density: Float = 1.5;
	static var grass_seed: Int = 50;
	static var instances = [];

	public static var clouds: Array<{rain: Float}> = [
		for (i in 0...World.tiles_x*World.tiles_y) { rain: 0.0 }
	];

	function render_game(c: Canvas, entities: Array<Entity>, viewport: Viewport, debug_draw: Bool) {
		Profiler.marker("", SegmentColor.Render);

		var w = viewport.w;
		var h = viewport.h;

		if (camera != null) {
			camera.update(w, h);
		}

		var vtiles = World.visible_tiles;

		// for (cloud in clouds) {
		// 	var draw = new components.Drawable("fake");
		// 	draw.mesh = cube;
		// 	draw.shader = Terrain;
		// 	var scale = new Vec3(World.tile_size, World.tile_size, 25.0);
		// 	var tx = new components.Transform(new Vec3(), null, null, scale);
		// 	tx.position = new Vec3(scale.x / 2 + scale.x * cloud.x, scale.y / 2 + scale.y * cloud.y, 500/2);
		// 	tx.mtx = Mat4.scale(scale) * Mat4.translate(tx.position);
		// 	drawables.push({
		// 		drawable: draw,
		// 		transform: tx
		// 	});
		// }

		Profiler.push_block("entity draw", SegmentColor.Render);
		Lg.setCanvas(c);

		Lg.setShader(shaders.sky);
		send_uniforms(shaders.sky);
		L3d.set_depth_write(false);
		Lg.rectangle(Fill, -1, -1, 2, 2);

		L3d.set_depth_test(Less);
		L3d.set_depth_write(true);
		L3d.set_culling(Back);

		Lg.setShader(shaders.terrain);
		send_uniforms(shaders.terrain);

		Lg.setShader(shaders.basic);
		send_uniforms(shaders.basic);

		L3d.clear();
		Lg.setBlendMode(Replace, Premultiplied);

		var far = camera != null? camera.far : 200;
		var pos = camera != null? camera.position : new Vec3();
		var mtx = Mat4.scale(new Vec3(far, far, 1)) * Mat4.translate(new Vec3(pos.x, pos.y, World.kill_z));

		var shader = shaders.basic;
		Lg.setShader(shader);
		send(shader, "u_model", mtx.to_vec4s());

		var inv = mtx.copy();
		inv.invert();
		inv.transpose();

		send(shader, "u_normal_mtx", inv.to_vec4s());
		Lg.draw(grid.mesh);

		Lg.setShader(shaders.basic);
		var last_shader = ShaderType.Basic;

		var wire_only = wire_mode;

		for (vt in vtiles) {
			var tile = vt.world_tile;
			var drawables = tile.entities.filter(function(e) { return e.drawable != null && e.transform != null; });

			var tile_offset = vt.offset();

			for (e in drawables) {
				var d = e.drawable;
				var xform = e.transform;

				if (d.mesh == null) {
					continue;
				}

				var shader = d.shader == ShaderType.Terrain ? shaders.terrain : shaders.basic;
				if (d.shader != last_shader) {
					var st = [
						ShaderType.Basic => shaders.basic,
						ShaderType.Terrain => shaders.terrain
					];
					Lg.setShader(st[d.shader]);
				}
				last_shader = d.shader;

				var mtx = new Mat4();
				if (xform.scale.lengthsq() > 0) {
					mtx *= Mat4.scale(xform.scale);
				}
				mtx *= Mat4.rotate(xform.orientation);
				mtx *= Mat4.translate(xform.position + tile_offset);

				// Debug.aabb(xform.position + tile_offset - new Vec3(5,5,5), xform.position + tile_offset + new Vec3(5,5,5), 0, 1, 1);
				if (e.rails != null) {
					for (rail in e.rails) {
						Debug.capsule(rail.capsule, 1, 0, 1);
					}
				}

				send(shader, "u_model", mtx.to_vec4s());

				var inv = mtx.copy();
				inv.invert();
				inv.transpose();

				send(shader, "u_normal_mtx", inv.to_vec4s());

				var animated = e.animation != null && e.animation.timeline != null;
				if (d.shader == ShaderType.Basic) {
					shader.send("u_rigged", animated? 1 : 0);
					if (animated) {
						var tl = e.animation.timeline;
						inline function unpack(t): Dynamic {
							return untyped __lua__("unpack(t)");
						}
						shader.send("u_pose", lua.TableTools.unpack(tl.current_pose));
					}
				}

				if (d.shader == ShaderType.Terrain) {
					d.mesh.mesh.setTexture(texture);
				}
				lua.PairTools.ipairsEach(d.mesh.meshes, function(i, m) {
					var mesh = d.mesh.mesh;
					mesh.setDrawRange(m.first, m.last);
					if (debug_draw || wire_only) {
						L3d.set_culling(None);
						setColor(0, 0, 0, 1);
						Lg.setWireframe(true);
						Lg.draw(mesh);
						setColor(1, 1, 1, 1);
						Lg.setWireframe(false);
						L3d.set_culling(Back);
					}
					if (!wire_only) {
						Lg.draw(mesh);
					}
				});

				if (debug_draw) {
					var bounds = d.mesh.bounds.base;
					var min = new Vec3(bounds.min[1], bounds.min[2], bounds.min[3]);
					var max = new Vec3(bounds.max[1], bounds.max[2], bounds.max[3]);
					var xform_bounds = Utils.rotate_bounds(mtx, min, max);
					Debug.aabb(xform_bounds.min, xform_bounds.max, 0, 1, 1);
				}

				if (e.attachments != null && animated) {
					var tl = e.animation.timeline;
					for (attach in e.attachments) {
						var m = Mat4.from_cpml(tl.current_matrices[cast attach.bone]);
						var flip = new Mat4([
							1, 0, 0, 0,
							0, 0, -1, 0,
							0, 1, 0, 0,
							attach.offset[0], attach.offset[2],-attach.offset[1], 1
						]);

						var am = flip * m * mtx;
						if (debug_draw) {
							var bounds = attach.mesh.bounds.base;
							var min = new Vec3(bounds.min[1], bounds.min[2], bounds.min[3]);
							var max = new Vec3(bounds.max[1], bounds.max[2], bounds.max[3]);
							var xform_bounds = Utils.rotate_bounds(am, min, max);
							Debug.aabb(xform_bounds.min, xform_bounds.max, 0, 0, 1);
						}
						shader.send("u_model", am.to_vec4s());
						shader.send("u_rigged", 0);
						var inv = am.copy();
						inv.invert();
						inv.transpose();
						send(shader, "u_normal_mtx", inv.to_vec4s());

						lua.PairTools.ipairsEach(attach.mesh.meshes, function(i, m) {
							var mesh = attach.mesh.mesh;
							mesh.setDrawRange(m.first, m.last);
							if (debug_draw || wire_only) {
								L3d.set_culling(None);
								setColor(0, 0, 0, 1);
								Lg.setWireframe(true);
								Lg.draw(mesh);
								setColor(1, 1, 1, 1);
								Lg.setWireframe(false);
								L3d.set_culling(Back);
							}
							if (!wire_only) {
								Lg.draw(mesh);
							}
						});
					}
				}
			}
		}
		Profiler.pop_block();

		Profiler.push_block("grass", new SegmentColor(0.25, 0.75, 0.0));
		var count = 0;
		if (grass_enabled) {
			var models = [
				short_grass,
				short_grass,
				short_grass,
				short_grass,
				short_grass,
				grass,
			];
			for (vt in vtiles) {
				count = Grass.scatter(instances, camera, models, vt.offset(), grass_seed, count, 0, grass_range, grass_density, grass_range);
			}
		}

		Profiler.push_block("grass draw", new SegmentColor(0.1, 0.5, 0.0));
		var gs = shaders.grass;
		Lg.setShader(gs);
		send_uniforms(gs);

		send(gs, "u_time", now);
		send(gs, "u_speed", 1);
		send(gs, "u_wind_force", 0.5);

		L3d.set_culling(Back);
		for (i in 0...count) {
			var instance = instances[i];
			gs.send("u_instance", instance);
			Lg.draw(cast instance[5]);
		}
		Profiler.pop_block();
		Profiler.pop_block();

		Profiler.push_block("debug draw", new SegmentColor(0.25, 0.25, 0.25));
		Lg.setWireframe(true);
		Lg.setShader(shaders.debug);
		send_uniforms(shaders.debug);
		send(shaders.debug, "u_white_point", new Vec3(r, g, b).unpack());
		send(shaders.debug, "u_exposure", exposure);


		L3d.set_culling(None);

		send(shaders.debug, "u_model", new Mat4().to_vec4s());
		Debug.draw(false);

		Lg.setWireframe(false);
		Lg.setBlendMode(Alpha, Alphamultiply);

		var caps = Debug.clear_capsules();
		//if (debug_draw) {
			inline function mtx_for(capsule: Vec3, radius: Float) {
				return Mat4.scale(new Vec3(radius, radius, radius))
					* Mat4.translate(capsule)
				;
			}
			inline function mtx_srt(s: Vec3, r: Quat, t: Vec3) {
				return Mat4.scale(s)
					* Mat4.rotate(r)
					* Mat4.translate(t)
				;
			}
			var shader = shaders.debug;
			Lg.setShader(shader);
			for (cap_data in caps) {
				setColor(cap_data.r, cap_data.g, cap_data.b, 0.5);
				var capsule = cap_data.capsule;

				var mtx = mtx_for(capsule.a, capsule.radius);
				send(shader, "u_model", mtx.to_vec4s());
				Lg.draw(sphere.mesh);

				mtx = mtx_for(capsule.b, capsule.radius);
				send(shader, "u_model", mtx.to_vec4s());
				Lg.draw(sphere.mesh);

				var dir = capsule.b - capsule.a;
				dir.normalize();

				var rot = math.Quat.from_direction(dir);
				rot.normalize();

				var length = Vec3.distance(capsule.a, capsule.b);
				mtx = mtx_srt(new Vec3(capsule.radius, capsule.radius, length / 2), rot, (capsule.a + capsule.b) / 2);

				send(shader, "u_model", mtx.to_vec4s());
				Lg.draw(cylinder.mesh);
			}
		//}

		// for (vt in vtiles) {
		// 	var tile = vt.world_tile;
		// 	var drawables = tile.entities.filter(function(e) { return e.drawable != null && e.transform != null; });

		// 	for (e in drawables) {
		// 		var d = e.drawable;
		// 		var xform = e.transform;
		// 	}
		// }

		Profiler.pop_block();

		Lg.setWireframe(false);
		Lg.setShader();

		L3d.set_depth_test();

		Lg.setCanvas();
		Lg.setShader();
	}

	function render_view(c: Canvas, entities: Array<Entity>, viewport: Viewport, axis: Vec3) {
		var w = viewport.w;
		var h = viewport.h;
		var ar = w/h;

		Lg.setCanvas(c);
		Lg.clear(42, 42, 42);
		L3d.clear();

		Lg.setWireframe(true);

		L3d.set_depth_test(Less);
		L3d.set_depth_write(true);
		L3d.set_culling(None);

		var shader = shaders.edit;
		var range = 20;
		var proj = Mat4.from_ortho(-range*ar, range*ar, range, -range, -1000, 1000);

		var pos = new Vec3();
		if (camera != null) {
			pos[0] = camera.position[0];
			pos[1] = camera.position[1];
			pos[2] = camera.position[2];
		}

		var up = Vec3.unit_z();
		if (axis[2] == 1) {
			up = Vec3.unit_y();
		}
		var view = Mat4.look_at(pos + axis, pos, up);

		send(shader, "u_view", view.to_vec4s());
		send(shader, "u_projection", proj.to_vec4s());

		for (e in entities) {
			var d = e.drawable;
			var xform = e.transform;

			var fwd = xform.orientation * -Vec3.unit_y();
			var eup = Vec3.unit_z();
			Debug.axis(xform.position, Vec3.cross(fwd, eup), fwd, eup);

			if (d == null || d.mesh == null) {
				continue;
			}

			Lg.setShader(shader);

			var mtx = xform.mtx;
			var bounds = d.mesh.bounds.base;
			var min = new Vec3(bounds.min[1], bounds.min[2], bounds.min[3]);
			var max = new Vec3(bounds.max[1], bounds.max[2], bounds.max[3]);
			var xform_bounds = Utils.rotate_bounds(mtx, min, max);
			Debug.aabb(xform_bounds.min, xform_bounds.max, 0, 1, 1);

			send(shaders.edit, "u_model", mtx.to_vec4s());
			var color = new Vec3(0.4, 0.4, 0.4);
			if (Editor.selected == e) {
				color[1] = 1;
			}
			send(shaders.edit, "u_color", color.unpack());
			lua.PairTools.ipairsEach(d.mesh.meshes, function(i, m) {
				var mesh = d.mesh.mesh;
				mesh.setDrawRange(m.first, m.last);
				Lg.draw(mesh);
			});
		}

		var shader = shaders.debug;
		Lg.setShader(shader);
		send(shader, "u_view", view.to_vec4s());
		send(shader, "u_projection", proj.to_vec4s());
		send(shader, "u_white_point", new Vec3(r, g, b).unpack());
		send(shader, "u_exposure", exposure);

		Debug.draw(false);

		L3d.set_depth_test(None);
		Lg.setWireframe(false);
		Lg.setCanvas();
		Lg.setShader();
	}

	function setup_post() {
		Lg.setShader(shaders.post);
		if (ab) {
			send(shaders.post, "u_white_point", new Vec3(swap.r, swap.g, swap.b).unpack());
		}
		else {
			send(shaders.post, "u_white_point", new Vec3(r, g, b).unpack());
		}
		send(shaders.post, "u_exposure", exposure);
		send(shaders.post, "u_vignette", vignette);
		setColor(1.0, 1.0, 1.0, 1.0);
	}

	function draw_game_view(vp: Viewport, entities: Array<Entity>, submit_view: Bool) {
		if (!submit_view) {
			render_game(main_canvas, entities, vp, false);
			return;
		}

		render_game(canvases[0], entities, vp, false);

		var c = canvases[1];
		c.renderTo(function() {
			setup_post();
			Lg.draw(canvases[0]);
			Lg.setShader();
		});

#if imgui
		Widget.set_cursor_pos(vp.x, vp.y);
		Widget.image(c, vp.w, vp.h, 0, 0, 1, 1);
#end
	}

	static var activate_game = false;

	static var now = 0.0;

	override public function update(entities: Array<Entity>, dt: Float) {
		now += dt;

		var w = Lg.getWidth();
		var h = Lg.getHeight();

#if imgui
		Panel.register_panel(UIPanelCategory.Settings, "Post Processing", function() {
			Widget.begin_group();
			if (Widget.checkbox("##ab", !ab)) {
				ab = !ab;
			}
			Widget.same_line();
			if (ab) Style.push_color("Text", 1, 1, 1, 0.5);
			var ret = Widget.drag_float3("White Point", r, g, b, 0.1, 0.5, 20);
			if (!ab) {
				r = ret.f1;
				g = ret.f2;
				b = ret.f3;
			}
			if (ab) Style.pop_color();
			Widget.end_group();

			var r2 = Widget.slider_float("Exposure", exposure, -5, 5);
			exposure = r2.f1;

			r2 = Widget.slider_float("Vignette", vignette, 0, 1);
			vignette = r2.f1;
		});

		Panel.register_panel(UIPanelCategory.Settings, "Grass", function() {
			if (Widget.checkbox("Draw Grass", grass_enabled)) {
				grass_enabled = !grass_enabled;
			}
			var rf = Widget.slider_float("Range", grass_range, 0, 200);
			grass_range = rf.f1;
			rf = Widget.slider_float("Density", grass_density, 0, 10);
			grass_density = rf.f1;
			var ri = Widget.slider_int("Seed", grass_seed, 0, 100);
			grass_seed = ri.i1;
		});

		Panel.register_panel(UIPanelCategory.Settings, "Display", function() {
			if (Widget.checkbox("Wireframe", wire_mode)) {
				wire_mode = !wire_mode;
			}
		});

		var editing = false;
		if (Main.showing_menu(Main.WindowType.EditorUI)) {
			editing = true;
		}

		var cx = 4;
		var cy = 4;
		if (editing) {
			GameInput.bind(GameInput.Action.Debug_F7, function() {
				activate_game = true;
				PlatformInput.set_relative(true);
				return true;
			});
			GameInput.bind(GameInput.Action.Debug_F8, function() {
				PlatformInput.set_relative(false);
				return true;
			});

			Window.set_next_window_pos(0, 20);
			Window.set_next_window_size(w, h-20);
			var open = Window.begin("DockArea", true, lua.Table.create([ "NoWindowBg", "NoTitleBar", "NoResize", "NoMove", "NoBringToFrontOnFocus", "NoCollapse" ]));
			if (open) {
				Lg.setBackgroundColor(89/5, 157/5, 220/5);
				Window.begin_dockspace();

				Window.set_next_dock("Right");
				Editor.running = false;
				var flags = lua.Table.create([ "NoScrollbar" ]);
				open = Window.begin_dock("Editor##editor_view", null, flags);
				if (activate_game) {
					Window.set_dock_active();
					activate_game = false;
				}
				if (open) {
					Editor.running = true;
					var size = Window.get_content_region_max();
					var vp: Viewport = { x: 0, y: 0, w: size[0]+cx*2, h: size[1]+cy*2 };
					if (vp.w != canvases[0].getWidth() || vp.h != canvases[0].getHeight()) {
						gui_resize(vp.w, vp.h);
					}
					draw_game_view(vp, entities, true);
				}
				Window.end_dock();

				Window.set_next_dock("Bottom");
				LogWindow.draw();

				Window.set_next_dock_split_ratio(0.2, 0.5);
				Window.set_next_dock("Left");
				Editor.draw();

				Window.end_dockspace();
			}
			Window.end();
		}
		else {
			Lg.setBackgroundColor(89, 157, 220);

#end
			var vp: Viewport = { x: 0, y: 0, w: w, h: h };
			draw_game_view(vp, entities, false);

			var c = main_canvas;
			var rw = w / c.getWidth();
			var rh = h / c.getHeight();
			setup_post();
			Lg.draw(c, vp.x, vp.y, 0, rw, rh);
			Lg.setShader();
#if imgui
		}
		if (World.is_local()) {
			setColor(0.2, 0.0, 0.0, 0.95);
			var str = "LOCAL MAP";
			var f = Lg.getFont();
			Lg.rectangle(Fill, 20, 20, f.getWidth(str) + 20, f.getHeight() + 20);
			setColor(1.0, 0.0, 0.0, 1.0);
			Lg.print(str, 30, 30);
		}
#end
		setColor(1.0, 1.0, 1.0, 1.0);

		Hud.draw();

		setColor(1.0, 1.0, 1.0, 1.0);
	}
}
