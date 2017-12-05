package ui;

#if imgui
import imgui.MenuBar.*;
import imgui.Widget;

import Main.*;
import Main.WindowType;
import love.mouse.MouseModule as Mouse;
import love.event.EventModule as Event;
#end

class MainMenu {
	public static function draw() {
#if imgui
		editing = showing_menu(WindowType.EditorUI);
		if (!Mouse.getRelativeMode() || editing) {
			if (begin_main()) {

				if (begin_menu("File")) {
					if (menu_item("Load Game")) {
						player.load();
					}
					if (menu_item("Save Game")) {
						player.save();
					}
					Widget.separator();
					if (menu_item("Reload Map")) {
						World.reload();
						respawn();
					}
					if (menu_item("Save Map")) {
						World.save();
					}
					Widget.separator();
					if (menu_item("Exit")) {
						Event.quit();
					}
					end_menu();
				}

				if (begin_menu("Debug")) {
					if (begin_menu("Player")) {
						if (menu_item("Respawn")) {
							respawn();
						}
						end_menu();
					}
					end_menu();
				}

				if (begin_menu("Window")) {
					Widget.separator();
					if (menu_item("Camera...")) {
						toggle_window(WindowType.CameraDebug);
					}
					if (menu_item("Editor...", "F1")) {
						toggle_window(WindowType.EditorUI);
					}
					if (menu_item("Profiler...", "F3")) {
						toggle_window(WindowType.ProfilerUI);
					}
					if (menu_item("Log...")) {
						toggle_window(WindowType.Log);
					}
					end_menu();
				}

			}
			end_main();
		}
	}
}
#else
	}
}
#end
