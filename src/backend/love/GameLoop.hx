package backend.love;

import love.math.MathModule as Lm;
import love.timer.TimerModule as Lt;
import love.graphics.GraphicsModule as Lg;
import love.Love;
import love.event.EventModule as Event;
import love.keyboard.KeyboardModule as Keyboard;
import love.mouse.MouseModule as Mouse;

import backend.Window;

class GameLoop {
	static var window: Window;

	static function load(args: Array<String>) {
		Main.load(args);
	}

	static function update(dt: Float) {
		Main.update(window, dt);
	}

	static function draw() {
		Main.draw(window);
	}

	static function mousepressed(x: Float, y: Float, button: Float, istouch: Bool) {
		Main.mousepressed(x, y, Std.int(button));
	}

	static function mousereleased(x: Float, y: Float, button: Float, istouch: Bool) {
		Main.mousereleased(x, y, Std.int(button));
	}

	static function mousemoved(x: Float, y: Float, dx: Float, dy: Float, istouch: Bool) {
		Main.mousemoved(x, y, dx, dy);
	}

	static function wheelmoved(x: Float, y: Float) {
		Main.wheelmoved(x, y);
	}

	static function textinput(str: String) {
		Main.textinput(str);
	}

	static function keypressed(key: String, scan: String, isrepeat: Bool) {
		if (key == "escape" && Keyboard.isDown("lshift", "rshift")) {
			Event.quit();
		}

		Main.keypressed(key, scan, isrepeat);
	}

	static function keyreleased(key: String) {
		Main.keyreleased(key);
	}

	static function real_run() {
		window = new Window();
		window.open(1920, 1080);

		Lm.setRandomSeed(lua.Os.time());
		var args = lua.Lib.tableToArray(untyped __lua__("arg"));
		args.splice(0, 1);
		load(args);

		Love.mousepressed  = mousepressed;
		Love.mousereleased = mousereleased;
		Love.mousemoved    = mousemoved;
		Love.wheelmoved    = wheelmoved;
		Love.textinput     = textinput;
		Love.keypressed    = keypressed;
		Love.keyreleased   = keyreleased;

		// We don't want the first frame's dt to include time taken by love.load.
		Lt.step();
	
		var dt: Float = 0;
	
		// Main loop time.
		while (true) {
			// Process events.
			window.poll_events();
			untyped __lua__('
				for name, a,b,c,d,e,f in love.event.poll() do
					if name == "quit" then
						if not {0} or not {0}() then
							return a
						end
					end
					love.handlers[name](a,b,c,d,e,f)
				end
			', Main.quit);
	
			// Update dt, as we'll be passing it to update
			Lt.step();
			dt = Lt.getDelta();
			dt = Math.min(dt, 1/30);
			dt = Math.max(dt, 1/2000);

#if imgui
			if (Keyboard.isDown("tab")) {
				dt *= 4;
			}
#end

			// Call update and draw
			update(dt);
	
			if (window.is_open()) {
				var bg = Lg.getBackgroundColor();
				Lg.clear(bg.r, bg.g, bg.b, bg.a);
				Lg.origin();
				draw();
				window.present();
			}

			Lt.sleep(0.001);
		}
	}

	public static inline function run() {
		Love.run = real_run;
	}
}
