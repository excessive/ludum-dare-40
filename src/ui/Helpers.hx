package ui;

#if imgui
import math.Vec3;
import math.Quat;
import math.Utils;

import imgui.Window;
import imgui.Widget;
import imgui.Style;
import imgui.ImGui;

class Helpers {
	public static function setup_imgui() {
		var scale = 1.0;
		if (love.Love.getVersion().minor == 10) {
			scale = love.window.WindowModule.getPixelScale();
		}

		// ImGui.set_global_font("assets/fonts/Inconsolata-Regular.ttf", 16*scale, 0, 0, 2, 2);
		ImGui.set_global_font("assets/fonts/NotoSans-Regular.ttf", 16*scale, 0, 0, 2, 2);
		Style.push_color("Text", 1.00, 1.00, 1.00, 1.00);
		Style.push_color("WindowBg", 0.07, 0.07, 0.08, 0.98);
		Style.push_color("PopupBg", 0.07, 0.07, 0.08, 0.98);
		Style.push_color("CheckMark", 0.15, 1.0, 0.4, 0.91);
		Style.push_color("Border", 0.70, 0.70, 0.70, 0.20);
		Style.push_color("FrameBg", 0.80, 0.80, 0.80, 0.12);
		Style.push_color("FrameBgHovered", 0.04, 0.50, 0.78, 1.00);
		Style.push_color("FrameBgActive", 0.15, 0.52, 0.43, 1.00);
		Style.push_color("TitleBg", 0.15, 0.52, 0.43, 0.76);
		Style.push_color("TitleBgCollapsed", 0.11, 0.22, 0.23, 0.50);
		Style.push_color("TitleBgActive", 0.15, 0.52, 0.43, 1.00);
		Style.push_color("MenuBarBg", 0.07, 0.07, 0.11, 0.76);
		Style.push_color("ScrollbarBg", 0.26, 0.29, 0.33, 1.00);
		Style.push_color("ScrollbarGrab", 0.40, 0.43, 0.47, 0.76);
		Style.push_color("ScrollbarGrabHovered", 0.28, 0.81, 0.68, 0.76);
		Style.push_color("ScrollbarGrabActive", 0.96, 0.66, 0.06, 1.00);
		Style.push_color("SliderGrab", 0.28, 0.81, 0.68, 0.47);
		Style.push_color("SliderGrabActive", 0.96, 0.66, 0.06, 0.76);
		Style.push_color("Button", 0.22, 0.74, 0.61, 0.47);
		Style.push_color("ButtonHovered", 0.00, 0.48, 1.00, 1.00);
		Style.push_color("ButtonActive", 0.83, 0.57, 0.04, 0.76);
		Style.push_color("Header", 0.22, 0.74, 0.61, 0.47);
		Style.push_color("HeaderHovered", 0.07, 0.51, 0.92, 0.76);
		Style.push_color("HeaderActive", 0.96, 0.66, 0.06, 0.76);
		Style.push_color("Column", 0.22, 0.74, 0.61, 0.47);
		Style.push_color("ColumnHovered", 0.28, 0.81, 0.68, 0.76);
		Style.push_color("ColumnActive", 0.96, 0.66, 0.06, 1.00);
		Style.push_color("ResizeGrip", 0.22, 0.74, 0.61, 0.47);
		Style.push_color("ResizeGripHovered", 0.28, 0.81, 0.68, 0.76);
		Style.push_color("ResizeGripActive", 0.96, 0.66, 0.06, 0.76);
		Style.push_color("CloseButton", 0.00, 0.00, 0.00, 0.47);
		Style.push_color("CloseButtonHovered", 0.00, 0.00, 0.00, 0.76);
		Style.push_color("PlotLinesHovered", 0.22, 0.74, 0.61, 1.00);
		// Style.push_color("PlotHistogram", 0.78, 0.21, 0.21, 1.0);
		Style.push_color("PlotHistogram", 0.15, 0.52, 0.43, 1.00);
		Style.push_color("PlotHistogramHovered", 0.96, 0.66, 0.06, 1.00);
		Style.push_color("TextSelectedBg", 0.22, 0.74, 0.61, 0.47);
		Style.push_color("ModalWindowDarkening", 0.20, 0.20, 0.20, 0.69);

		ImGui.new_frame();
	}

	public static function any_value(label, v: Dynamic) {
		Widget.text(label + ": " + Std.string(v));
	}

	public static function drag_vec3(label, v: Vec3, enabled = true, speed: Float = 0.1, min: Float = -9999, max: Float = 9999) {
		var r = Widget.drag_float3(label, v[0], v[1], v[2], speed, min, max);
		if (!enabled) {
			return;
		}
		v[0] = r.f1;
		v[1] = r.f2;
		v[2] = r.f3;
	}

	public static function input_vec3(label, v: Vec3, enabled = true) {
		var r = Widget.input_float3(label, v[0], v[1], v[2]);
		if (!enabled) {
			return;
		}
		v[0] = r.f1;
		v[1] = r.f2;
		v[2] = r.f3;
	}

	public static function input_quat(label, q: Quat, enabled = true) {
		var eul = q.to_euler();
		var result = Widget.drag_float3(label, Utils.deg(eul[0]), Utils.deg(eul[1]), Utils.deg(eul[2]), 0.5, -180, 180);
		if (!enabled) {
			return;
		}
		eul[0] = Utils.rad(result.f1);
		eul[1] = Utils.rad(result.f2);
		eul[2] = Utils.rad(result.f3);
		var tmp = Quat.from_euler(eul);
		for (i in 0...4) {
			q[i] = tmp[i];
		}
	}
}

#end
