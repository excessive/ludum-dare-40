package backend;

#if cpp
typedef NativeGc = backend.cpp.Gc;
#elseif lua
typedef NativeGc = backend.love.Gc;
#end

#if cppia
private
#end
abstract Gc(NativeGc) {
	// public inline function new() this = new NativeGc();

	/** Run a GC cycle. If `major`, run a complete collection. **/
	public static function run(major: Bool) NativeGc.run(major);

	/** GC Memory usage, in KiB. **/
	public static function mem_usage(): Int return NativeGc.mem_usage();
	public static function disable() NativeGc.disable();
	public static function enable() NativeGc.enable();
}
