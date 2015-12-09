package website.controller;

import haxe.crypto.Md5;
import ufront.web.Controller;
import ufront.web.result.*;
import website.api.UserApi;
using tink.CoreApi;

@cacheRequest
class UserController extends Controller {

	@inject public var api:UserApi;

	@:route("/$username")
	public function profile( username:String ) {
		var data = api.getUserProfile( username ).sure();
		var user = data.a;
		return new ViewResult({
			title: '$username (${user.fullname}) on Haxelib',
			user: user,
			projects: data.b,
			emailHash: Md5.encode( user.email ),
		});
	}

	@:route("/")
	public function list() {
		var userList = api.getUserList().sure();
		return new ViewResult({
			title: 'Haxelib Contributors',
			list: userList
		});
	}
	// Future: edit your own profile.  Especially password resets.
}
