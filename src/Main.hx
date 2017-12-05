import love.Love;
import love.keyboard.KeyboardModule as Keyboard;
import love.timer.TimerModule as Timer;
import backend.Input as PlatformInput;

#if imgui
import imgui.*;
#end

import ui.MainMenu;
import systems.Render;
import systems.PlayerController;
import Profiler.SegmentColor;
import math.Vec3;

import editor.Editor;

import backend.GameLoop;
import backend.Gc;
import backend.Window as PlatformWindow;
import ui.Anchor;

import components.Player;

enum WindowType {
	EditorUI;
	CameraDebug;
	Log;
	ProfilerUI;
}

class Main {
	static var world: World;
	static var open_windows: Array<WindowType> = [
		EditorUI
	];
	public static var player: Player;
	public static var debug_mode = false;
	public static var editing = false;

	static var show_profiler = false;

	public static function showing_menu(window) {
		return open_windows.indexOf(window) >= 0;
	}

	public static function toggle_window(window) {
		var idx = open_windows.indexOf(window);
		if (idx >= 0) {
			open_windows.splice(idx, 1);
			return;
		}
		open_windows.push(window);
	}

	static function main() {
		return GameLoop.run();
	}

	public static function load(args: Array<String>) {
		var boot_editor = false;
		for (v in args) {
			if (v == "--perf") {
				show_profiler = true;
				continue;
			}
			if (v == "--editor") {
				boot_editor = true;
				continue;
			}
		}

		if (boot_editor) {
			toggle_window(WindowType.EditorUI);
			editing = true;
			PlatformInput.set_relative(false);
		}

		if (show_profiler) {
			toggle_window(WindowType.ProfilerUI);
		}

		Language.load("en");

		// love.window.WindowModule.maximize();

		#if imgui
		ui.Helpers.setup_imgui();
		#end

		PlatformInput.set_relative(true);

		GameInput.init();
		Editor.init();

		var p = new Player();
		p.load();
		player = p;

		Render.init();
		Time.init();
		World.init(p);

		var spawn = new Vec3(1.0, 1.0, 0.0);
		Profiler.load_zone();
		Zone.load("assets/maps/world.fresh");
		Player.spawn(spawn, player);

		Profiler.start_frame();

		// systems.Hud.add_subtitle({
		// 	text: "this is a test of the emergency broadcast system",
		// 	duration: 5
		// });

		Love.resize = resize;
		Love.focus  = focus;
	}

	static function resize(w: Float, h: Float) {
		Render.resize(w, h);
	}

	public static function mousepressed(x: Float, y: Float, button: Float) {
#if imgui
		if (!PlatformInput.get_relative()) {
			Input.mousepressed(button);
		}
#end
	}

	public static function mousereleased(x: Float, y: Float, button: Float) {
#if imgui
		if (!PlatformInput.get_relative()) {
			Input.mousereleased(button);
		}
#end
	}

	public static function mousemoved(x: Float, y: Float, dx: Float, dy: Float) {
#if imgui
		if (!PlatformInput.get_relative()) {
			Input.mousemoved(x, y);
		}
#end
		if (PlatformInput.get_relative()) {
			PlayerController.mouse_moved(dx, dy);
		}
	}

	public static function wheelmoved(x: Float, y: Float) {
#if imgui
		if (!PlatformInput.get_relative()) {
			Input.wheelmoved(y);
		}
#end
	}

	public static function textinput(str: String) {
#if imgui
		if (!PlatformInput.get_relative()) {
			Input.textinput(str);
		}
#end
	}

	public static function keypressed(key: String, scan: String, isrepeat: Bool) {
		if (!isrepeat) {
			GameInput.keypressed(key);
		}

		if (key == "escape") {
			PlatformInput.set_relative(!PlatformInput.get_relative());
		}
#if imgui
		if (!PlatformInput.get_relative() || key == "escape") {
			Input.keypressed(key);
		}
#end
	}

	public static function keyreleased(key: String) {
		GameInput.keyreleased(key);

#if imgui
		if (!PlatformInput.get_relative()) {
			Input.keyreleased(key);
		}
#end
	}

	public static function respawn() {
		Player.spawn(Editor.cursor.as_absolute(), player);
	}

	static var has_focus = true;

	static function focus(focus: Bool) {
		has_focus = focus;
	}

	static var dt: Float = 0;
	public static inline function update(window: PlatformWindow, _dt) {
		Anchor.update(window);
		dt = _dt;
	}

	public static function draw(window) {
		MainMenu.draw();

		GameInput.update(dt);
		GameInput.bind(GameInput.Action.Debug_F5, function() {
			// Event.quit("restart");
			return true;
		});

		GameInput.bind(GameInput.Action.Debug_F1, function() {
			PlatformInput.set_relative(showing_menu(EditorUI));
			toggle_window(WindowType.EditorUI);
			return true;
		});

		// significantly reduce framerate if out of focus while in editor mode.
		if (editing && !has_focus) {
			Timer.sleep(0.1);
		}

		Profiler.start_frame();
		Time.update(dt);
		World.update(dt);
		Profiler.push_block("GC", new SegmentColor(0.5, 0.0, 0.0));
		Gc.run(false);
		Profiler.pop_block();
		Profiler.end_frame();
#if imgui
		ImGui.render();
		ImGui.new_frame();
#end
	}

	public static function quit(): Bool {
#if imgui
		ImGui.shutdown();
#end

		return false;
	}
}
