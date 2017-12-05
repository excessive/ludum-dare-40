package components;

enum TriggerState {
	Entered;
	Inside;
	Left;
}

enum TriggerType {
	Radius;
	Volume;
	RadiusInFront;
}

class Trigger {
	public var cb:        String;
	public var type:      TriggerType;
	public var range:     Float;
	public var max_angle: Float;
	public var enabled:   Bool;
	public var inside:    Bool = false;

	public function new(_cb: String, _type: TriggerType, _range: Float, _max_angle: Float = 0.5, _enabled: Bool = false) {
		this.cb        = _cb;
		this.type      = _type;
		this.range     = _range;
		this.max_angle = _max_angle;
		this.enabled   = _enabled;
	}
}
