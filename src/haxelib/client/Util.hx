package haxelib.client;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.Field;

using haxe.macro.Tools;
#end

using StringTools;
using Lambda;

#if macro

private function getValueArray(fields:Array<Field>):Expr {
	final type = Context.getLocalClass().get();

	// Switch on the type and check if it's an abstract with @:enum metadata
	final valueExprs = [];
	for (field in fields) {
		switch field {
			case {kind: FVar(_), access:access} if (!access.contains(AStatic)):
				final fieldName = field.name;
				valueExprs.push(macro $i{type.name}.$fieldName);
			default:
		}
	}
	return macro $a{valueExprs};
}

private function generateAliasMaps(fields:Array<Field>):{aliasesByName:Array<Expr>, namesByAlias:Array<Expr>} {
	final aliasesByName = [];
	final namesByAlias = [];

	for (field in fields) {
		if (field.meta == null)
			continue;
		final aliasMeta = field.meta.find((meta) -> meta.name == ":alias");
		if (aliasMeta == null)
			continue;
		final aliases = [];
		for (alias in aliasMeta.params) {
			final alias = switch alias.expr {
				case EConst(CString(s)): s;
				default: throw new Error("Invalid alias type", field.pos);
			}
			aliases.push(alias);
			namesByAlias.push(macro $v{alias} => $i{field.name});
		}
		aliasesByName.push(macro $i{field.name} => $v{aliases});
	}
	return { aliasesByName: aliasesByName, namesByAlias: namesByAlias };
}

function addStaticField(fields:Array<Field>,name:String, kind:FieldType, ?doc:String, isPublic = false)
	fields.push({
		name: name,
		access: isPublic ? [AStatic, APublic] : [AStatic],
		doc: doc,
		kind: kind,
		pos: Context.currentPos()
	});

#end

private final ofString = macro {
	for (value in VALUES) {
		if ((value:String) == str)
			return value;
	}
	return null;
};
private final ofStringWithAliases = macro {
	// first check aliases
	final alias = NAMES_BY_ALIAS[str];
	if (alias != null)
		return alias;
	${ofString}
};

macro function buildArgType():Array<Field> {
	final type = Context.getLocalType();

	final abstractType = switch (type.getClass()) {
		case {kind: KAbstractImpl(_.get() => ab)} if (ab.meta.has(":enum")):
			ab;
		case {name: name}:
			throw new Error(name + " should be enum abstract", Context.currentPos());
	}

	final abstractPath = TPath({name: abstractType.name, pack: abstractType.pack});

	final fields = Context.getBuildFields();
	addStaticField(fields, "VALUES", FVar(macro:Array<$abstractPath>, getValueArray(fields)));

	final aliasData = generateAliasMaps(fields);

	final hasAliases = !aliasData.aliasesByName.empty();
	if (hasAliases) {
		addStaticField(fields, "ALIASES_BY_NAME", FVar(macro:Map<$abstractPath, Array<String>>, macro $a{aliasData.aliasesByName}));
		addStaticField(fields, "NAMES_BY_ALIAS", FVar(macro:Map<String, $abstractPath>, macro $a{aliasData.namesByAlias}));
	}

	final argName = abstractType.name.toLowerCase();

	addStaticField(fields, "getAliases", FFun({
		args: [{name: argName, type: macro:$abstractPath}],
		expr: hasAliases ? macro { return ALIASES_BY_NAME[$i{argName}] ?? []; } : macro {return [];},
		ret: macro: Array<String>
	}), 'Returns array of aliases for `$argName`.', true);

	addStaticField(fields, "ofString", FFun({
			args: [{name: "str", type: macro: String}],
			expr: hasAliases ? ofStringWithAliases : ofString,
			ret: macro:$abstractPath
		}),
		'Returns `str` as an instance of `${abstractType.name}`. If it is invalid, returns `null`.', true
	);

	return fields;
}
