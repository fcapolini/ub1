package reapp.macro;

import reapp.app.*;
import reapp.core.*;
import haxe.macro.Expr;
//#if macro
import haxe.macro.Context;
import haxe.macro.ExprTools;
import haxe.macro.MacroStringTools;
import haxe.macro.TypeTools;
//#end

// 1) replace APP calls with new ReApp()
// 2) replace vars in callbacks with new Re<>()
// 3) replace references to those vars with id.value
// 2) replace TAG calls with new ReTag()
class RE {

	macro public static function APP(doc:Expr, callback:Expr) {
//#if macro
		var scope:ReScope = {
			parent: null,
			reactive: true,
			names: new Map<String, Bool>(),
		}
		callback = patchCallback(callback, scope);
		var ret = macro {
			var _ctx_ = new ReContext();
			new ReApp($doc, _ctx_, $callback);
		}
		trace(scope.names);
		//trace(ExprTools.toString(ret));
		return ret;
//#end
	}

//#if macro
	public static function TAG(tag:Expr, callback:Expr) {
		var scope:ReScope = {
			parent: null,
			reactive: true,
			names: new Map<String, Bool>(),
		}
		callback = patchCallback(callback, scope);
		var ret = macro new ReTag(_n_, $tag, $callback);
		trace(scope.names);
		//trace(ExprTools.toString(ret));
		return ret;
	}

	static function patchCallback(callback:Expr, scope:ReScope): Expr {
		callback = formatStrings(callback);
		switch (callback.expr) {
			case ExprDef.EFunction(_, f):
				return {
					expr: ExprDef.EFunction(null, {
						args: [{
							name:'_n_', type:getComplexType('ReElement')
						}, {
							name:'_ctx_', type:getComplexType('ReContext')
						}],
						ret: null,
						expr: patchCallbackBody(f.expr, scope),
					}),
					pos: callback.pos,
				}
			default:
				error('function expected', callback.pos);
				return macro null;
		}
	}

	static function formatStrings(e:Expr): Expr {
		return switch (e.expr) {
			case ExprDef.EConst(Constant.CString(s)):
				formatString(s, e.pos);
			default:
				ExprTools.map(e, formatStrings);
		}
	}

	static function patchCallbackBody(block:Expr, scope:ReScope): Expr {
		switch (block.expr) {
			case ExprDef.EBlock(ee):
				return patchIds(block, scope);
			default:
				error('block expected', block.pos);
				return macro null;
		}
	}

	static function patchIds(e:Expr, scope:ReScope): Expr {
		// pass1: replace declared vars with Re<> instances
		function f1(e:Expr, scope:ReScope) {
			function f(e:Expr) {
				return switch (e.expr) {
					case EFunction(n,f):
						var s = makeFunctionScope(scope, f);
						ExprTools.map(e, function(e:Expr) return f1(e, s));
					case EVars(vv):
						scope.reactive ?
							patchVars(vv, e.pos, scope) :
							ExprTools.map(e, f);
					default:
						ExprTools.map(e, f);
				}
			}
			return f(e);
		}
		// pass2: replace relevant references with <id>.value
		function f2(e:Expr, scope:ReScope) {
			function f(e:Expr) {
				return switch (e.expr) {
					case EFunction(n,f):
						var s = makeFunctionScope(scope, f);
						ExprTools.map(e, function(e:Expr) return f1(e, s));
					case EConst(CIdent(id)):
						patchId(id, e.pos, scope);
					default:
						ExprTools.map(e, f);
				}
			}
			return f(e);
		}
		return e != null ? f2(f1(e, scope), scope) : null;
	}

	static function makeFunctionScope(scope:ReScope, f:Function) {
		var ret:ReScope = {
			parent: scope,
			reactive: false,
			names: new Map<String, Bool>(),
		}
		for (a in f.args) {
			ret.names.set(a.name, false);
		}
		return ret;
	}

	static function patchVars(vv1:Array<Var>,
	                          pos:Position,
	                          scope:ReScope): Expr {
		var vv2 = new Array<Var>();
		for (v1 in vv1) {
			//scope.names.set(v1.name, true);
			vv2.push(patchVar(v1, pos, scope));
		}
		return {
			expr: ExprDef.EVars(vv2),
			pos: pos,
		}
	}

	static function patchVar(v:Var,
	                         pos:Position,
	                         scope:ReScope): Var {
		var ret:Var = {
			name: v.name,
			type: v.type,
			expr: v.expr, //patchIds(v.expr, scope),
		}
		ensureVarType(ret);
		if (ret.expr != null) {
			switch (ret.expr.expr) {
				case EFunction(n,f):
					scope.names.set(ret.name, false);
				case ENew(t,p):
					scope.names.set(ret.name, false);
				default:
					var callParams:Array<Expr> = null;
					var tag = switch(ret.expr.expr) {
						case ECall(e,pp):
							callParams = pp;
							switch (e.expr) {
								case EConst(CIdent(s)): s == 'TAG';
								default: false;
							}
						default:
							false;
					}
					if (tag) {
						trace('TAG found');
						if (callParams.length == 2) {
							scope.names.set(ret.name, false);
							ret.expr = TAG(callParams[0], callParams[1]);
						} else {
							error('bad TAG parameters', ret.expr.pos);
						}
					} else {
						scope.names.set(ret.name, true);
						ret.expr = {
							expr: ExprDef.ENew({
								pack: ['reapp', 'core'],
								name: 'Re',
								params: [TypeParam.TPType(ret.type)],
							}, [
								macro _ctx_,
								ret.expr,
								macro _n_.add,
							]),
							pos: pos,
						}
					}
			}
			ret.type = null;
		}
		return ret;
	}

	static function ensureVarType(v:Var) {
		if (v.type == null && v.expr != null) {
			try {
				var type = untyped Context.typeof(v.expr);
				v.type = untyped Context.toComplexType(type);
			} catch (ignored:Dynamic) {}
		}
		if (v.type == null) {
			v.type = ComplexType.TPath({pack:[], name:'Dynamic'});
		}
	}

	static function patchId(id:String, pos:Position, scope:ReScope): Expr {
		trace('patchId($id)');
		while (scope != null) {
			if (scope.names.get(id)) {
				return parse('$id.value', pos);
			}
			scope = scope.parent;
		}
		return parse('$id', pos);
	}
//#end

	// =========================================================================
	// util
	// =========================================================================

	static function getComplexType(name:String): ComplexType {
#if macro
		return TypeTools.toComplexType(Context.getType(name));
#else
		return null;
#end
	}

	static function parse(src:String, pos:Position): Expr {
#if macro
		return Context.parse(src, pos);
#else
		return null;
#end
	}

	static function error(msg:String, pos:Position) {
#if macro
		Context.error(msg, pos);
#end
	}

	static function formatString(s:String, pos:Position): Expr {
#if macro
		return MacroStringTools.formatString(s, pos);
#else
		return null;
#end
	}

}

typedef ReScope = {
	parent: ReScope,
	reactive: Bool,
	names: Map<String, Bool>,
}
