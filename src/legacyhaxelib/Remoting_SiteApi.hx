package legacyhaxelib;

class Remoting_SiteApi {
	public function new(c:haxe.remoting.Connection) {
			this.__cnx = c;
	}
	var __cnx : haxe.remoting.Connection;
	public function search(word:String):List<{ public var name(default, default) : String; public var id(default, default) : StdTypes.Int; }> return __cnx.resolve("search").call([word]);
	public function infos(project:String):legacyhaxelib.Data.ProjectInfos return __cnx.resolve("infos").call([project]);
	public function user(name:String):legacyhaxelib.Data.UserInfos return __cnx.resolve("user").call([name]);
	public function register(name:String, pass:String, mail:String, fullname:String):StdTypes.Bool return __cnx.resolve("register").call([name, pass, mail, fullname]);
	public function isNewUser(name:String):StdTypes.Bool return __cnx.resolve("isNewUser").call([name]);
	public function checkDeveloper(prj:String, user:String):StdTypes.Void __cnx.resolve("checkDeveloper").call([prj, user]);
	public function checkPassword(user:String, pass:String):StdTypes.Bool return __cnx.resolve("checkPassword").call([user, pass]);
	public function getSubmitId():String return __cnx.resolve("getSubmitId").call([]);
	public function processSubmit(id:String, user:String, pass:String):String return __cnx.resolve("processSubmit").call([id, user, pass]);
	public function postInstall(project:String, version:String):StdTypes.Void __cnx.resolve("postInstall").call([project, version]);
}