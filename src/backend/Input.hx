package backend;

#if cpp
typedef NativeInput = backend.cpp.Input;
#elseif lua
typedef NativeInput = backend.love.Input;
#end

abstract Input(NativeInput) {
	public static inline function set_relative(enabled: Bool): Void {
		return NativeInput.set_relative(enabled);
	}
	public static inline function get_relative(): Bool {
		return NativeInput.get_relative();
	}
}
