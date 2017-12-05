import ui.LogWindow;

enum Level {
	Debug;
	Info;
	Item;
	Quest;
	System;
}

class Log {
	public static function write(level: Level, msg: String) {
		var line = "[" + level.getName() + "] " + msg;
		LogWindow.push(line);
		Sys.println(line);
	}
}
