package pageamp.reactivity;

import pageamp.lib.Util;
import pageamp.lib.DoubleLinkedItem;
import pageamp.lib.BaseNode;
#if feffects
	import feffects.Tween;
#end

@:access(pageamp.reactivity.ReValue)
class ReScope extends BaseNode {
	public static inline var NOTNULL_FUNCTION = '__nn__';
	public var rootScope(get, null): ReScope;
	public inline function get_rootScope() return cast baseRoot;
	public var parentScope(get, null): ReScope;
	public inline function get_parentScope() return cast baseParent;
	public var childScopes(get, null): Array<ReScope>;
	public inline function get_childScopes() return cast baseChildren;
	public var context(default, null): ReContext;

	public var clonedScope(default,null):Bool;
	public var name(default,null):String;
	public var values(default,null):Map<String, ReValue>;
	public var refreshableList(default, null):DoubleLinkedItem;
	public var autoId(default,null) = 0;

	public function new(parent:ReScope,
						name:Null<String>,
						?plug:String,
						?index:Int,
						?cb:ReScope->Void) {
		clonedScope = false;
		this.name = name;
		if (parent != null) {
			new ReConst(this, 'parent', parent);
			name != null ? new ReConst(parent, name, this) : null;
			context = parent.context;
			new ReConst(this, 'animate', animate);
			new ReConst(this, 'delayedSet', delayedSet);
		} else {
			new ReConst(this, 'root', this);
			name != null ? new ReConst(this, name, this) : null;
			context = new ReContext(this);
			new ReConst(this, 'null', null);
			new ReConst(this, 'true', true);
			new ReConst(this, 'false', false);
			new ReConst(this, 'trace', Reflect.makeVarArgs(function(el) {
				//TODO: server-side logging
#if client
				var inf = context.interp.posInfos();
				var v = el.shift();
				if (el.length > 0)
					inf.customParams = el;
				haxe.Log.trace(Std.string(v), inf);
#end
			}));
			new ReConst(this, 'log', function(s) {
				//TODO: server-side logging
#if client
				js.Syntax.code('console.log(s)');
#end
			});
			// new ReConst(this, NOTNULL_FUNCTION, Util.orEmpty);
			//#if (js || php)
				// NOTE: a logic expression like "msg [[1, 0]]" is wrong, but
				// it turns into "'msg ' + __nn__(1, 0)"' so hscript's parser
				// sees nothing wrong with it.
				// In JS and PHP __nn__() simply ignores the second argument,
				// but this fails in Haxe interp and in Java.
				// To mitigate the problem we implement __nn__() as a vararg function
				// in targets other than JS and PHP.
				new ReConst(this, NOTNULL_FUNCTION, Util.orEmpty);
			// #else
			// 	// Ooops, we cannot do that...
			// 	// we may replace the __nn__ call with an inline conditional expression
			// 	// in ReParser so hscript's will pick up the error
			// 	new ReConst(this, NOTNULL_FUNCTION, Util.orEmptyVararg);
			// #end
			new ReConst(this, 'int', (v) -> Std.parseInt(v+''));
			new ReConst(this, 'string', (v) -> Std.string(v));
			new ReConst(this, 'trim', function(v:Dynamic): String {
				return v != null ? StringTools.trim(Std.string(v)) : '';
			});
			new ReConst(this, 'upperCase', function(v:Dynamic): String {
				return v != null ? '$v'.toUpperCase() : '';
			});
			new ReConst(this, 'lowerCase', function(v:Dynamic): String {
				return v != null ? '$v'.toLowerCase() : '';
			});
			new ReConst(this, 'capitalize', function(s:String): String {
				s == null ? s = '' : s;
				return ~/((^\w)|(\s+\w))/g.map(s, function(re:EReg): String {
					return re.matched(1).toUpperCase();
				});
			});
			new ReConst(this, 'regex', (v, opt='') -> {
				return v != null ? new EReg(Std.string(v), opt) : null;
			});
			new ReConst(this, 'Date', Date);
			new ReConst(this, 'Math', Math);
		}
		new ReConst(this, 'this', this);
		super(parent, plug, index, cb);
		// if (parent == null) {
		// 	context.refresh();
		// }
	}

	override public function removeChild(child:BaseNode):BaseNode {
		var childName = cast(child, ReScope).name;
		if (childName != null) {
			var v = values.get(childName);
			if (v != null && v.v == child) {
				values.remove(childName);
			}
		}
		return super.removeChild(child);
	}

	public function get(n:String, pull = true):Dynamic {
		var value = resolve(n);
		return (value != null ? value.get(pull) : null);
	}

	public function getLocal(n:String, pull = true):Dynamic {
		var value = values.get(n);
		return (value != null ? value.get(pull) : null);
	}

	#if !debug inline #end
	public function getLocalBool(key:String, defval:Bool, pull=true): Bool {
		var ret:Dynamic = getLocal(key, pull);
		return ret != null ? (ret == 'true' || ret == true) : defval;
	}

	#if !debug inline #end
	public function getLocalInt(key:String, defval:Int, pull=true): Int {
		return Util.toInt2(getLocal(key, pull), defval);
	}

	#if !debug inline #end
	public function getLocalFloat(key:String, defv:Float, pull=true): Float {
		return Util.toFloat2(getLocal(key, pull), defv);
	}

	#if !debug inline #end
	public function getLocalString(key:String, defv:String, pull=true): String {
		var ret = getLocal(key, pull);
		return (ret != null ? Std.string(ret) : defv);
	}

	public function set(n:String, v:Dynamic, push=true) {
		var value:ReValue = resolve(n);
		value != null ? value.set(v, push) : new ReValue(this, n, v);
	}

	public function trigger(n:String) {
		var value:ReValue = resolve(n);
		value != null ? value.trigger() : null;
	}

	public function exists(n:String) {
		return ReInterp.ENABLE_UNKNOWN_VAR_EXCEPTION ? values.exists(n) : true;
	}

	public function addValue(name:String, value:ReValue, refreshable = true) {
		name == null ? name = AUTOID_PREFIX + (++autoId) : null;
		value.k = name;
		ensureValues().set(name, value);
		refreshable ? value.linkAfter(ensureRefreshableList()) : null;
	}

	public inline function refresh(): ReScope {
		context.refresh(this);
		return this;
	}

#if utest
	override public function assertEquals(bn:pageamp.lib.BaseNode, ?msg:String) {
		var s:ReScope = cast bn;
		utest.Assert.equals(clonedScope, s.clonedScope, msg);
		utest.Assert.equals(name, s.name, msg);
		utest.Assert.equals(values != null, s.values != null, msg);
		super.assertEquals(bn, msg);
	}

	public function countScopes() {
		var f = null;
		f = function(scope:ReScope) {
			var ret = 1;
			for (child in scope.childScopes) {
				ret += child.countScopes();
			}
			return ret;
		}
		return f(this);
	}

	public function countRefreshableValues() {
		var ret = 0, p = refreshableList;
		while (p.next != null) {
			ret++;
			p = p.next;
		}
		return ret;
	}
#end

	// =========================================================================
	// private
	// =========================================================================
	static inline var AUTOID_PREFIX = '-v';

	#if !debug inline #end
	function ensureValues() {
		return (values == null ? (values = new Map()) : values);
	}

	#if !debug inline #end
	function ensureRefreshableList() {
		return (refreshableList == null ?
			(refreshableList = new DoubleLinkedItem()) :
			refreshableList);
	}

	#if !debug inline #end
	function resolve(name:String):ReValue {
		var ret = (values != null ? values.get(name) : null);
		return ret == null ?
			(parentScope != null ? parentScope.resolve(name) : null) :
			ret;
	}

	function refreshScope() {
		var v:ReValue = cast refreshableList != null ? refreshableList.next : null;
		while (v != null) {
			v.get();
			v = cast v.next;
		}
		for (child in childScopes) {
			if (!child.clonedScope) {
				child.refreshScope();
			}
		}
	}

	// =========================================================================
	// animation
	// =========================================================================
#if feffects
	#if !java static #end var suffixRE = ~/([^\d^-^\.]+)\s*$/;
	var animations = new Map<String,ReScopeAnimation>();
#end

	//TODO: if value doesn't change, don't 'animate' it at all
	public function animate(key:String,
							val:Dynamic,
							secs=.0,
							delay=.0,
							?cb:Void->Void,
							?easingName:String): Void {
//        if (key.indexOf(':') >= 0) {
//            var p = key.split(':');
//            key = p[0];
//            easingName = p[1];
//        }
		var scope = this;
		var s = scope;
		while (s != null) {
			if (s.exists(key)) {
				scope = s;
				break;
			}
			s = s.parentScope;
		}
#if feffects
        var easing = switch(easingName) {
            case 'easeIn': feffects.easing.Cubic.easeIn;
            case 'easeOut': feffects.easing.Cubic.easeOut;
            default: feffects.easing.Cubic.easeInOut;
        }
		var animation:ReScopeAnimation = animations.get(key);
		if (animation != null) {
			// prevent starting
			animation.delay = null;
			if (animation.tween != null) {
				animation.tween.stop();
			}
		}
		animation = {
			scope: scope,
			key: key,
			delay: function() startAnimation(animation),
			val: val,
			secs: secs,
			easing: easing,
			tween: null,
			cb: cb
		};
		animations.set(key, animation);
		haxe.Timer.delay(animation.delay, Std.int(delay * 1000));
#else
		scope.delayedSet(key, val, delay, cb);
#end
	}

#if feffects
	static function startAnimation(a:ReScopeAnimation) {
		var v1 = toFloat(a.scope.get(a.key, false));
		var v2 = toFloat(a.val);
		var suffix = (suffixRE.match(a.val + '') ? suffixRE.matched(1) : null);
		var t = new Tween(v1, v2, Std.int(a.secs * 1000), a.easing);
//		feffects.easing.Cubic.easeInOut);
		if (suffix != null) {
			t.onUpdate(function(e) {
				a.scope.set(a.key, (Math.round(e * 100) / 100) + suffix);
			});
		} else {
			t.onUpdate(function(e) {
				a.scope.set(a.key, Math.round(e * 100) / 100);
			});
		}
		t.onFinish(function() {
			a.scope.set(a.key, a.val);
			a.scope.animations.remove(a.key);
			a.cb != null ? a.cb() : null;
		});
		t.start();
		a.delay = null;
		a.tween = t;
	}
#end

	#if !debug inline #end
public static function toFloat(s:Dynamic, defval=0): Float {
	var ret = Std.parseFloat(Std.string(s));
	return (ret != Math.NaN ? ret : defval);
}

	#if !debug inline #end
public static function toInt(s:Dynamic, defval=0): Int {
	var ret = Std.parseInt(Std.string(s));
	return (ret != null ? ret : defval);
}

	public function delayedSet(key:String, val:Dynamic, secs=.0, ?cb:Void->Void) {
#if !client
		var value = values.get(key);
		if (value != null) {
		    if (secs <= 0) {
    			context.delayedSet(this, key, val, cb);
			}
		}
#else
		function apply() {
			set(key, val);
			cb != null ? cb() : null;
		}
		if (secs == 0 && context.cycle < 2) {
			apply();
		} else {
			haxe.Timer.delay(apply, Std.int(secs * 1000));
		}
#end
	}

	public function delay(cb:Void->Void, secs=.0) {
#if !client
		context.delayedCall(cb);
#else
		if (secs == 0 && context.cycle < 2) {
			cb();
		} else {
			haxe.Timer.delay(cb, Std.int(secs * 1000));
		}
#end
	}

}

#if feffects
typedef ReScopeAnimation = {
	scope: ReScope,
	key: String,
	delay: Void->Void,
	val: Float,
	secs: Float,
	easing: Easing,
	tween: Tween,
	cb: Void->Void
}
#end
