package tools.haxelib;

import haxe.ds.Option;

#if macro
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;

using haxe.macro.Tools;
#end

typedef Validatable = {
	function validate():Option<{ error: String }>;
}

class Validator {
	#if macro
	static var ARG = 'v';
	var pos:Position;
	var IARG:Expr;
	function new(pos) {
		this.pos = pos;
		IARG = macro @:pos(pos) $i{ARG};
	}
	
	function doCheck(t:Type, e:Expr) {
		var ct = t.toComplexType();
		return
			macro @:pos (function ($ARG : $ct) ${makeCheck(t)})($e);
	}
	
	function isAtom(s:String)
		return switch s {
			case 'String', 'Int', 'Bool', 'Float': true;
			default: false;
		}
	
	function enforce(type:String)
		return 
			macro @:pos(pos) if (!Std.is($i{ARG}, $i{type})) throw '$type expected';
	
	function rename(e:Expr) 
		return switch e {
			case macro $i{name} if (name == '_'): IARG;
			default: e.map(rename);
		}
			
	function makeCheck(t:Type):Expr 
		return
			switch Context.follow(t) {
				case TAnonymous(_.get().fields => fields): 
					
					var block:Array<Expr> = [
						for (f in fields)
						if (f.kind.match(FVar(AccNormal, _)))
						{
							var name = f.name;
							var rec = doCheck(f.type, macro @:pos(pos) $IARG.$name);
							
							if (f.meta.has(':requires')) {
								var body = [];
								for (m in f.meta.get()) 
									if (m.name == ':requires')
										for (p in m.params) 
											switch p {
												case macro $msg => $p:
													body.push(rename(
														macro @:pos(pos) if (!$p) throw $msg
													));
												default: 
													Context.error('Should be "<message>" =>" <condition>', p.pos);	
											}
										//{
											//p = rename(p);
											//cond = macro @:pos(pos) $p && $cond;
										//}
								
								var t = f.type.toComplexType();
								rec = macro @:pos(pos) {
									$rec;
									(function($ARG : $t) $b{body})($IARG.$name);
								}
							}								
							
							if (f.meta.has(':optional')) {
								rec = macro @:pos(pos) if (Reflect.hasField($IARG, $v{name}) && $IARG.$name != null) $rec;
							}
							else
								rec = macro @:pos(pos) 
									if (!Reflect.hasField($IARG, $v{name})) 
										throw ("missing field " + $v{name});
									else 
										$rec;
							
							rec;
						}
					];
					
					block.unshift(
						macro @:pos(pos) if (!Reflect.isObject($IARG)) throw 'object expected'
					);
					
					macro @:pos(pos) $b{block};
					
				case _.toString() => atom if (isAtom(atom)): 
					
					enforce(atom);
					
				case TInst(_.get().module => 'Array', [p]):
					
					macro @:pos(pos) {
						${enforce('Array')};
						for ($IARG in $IARG)
							${doCheck(p, IARG)};
					}
				
				case TAbstract(_.get() => { from: [ { t: t, field: null } ] }, _):
					
					makeCheck(t);
					
				case TAbstract(_.get() => a, _) if (a.meta.has(':enum')):
					var name = a.module + '.' + a.name;
					var options:Array<Expr> = [
						for (f in a.impl.get().statics.get()) 
						if (f.kind.match(FVar(_, _)))
						macro @:pos(pos) $p{(name+'.'+f.name).split('.')}
					];
					
					macro if (!Lambda.has($a { options }, $IARG)) throw 'Invalid value ' + $IARG + ' for ' + $v { a.name };
					
				case TAbstract(_.get() => a, _):
					
					macro @:pos(pos) switch ($IARG : tools.haxelib.Validator.Validatable).validate() {
						case Some( { error: e } ): throw e;
						case None:
					}
					
				case TDynamic(k):
					var checker = makeCheck(k);
					var ct = k.toComplexType();
					macro @:pos(pos) {
						if (!Reflect.isObject($i{ARG})) throw 'object expected';
						for (f in Reflect.fields($i{ARG})) {
							var $ARG:$ct = Reflect.field($i{ARG}, f);
							$checker;
						}
					}
				case v: 
					throw t.toString();
			}
	#end		
	macro static public function validate(e:Expr) 
		return 
			new Validator(e.pos).doCheck(Context.typeof(e), e);
}