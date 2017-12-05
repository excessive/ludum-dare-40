package systems;

import editor.Editor;

import love.graphics.GraphicsModule as Lg;
import love.graphics.Canvas;
import love.math.MathModule as Lm;
import love.graphics.BlendAlphaMode;
import love.graphics.BlendMode;
import math.Vec2;
import math.Utils;
import math.Triangle;

typedef CloudTile = {
	var rain: Float;
	var wind: Vec2;
}

typedef RainCloud = {
	var position: Vec2;
	var last_update: Float;
	var age: Float;
}

class WeatherSystem extends System {
	var cloud_tiles: Array<CloudTile> = [];
	var cloud_parts: Array<RainCloud> = [];
	var cloud_lifetime = 20.0;
	var cloud_count = 50;
	var now = 0.0;
	var rng = Lm.newRandomGenerator();
	function spawn(n: Int) {
		var lifetime_variance = 10.0;
		for (i in 0...n) {
			cloud_parts.push({
				position: new Vec2(rng.random(World.tiles_x), rng.random(World.tiles_y)),
				last_update: now,
				age: rng.random(lifetime_variance)
			});
		}
	}
	var canvas: Canvas;
	public function new() {
		super();
		canvas = Lg.newCanvas(512, 512, Rgba8, 4);
		var n = World.tiles_x*World.tiles_y;
		var div: Float = (World.tiles_x+World.tiles_y)/2;
		for (i in 0...n) {
			var x = i % World.tiles_x;
			var y = Std.int(i / World.tiles_x);
			var dir = new Vec2(
				Lm.noise(x / div, y / div),
				1-Lm.noise(x / div, y / div)
			);
			if (dir.length() > 1) {
				dir.normalize();
			}
			dir *= 1/0.5;
			cloud_tiles.push({
				rain: 0.0,
				wind: dir.copy()
			});
		}
		spawn(cloud_count);
	}
	override function filter(e: Entity) {
		return false;
	}
	function draw(w: Float, h: Float, debug_draw: Bool) {
		inline function tile_at(x: Float, y: Float) {
			var idx = Math.floor(y)*World.tiles_x+Math.floor(x);
			return cloud_tiles[idx];
		}

		var at = Editor.cursor;
		if (debug_draw) {
			Lg.setBlendMode(BlendMode.Alpha, BlendAlphaMode.Premultiplied);
		}
		for (i in 0...cloud_tiles.length) {
			var tile = cloud_tiles[i];
			var x: Float = i % World.tiles_x;
			var y: Float = Std.int(i / World.tiles_x);
			var rain = Math.pow(tile.rain, 1/2);
			if (rain < 0.125) {
				rain = 0.0;
			}
			else {
				var idx = Std.int(y*World.tiles_x+x);
				var cloud = systems.Render.clouds[idx];
				cloud.rain = rain;
			}
			if (debug_draw) {
				Lg.setColor(rain*255, rain*255, rain*255, 220);
				Lg.rectangle(Fill, x*w, y*h, w, h);
				Lg.setColor((tile.wind.x*0.5+0.5)*255, (tile.wind.y*0.5+0.5)*255, 255*rain, 255);
				x = x * w + w/2;
				y = y * h + h/2;
				Lg.line(x, y, x+tile.wind.x*20, y+tile.wind.y*20);
			}
			tile.rain = 0.0;
		}

		Lg.setBlendMode(BlendMode.Alpha, BlendAlphaMode.Alphamultiply);
		for (vt in World.visible_tiles) {
			var base = Render.camera.viewable;
			var tri = new Triangle(
				base.v0 / World.tile_size,
				base.v1 / World.tile_size,
				base.v2 / World.tile_size,
				base.vn
			);
			Lg.setColor(255, 0, 255, 100);
			Lg.polygon(Line,
				tri.v0.x * w, tri.v0.y * h,
				tri.v1.x * w, tri.v1.y * h,
				tri.v2.x * w, tri.v2.y * h
			);
			Lg.setColor(0, 255, 0, 50);
			Lg.rectangle(Fill, vt.x*w, vt.y*h, w, h);
		}
		Lg.setColor(255, 255, 255, 255);

		for (cloud in cloud_parts) {
			var cdt = now - cloud.last_update;
			cloud.position.x = Utils.wrap(cloud.position.x, World.tiles_x);
			cloud.position.y = Utils.wrap(cloud.position.y, World.tiles_y);

			var tile = tile_at(cloud.position.x, cloud.position.y);
			if (tile == null) {
				trace('error @ cloud ${cloud.position.x} ${cloud.position.y}');
				continue;
			}
			tile.rain += 0.05;
			cloud.position += tile.wind * cdt;
			cloud.last_update = now;
			cloud.age += cdt;
			if (debug_draw) {
				Lg.setColor(255, 255, 255, 255);
				Lg.circle(Fill, cloud.position.x * w, cloud.position.y * h, 2);
			}
		}
		var removed = 0;
		for (i in 0...cloud_parts.length) {
			var cloud = cloud_parts[i];
			if (cloud.age < cloud_lifetime) {
				continue;
			}
			if (i >= cloud_parts.length-removed) {
				break;
			}
			removed += 1;
			cloud_parts[i] = cloud_parts[cloud_parts.length-removed];
		}
		cloud_parts = cloud_parts.splice(removed, cloud_parts.length - removed);
		spawn(removed);

		if (debug_draw) {
			Lg.setColor(255, 0, 255, 255);
			var pos = Editor.cursor.as_absolute();
			Lg.circle(Fill, pos.x*w/World.tile_size, pos.y*h/World.tile_size, 5);
			World.tile_at(pos);
			// Lg.circle(Fill, pos2.x*w, pos2.y*h, 10);

			Lg.setColor(255, 255, 255, 255);
		}
	}
	override function update(entities: Array<Entity>, dt: Float) {
		now += dt;

		return;

		var wh = canvas.getDimensions();
		var w = wh.width/World.tiles_x;
		var h = wh.height/World.tiles_y;

#if imgui
		var open = imgui.Window.begin("Weather");
		if (open) {
			canvas.renderTo(function() {
				draw(w, h, true);
			});
			imgui.Widget.image(canvas, 512, 512, 0, 1, 1, 0);
		}
		else {
#end
			draw(w, h, false);
#if imgui
		}
		imgui.Window.end();
#end
	}
}
