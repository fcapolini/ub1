package reapp2.core;

import haxe.macro.Expr;
//#if macro
	import haxe.macro.Context;
	import haxe.macro.ExprTools;
	import haxe.macro.MacroStringTools;
	import reapp2.core.macro.ReMacroScan;
	import reapp2.core.macro.ReMacroGen;
//#end

class ReMacro {
	public static inline var CLASS_PREFIX = 'Node';
	public static inline var INSTANCE_ARRAY = '_';

	macro public static function APP(block:Expr) {
//#if macro
		var scope = ReMacroScan.scan(block);
		ReMacroScan.dumpScope(scope);
		return ReMacroGen.gen(scope);
//#end
	}

	public static function formatString(s:String, pos:Position): Expr {
#if macro
		return MacroStringTools.formatString(s, pos);
#else
		return null;
#end
	}

}
