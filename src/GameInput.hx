import love.joystick.GamepadButton;
import love.joystick.GamepadAxis;
import love.joystick.JoystickModule;
import love.joystick.Joystick;
import love.keyboard.KeyConstant;
import love.keyboard.KeyboardModule;
import math.Utils;
import math.Vec2;

enum Action {
	Jump;            // gamepad A (while weapon out: dodge)
	TrickA;          // gamepad X
	TrickB;          // gamepad Y
	CameraReverse;   // gamepad LB
	CameraRecenter;  // gamepad RB
	Walk;            // gamepad LS (while stopped: crouch)

	MenuToggle;      // gamepad start
	MenuUp;          // gamepad D-up
	MenuDown;        // gamepad D-down
	MenuLeft;        // gamepad D-left
	MenuRight;       // gamepad D-right
	MenuPrev;        // gamepad LB
	MenuNext;        // gamepad RB
	MenuConfirm;     // gamepad A
	MenuCancel;      // gamepad B

	// virtual inputs
	XLright;
	XLleft;
	YLup;
	YLdown;

	XRright;
	XRleft;
	YRup;
	YRdown;

	XLaxis;
	YLaxis;
	XRaxis;
	YRaxis;

	LTrigger;
	RTrigger;

	Debug_F1;
	Debug_F2;
	Debug_F3;
	Debug_F4;
	Debug_F5;
	Debug_F6;
	Debug_F7;
	Debug_F8;
	Debug_F9;
	Debug_F10;
	Debug_F11;
	Debug_F12;

	Invalid; // anything unbound
}

typedef ActionBinding = {
	var player: Null<Action>;
	var menu: Null<Action>;
}

@:publicFields
class InputState {
	var pressed: Float = -1;
	var value: Float = 0;
	var first_update: Bool = true;
	var deadzone: Float = 0.35;
	var updated: Bool = false;
	inline function new() {}
	inline function is_down() {
		return Utils.threshold(value, deadzone) && pressed >= 0;
	}
	inline function value_deadzone() {
		return Utils.deadzone(value, deadzone);
	}
	inline function first_press() {
		return is_down() && first_update;
	}
	function press(v: Float = 1) {
		if (pressed < 0) {
			first_update = true;
			pressed = 0;
		}
		updated = true;
		value = v;
	}
	function update(dt: Float) {
		if (!updated) {
			first_update = true;
			pressed = -1;
			value = 0;
		}
		if (pressed > 0) {
			first_update = false;
			updated = false;
		}
		if (is_down()) {
			pressed += dt;
		}
	}
}

class GameInput {
	static var callbacks = new Map<Action, Void->Bool>();
	static var active: Array<Action> = [];

	static var kb_mappings = [
		KeyConstant.W => { player: Action.YLup,    menu: Action.MenuUp },
		KeyConstant.S => { player: Action.YLdown,  menu: Action.MenuDown },
		KeyConstant.A => { player: Action.XLleft,  menu: Action.MenuLeft },
		KeyConstant.D => { player: Action.XLright, menu: Action.MenuRight },

		KeyConstant.Up    => { player: Action.YLup,    menu: Action.MenuUp },
		KeyConstant.Down  => { player: Action.YLdown,  menu: Action.MenuDown },
		KeyConstant.Left  => { player: Action.XLleft,  menu: Action.MenuLeft },
		KeyConstant.Right => { player: Action.XLright, menu: Action.MenuRight },

		KeyConstant.Kp8 => { player: Action.YRup,    menu: Action.MenuUp },
		KeyConstant.Kp2 => { player: Action.YRdown,  menu: Action.MenuDown },
		KeyConstant.Kp4 => { player: Action.XRleft,  menu: Action.MenuLeft },
		KeyConstant.Kp6 => { player: Action.XRright, menu: Action.MenuRight },

		KeyConstant.Lctrl  => { player: Action.TrickA,      menu: null },
		KeyConstant.Lshift => { player: Action.TrickB,       menu: null },
		KeyConstant.Rctrl  => { player: Action.TrickA,      menu: null },
		KeyConstant.Rshift => { player: Action.TrickB,       menu: null },

		// KeyConstant.Z         => { player: Action.AttackPrimary, menu: null },

		KeyConstant.Space     => { player: Action.Jump,        menu: null },
		KeyConstant.Kp0       => { player: Action.Jump,        menu: null },
		KeyConstant.Return    => { player: null,    menu: Action.MenuConfirm },
		KeyConstant.Escape    => { player: Action.MenuCancel,  menu: Action.MenuCancel },
		KeyConstant.Backspace => { player: null,               menu: Action.MenuCancel },
		// KeyConstant.R         => { player: Action.ReadyWeapon, menu: null }
	];

	static var gp_mappings = [
		GamepadButton.A => { player: Action.Jump,        menu: Action.MenuConfirm },
		GamepadButton.B => { player: null,       menu: Action.MenuCancel },
		GamepadButton.X => { player: Action.TrickA ,   menu: null },
		GamepadButton.Y => { player: Action.TrickB, menu: null },

		GamepadButton.Leftshoulder  => { player: Action.CameraReverse,  menu: Action.MenuPrev },
		GamepadButton.Rightshoulder => { player: Action.CameraRecenter, menu: Action.MenuNext },

		// GamepadButton.Dpup    => { player: Action.Map,           menu: Action.MenuUp },
		// GamepadButton.Dpdown  => { player: Action.InventoryUse,  menu: Action.MenuDown },
		// GamepadButton.Dpleft  => { player: Action.InventoryPrev, menu: Action.MenuLeft },
		// GamepadButton.Dpright => { player: Action.InventoryNext, menu: Action.MenuDown },

		GamepadButton.Leftstick  => { player: Action.Walk,   menu: null },
		// GamepadButton.Rightstick => { player: Action.Sprint, menu: null },

		GamepadButton.Start => { player: Action.MenuToggle,  menu: Action.MenuToggle },
		GamepadButton.Back  => { player: null, menu: Action.MenuCancel }
	];

	static function to_action(key: String): Action {
		switch (key) {
			case "f1":  return Action.Debug_F1;
			case "f2":  return Action.Debug_F2;
			case "f3":  return Action.Debug_F3;
			case "f4":  return Action.Debug_F4;
			case "f5":  return Action.Debug_F5;
			case "f6":  return Action.Debug_F6;
			case "f7":  return Action.Debug_F7;
			case "f8":  return Action.Debug_F8;
			case "f9":  return Action.Debug_F9;
			case "f10": return Action.Debug_F10;
			case "f11": return Action.Debug_F11;
			case "f12": return Action.Debug_F12;
		}
		return Action.Invalid;
	}

	static var input_state = new Map<Action, InputState>();

	public static function keypressed(key: String) {
		var a = to_action(key);
		if (a == Action.Invalid) {
			return;
		}
		active.push(a);
	}

	public static function keyreleased(key: String) {
		var a = to_action(key);
		if (a == Action.Invalid) {
			return;
		}

		var idx = active.indexOf(a);
		if (idx >= 0) {
			active.splice(idx, 1);
		}
	}

	static var gp_raw_axes = [
		GamepadAxis.Leftx  => 0.0,
		GamepadAxis.Lefty  => 0.0,
		GamepadAxis.Rightx => 0.0,
		GamepadAxis.Righty => 0.0,
		GamepadAxis.Triggerleft  => 0.0,
		GamepadAxis.Triggerright => 0.0,
	];

	/** return true from callback to remove it after this frame.
	**/
	public static function bind(input: Action, cb: Void->Bool) {
		callbacks[input] = cb;
	}

	public static function init() {
		var actions = Action.createAll();
		for (action in actions) {
			input_state[action] = new InputState();
		}
	}

	static function update_gamepads() {
		var joysticks = JoystickModule.getJoysticks();
		for (axis in gp_raw_axes.keys()) {
			gp_raw_axes[axis] = 0;
		}

		lua.PairTools.ipairsEach(joysticks, function(i: Int, js: Joystick) {
			if (!js.isGamepad()) {
				return;
			}

			for (axis in gp_raw_axes.keys()) {
				var v = js.getGamepadAxis(axis);
				if (axis == GamepadAxis.Lefty || axis == GamepadAxis.Righty) {
					v = -v;
				}
				if (Math.abs(v) > Math.abs(gp_raw_axes[axis])) {
					gp_raw_axes[axis] = v;
				}
			}

			for (button in gp_mappings.keys()) {
				var b = js.isGamepadDown(button);
				var m = gp_mappings[button].menu;
				if (m != null) {
					if (b) { input_state[m].press(1); }
				}
				var p = gp_mappings[button].player;
				if (p != null) {
					if (b) { input_state[p].press(1); }
				}
			}
		});
	}

	static function update_keyboard() {
		for (key in kb_mappings.keys()) {
			var bind = kb_mappings[key];
			var b = KeyboardModule.isDown(Std.string(key));
			var m = bind.menu;
			if (m != null) {
				if (b) { input_state[m].press(1); }
			}
			var p = bind.player;
			if (p != null) {
				if (b) { input_state[p].press(1); }
			}
		}
	}

	public static inline function pressed(gi: Action) {
		return input_state[gi].first_press();
	}

	public static inline function get_value(gi: Action) {
		return input_state[gi].value_deadzone();
	}

	// handle combined deadzones
	public static function move_xy() {
		var x = input_state[Action.XLaxis];
		var y = input_state[Action.YLaxis];
		var ret = new Vec2(x.value, y.value);
		var l = ret.length();
		if (l < Math.max(x.deadzone, y.deadzone)) {
			ret[0] = 0;
			ret[1] = 0;
		}
		if (l > 1) {
			ret.scale(1/l);
		}
		return ret;
	}

	public static function view_xy() {
		var x = input_state[Action.XRaxis];
		var y = input_state[Action.YRaxis];
		var ret = new Vec2(x.value, -y.value);
		var l = ret.length();
		if (l < Math.max(x.deadzone, y.deadzone)) {
			ret[0] = 0;
			ret[1] = 0;
		}
		if (l > 1) {
			ret.scale(1/l);
		}
		return ret;
	}

	public static function update(dt: Float) {
		for (run in active) {
			if (callbacks.exists(run)) {
				var fn = callbacks[run];
				if (fn()) {
					active.remove(run);
					break;
				}
			}
		}
		callbacks = new Map<Action, Void->Bool>();

		update_gamepads();
		update_keyboard();

		// combine kb and gamepad axes...
		var v = gp_raw_axes[GamepadAxis.Leftx];
		input_state[Action.XLright].value += Math.max(v, 0);
		input_state[Action.XLleft].value  += Math.max(-v, 0);

		v = gp_raw_axes[GamepadAxis.Lefty];
		input_state[Action.YLup].value   += Math.max(v, 0);
		input_state[Action.YLdown].value += Math.max(-v, 0);

		v = gp_raw_axes[GamepadAxis.Rightx];
		input_state[Action.XRright].value += Math.max(v, 0);
		input_state[Action.XRleft].value  += Math.max(-v, 0);

		v = gp_raw_axes[GamepadAxis.Righty];
		input_state[Action.YRup].value   += Math.max(v, 0);
		input_state[Action.YRdown].value += Math.max(-v, 0);

		input_state[Action.XLaxis].press(input_state[Action.XLright].value - input_state[Action.XLleft].value);
		input_state[Action.YLaxis].press(input_state[Action.YLup].value    - input_state[Action.YLdown].value);
		input_state[Action.XRaxis].press(input_state[Action.XRright].value - input_state[Action.XRleft].value);
		input_state[Action.YRaxis].press(input_state[Action.YRup].value    - input_state[Action.YRdown].value);

		for (action in input_state.keys()) {
			var bind = input_state[action];
			bind.update(dt);
		}
	}
}
