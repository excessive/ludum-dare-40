package systems;

import ui.Anchor;
import actor.Actor;

import love.graphics.GraphicsModule as Lg;
import render.Helpers.setColor;

typedef ActorLayer = Array<Actor>;

typedef Subtitle = {
	text:     String,
	duration: Float
};

class Hud extends System {
	static var layers:          Array<ActorLayer> = [];
	static var subtitle_queue:  Array<Subtitle>   = [];
	static var subtitle_active: Bool = false;
	static var subtitle_opacity: Float = 0;

	override function filter(entity: Entity) {
		return false;
	}

	override function update(entities: Array<Entity>, dt: Float) {
		for (layer in layers) {
			for (actor in layer) {
				actor.update(dt);
			}
		}

		if (!subtitle_active && subtitle_queue.length > 0) {
			TimerScript.add(function(wait) {
				var sub = subtitle_queue[0];
				subtitle_active = true;
				subtitle_opacity = 1; // timer
				wait(sub.duration);
				subtitle_opacity = 0; // timer
				subtitle_queue.pop();
				subtitle_active = false;
			});
		}

		TimerScript.update(dt);
	}

	public static function add_subtitle(subtitle: Subtitle) {
		subtitle_queue.insert(subtitle_queue.length, subtitle);
	}

	static function draw() {
		Lg.setBlendMode(Alpha, Alphamultiply);
		setColor(1, 1, 1, 1);

		for (layer in layers) {
			for (actor in layer) {
				var state = actor.actual;
				// draw stuff
			}
		}

		if (subtitle_active) {
#if imgui
			imgui.Widget.text(subtitle_queue[0].text);
			imgui.Widget.value("opacity", subtitle_opacity);
#end

			setColor(0, 0, 0, subtitle_opacity);
			var sub = subtitle_queue[0].text;
			Lg.print(sub, Anchor.center_x, Anchor.bottom);
		}

#if debug
		setColor(0, 0, 0, 0.5);
		Lg.line(Anchor.left, Anchor.center_y, Anchor.right, Anchor.center_y);
		Lg.line(Anchor.center_x, Anchor.top, Anchor.center_x, Anchor.bottom);
		setColor(0, 0, 0, 1.0);
		Lg.rectangle(Line, Anchor.left, Anchor.top, Anchor.width, Anchor.height);
#end
	}
}
