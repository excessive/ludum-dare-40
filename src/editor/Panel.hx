package editor;

enum UIPanelCategory {
	Settings;
	Entities;
	Selection;
}

typedef UIPanelFn = Void->Void;

typedef UIPanelEntry = {
	var label: String;
	var cb: UIPanelFn;
}

typedef UIPanel = {
	var type: UIPanelCategory;
	var panels: Array<UIPanelEntry>;
	var dock_at: Null<String>;
}

class Panel {
	public static var panels: Array<UIPanel> = [];
	public static function register_panel(cat: UIPanelCategory, label: String, fn: UIPanelFn) {
		panels[cat.getIndex()].panels.push({
			label: label,
			cb: fn
		});
	}

}