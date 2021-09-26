package sys.db;

import Mysql2 as JsMysql;
import js.lib.Promise;
using sys.db.Mysql.PromiseSynchronizer;

@:jsRequire("promise-synchronizer")
private extern class PromiseSynchronizer {
	@:selfCall
	static public function sync<T>(p:Promise<T>):T;
}

class Mysql {
	public static function connect(params:{
		host:String,
		?port:Int,
		user:String,
		pass:String,
		?socket:String,
		?database:String
	}):sys.db.Connection {
		var cnx = JsMysql.createConnection({
			host: params.host,
			port: params.port,
			user: params.user,
			password: params.pass,
			database: params.database,
			socketPath: params.socket,
			rowsAsArray: true,
		}).promise();
		return new MysqlConnection(cnx);
	}
}

private class MysqlConnection implements sys.db.Connection {
	final cnx:mysql2.promise.Connection;
	var _lastInsertId:Null<Int>;
	public function new(cnx:mysql2.promise.Connection):Void {
		this.cnx = cnx;
	}
	public function request(s:String):ResultSet {
		var r:Dynamic = cnx.query(s).sync();
		_lastInsertId = r[0].insertId;
		return new MysqlResultSet(r[0], r[1]);
	}
	public function close():Void {
		cnx.end().sync();
	}
	public function escape(s:String):String {
		return cnx.escape(s);
	}
	public function quote(s:String):String {
		return cnx.escapeId(s);
	}
	public function addValue(s:StringBuf, v:Dynamic):Void {
		s.add(escape(v));
	}
	public function lastInsertId():Int {
		return _lastInsertId;
	}
	public function dbName():String {
		return cnx.config.database;
	}
	public function startTransaction():Void {
		cnx.beginTransaction().sync();
	}
	public function commit():Void {
		cnx.commit().sync();
	}
	public function rollback():Void {
		cnx.rollback().sync();
	}
}

private class MysqlResultSet implements sys.db.ResultSet {
	final nativeResults:Array<Array<Dynamic>>;
	final nativeFields:Array<mysql2.FieldPacket>;
	var current:Int = 0;
	public function new(results, fields):Void {
		this.nativeResults = results;
		this.nativeFields = fields;
	}

	function rowToObj(row:Array<Dynamic>):Dynamic {
		var obj:haxe.DynamicAccess<Dynamic> = {}
		for (i => field in nativeFields) {
			obj[field.name] = row[i];
		}
		return obj;
	}

	/**
		Get amount of rows left in this set.
		Depending on a database management system accessing this field may cause
		all rows to be fetched internally. However, it does not affect `next` calls.
	**/
	public var length(get, null):Int;
	function get_length() {
		return nativeResults.length - current;
	}
	/**
		Amount of columns in a row.
		Depending on a database management system may return `0` if the query
		did not match any rows.
	**/
	public var nfields(get, null):Int;
	function get_nfields() {
		return Std.int(nativeFields.length);
	}

	/**
		Tells whether there is a row to be fetched.
	**/
	public function hasNext():Bool {
		return length > 0;
	}
	/**
		Fetch next row.
	**/
	public function next():Dynamic {
		return rowToObj(nativeResults[current++]);
	}
	/**
		Fetch all the rows not fetched yet.
	**/
	public function results():List<Dynamic> {
		return Lambda.list([
			for (i in current...nativeResults.length)
				rowToObj(nativeResults[i])
		]);
	}
	/**
		Get the value of `n`-th column of the current row.
		Throws an exception if the re
	**/
	public function getResult(n:Int):String {
		return nativeResults[current][n];
	}
	/**
		Get the value of `n`-th column of the current row as an integer value.
	**/
	public function getIntResult(n:Int):Int {
		return nativeResults[current][n];
	}
	/**
		Get the value of `n`-th column of the current row as a float value.
	**/
	public function getFloatResult(n:Int):Float {
		return nativeResults[current][n];
	}
	/**
		Get the list of column names.
		Depending on a database management system may return `null` if there's no
		more rows to fetch.
	**/
	public function getFieldsNames():Null<Array<String>> {
		return nativeFields.map(f -> f.name);
	}
}