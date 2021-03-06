package pageamp.lib;

typedef Props = Dynamic;

class PropertyTools {
	public static function get(props:Props, key:String, ?defval:Dynamic):Dynamic {
		var val = (props != null ? Reflect.getProperty(props, key) : null);
		return (val != null ? val : defval);
	}

	public static function getString(props:Props, key:String, ?defval:String):String {
		return cast get(props, key, defval);
	}

	#if (!debug)
	inline
	#end
	public static function getInt(props:Props, key:String, defval = 0):Int {
		return Util.toInt2(get(props, key), defval);
	}

	public static function set(props:Props, key:String, val:Dynamic):Props {
		if (val != null) {
			if (props == null) {
				props = {};
			}
			Reflect.setProperty(props, key, val);
		} else if (props != null) {
			Reflect.deleteField(props, key);
		}
		return props;
	}

	public static function set2(props:Props, key:String, val:Dynamic):Props {
		if (props == null) {
			props = {};
		}
		Reflect.setProperty(props, key, val);
		return props;
	}

	public static function exists(props:Props, key:String):Bool {
		return (props != null ? Reflect.hasField(props, key) : false);
	}

	public static function remove(props:Props, key:String) {
		if (props != null) {
			Reflect.deleteField(props, key);
		}
	}

	public static inline function keys(props:Props):Array<String> {
		return props != null ? Reflect.fields(props) : [];
	}

	public static function ensure(props:Props, key:String, val:Dynamic):Props {
		if (!exists(props, key)) {
			props = set(props, key, val);
		}
		return props;
	}

	public static function ensure2(props:Props, key:String, val:Dynamic):Props {
		props = (props != null ? props : {});
		if (!exists(props, key)) {
			set2(props, key, val);
		}
		return props;
	}

	public static function ensureWith(props:Props, with:Props):Props {
		for (key in keys(with)) {
			props = ensure(props, key, get(with, key));
		}
		return props;
	}

	public static function clone(props:Props):Props {
		var ret:Props = null;
		if (props != null) {
			ret = {};
			for (key in keys(props)) {
				set(ret, key, get(props, key));
			}
		}
		return ret;
	}

	public static function overwriteWith(props:Props, with:Props):Props {
		var ret:Props = (props != null ? props : {});
		if (with != null) {
			for (key in keys(with)) {
				set(ret, key, get(with, key));
			}
		}
		return ret;
	}

	public static function fillWith(dst:Props, src:Props, overwrite = false):Props {
		var ret:Props = (dst != null ? dst : {});
		if (src != null) {
			for (key in keys(src)) {
				if (overwrite || !exists(dst, key)) {
					set(ret, key, get(src, key));
				}
			}
		}
		return ret;
	}

	public static function overwrite(props:Props, key:String, val:Dynamic, orRemove = false):OldProp {
		var ret:OldProp = {
			existed: exists(props, key),
			key: key,
			val: get(props, key)
		};
		orRemove ? remove(props, key) : set(props, key, val);
		return ret;
	}

	public static function restore(props:Props, old:OldProp) {
		if (old != null) {
			old.existed ? set(props, old.key, old.val) : remove(props, old.key);
		}
	}
}

typedef OldProp = {
	existed:Bool,
	key:String,
	val:Dynamic
}
