package tools.haxelib;

import haxe.ds.Option;
import haxe.ds.StringMap;

class Template extends haxe.Template {
	static var fieldCache = new StringMap();
	static function fieldMap(type:Class<Dynamic>) {
		var name = Type.getClassName(type);
		if (!fieldCache.exists(name)) {
			fieldCache.set(name, [for (field in Type.getInstanceFields(type)) field => true]);
		}
		return fieldCache.get(name);
	}
	function tryField(o:Dynamic, field:String):Option<Dynamic> {
		return
			switch Type.typeof(o) {
				case TClass(c):
					var fields = fieldMap(c);
					if (fields.exists(field) || fields.exists('get_$field')) 
						Some(Reflect.getProperty(o, field));
					else {
						None;
					}
				default:
					if (Reflect.hasField(o, field)) Some(Reflect.field(o, field));
					else None;
			}
	}
	function getField(o, field)
		return
			switch tryField(o, field) {
				case Some(v): v;
				case None: null;
			}
			
	override private function makePath(e:Void -> Dynamic, l):Dynamic {
		if (false) super.makePath(e, l);//to infer l
		
		var p = l.first();
		if( p == null || p.p != "." )
			return e;
		l.pop();
		var field = l.pop();
		if( field == null || !field.s )
			throw field.p;
		var f = field.p;
		haxe.Template.expr_trim.match(f);
		f = haxe.Template.expr_trim.matched(1);
		return makePath(function() { return getField(e(), f); }, l);
	}
	override function resolve(field:String):Dynamic {
		switch tryField(context, field) {
			case Some(v): return v;
			case None:
		}
		for (ctx in stack)
			switch tryField(ctx, field) {
				case Some(v): return v;
				case None:
			}
			
		if (field == "__current__" )
			return context;
			
		return 
			switch tryField(haxe.Template.globals, field) {
				case Some(v): v;
				case None: null;
			}
	}	
}