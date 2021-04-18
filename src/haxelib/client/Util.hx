package haxelib.client;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

using haxe.macro.Tools;
#end

using StringTools;

macro function getValues(typePath:Expr):Expr {
	final type = Context.getType(typePath.toString());

	// Switch on the type and check if it's an abstract with @:enum metadata
	switch (type.follow()) {
		case TAbstract(_.get() => ab, _) if (ab.meta.has(":enum")):
			final valueExprs = [];
			for (field in ab.impl.get().statics.get()) {
				if (field.meta.has(":enum") && field.meta.has(":impl")) {
					final fieldName = field.name;
					valueExprs.push(macro $typePath.$fieldName);
				}
			}
			return macro $a{valueExprs};
		default:
			throw new Error(type.toString() + " should be enum abstract", typePath.pos);
	}
}
