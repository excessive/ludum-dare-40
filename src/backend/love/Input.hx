package backend.love;

import love.mouse.MouseModule as Mouse;

class Input {
	public static inline function set_relative(enabled: Bool) {
		Mouse.setRelativeMode(enabled);
	}
	public static inline function get_relative() {
		return Mouse.getRelativeMode();
	}
}
