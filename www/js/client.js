(function () { "use strict";
var Client = function() { };
Client.__name__ = true;
Client.main = function() {
	((function($this) {
		var $r;
		var html = window.document;
		$r = new js.JQuery(html);
		return $r;
	}(this))).ready(function(_) {
		Client.menuExpandCollapse();
		Client.expandCurrentPageOnMenu();
		Client.syntaxHighlight();
		Client.pullOutStyling();
		Client.tableStyling();
		Client.emptyLinks();
		Client.externalLinks();
	});
};
Client.syntaxHighlight = function() {
	var kwds = ["abstract","break","case","cast","class","continue","default","do","dynamic","else","enum","extends","extern","for","function","if","implements","import","in","inline","interface","macro","new","override","package","private","public","return","static","switch","throw","try","typedef","untyped","using","var","while"];
	var kwds1 = new EReg("\\b(" + kwds.join("|") + ")\\b","g");
	var vals = ["null","true","false","this"];
	var vals1 = new EReg("\\b(" + vals.join("|") + ")\\b","g");
	var $it0 = (function($this) {
		var $r;
		var _this = new js.JQuery("pre code.prettyprint.haxe");
		$r = (_this.iterator)();
		return $r;
	}(this));
	while( $it0.hasNext() ) {
		var s = $it0.next();
		var html = s.html();
		var tabs = null;
		var _g = 0;
		var _g1 = html.split("\n");
		while(_g < _g1.length) {
			var line = _g1[_g];
			++_g;
			if(StringTools.trim(line) != "") {
				var r = new EReg("^\t*","");
				r.match(line);
				var t = r.matched(0);
				if(tabs == null || t.length < tabs.length) tabs = t;
			}
		}
		html = new EReg("^" + Std.string(tabs),"gm").replace(html,"");
		html = StringTools.trim(html);
		html = new EReg("('[^']*')","g").replace(html,"<span __xlass='str'>$1</span>");
		html = kwds1.replace(html,"<span class='kwd'>$1</span>");
		html = vals1.replace(html,"<span class='val'>$1</span>");
		html = html.split("__xlass").join("class");
		html = new EReg("(\"[^\"]*\")","g").replace(html,"<span class='str'>$1</span>");
		html = new EReg("(//[^\n]*)","g").replace(html,"<span class='cmt'>$1</span>");
		html = new EReg("(/\\*\\*?[^*]*\\*?\\*/)","g").replace(html,"<span class='cmt'>$1</span>");
		html = html.split("\t").join("    ");
		s.html(html);
	}
};
Client.menuExpandCollapse = function() {
	new js.JQuery(".tree-nav li i.fa").click(function() {
		$(this).parent().toggleClass("active");
	});
};
Client.expandCurrentPageOnMenu = function() {
	var current = haxe.io.Path.withoutDirectory(window.document.URL);
	new js.JQuery(".tree-nav a[href=\"" + current + "\"]").addClass("active").parents("li").addClass("active");
};
Client.pullOutStyling = function() {
	var $it0 = (function($this) {
		var $r;
		var _this = new js.JQuery("blockquote h5");
		$r = (_this.iterator)();
		return $r;
	}(this));
	while( $it0.hasNext() ) {
		var h5 = $it0.next();
		var type;
		var _this1 = h5.text();
		var len = h5.text().indexOf(":");
		type = HxOverrides.substr(_this1,0,len);
		h5.parent().addClass(type.toLowerCase());
	}
};
Client.tableStyling = function() {
	new js.JQuery(".site-content table").addClass("table");
};
Client.externalLinks = function() {
	new js.JQuery(".site-content a[href^='http://']").attr("target","_blank");
	new js.JQuery(".site-content a[href^='https://']").attr("target","_blank");
	new js.JQuery("a[href^='/api/']").attr("target","_blank");
};
Client.emptyLinks = function() {
	new js.JQuery("a[href=\"#\"]").click(function() {
		return false;
	}).attr("title","This page has not been created yet");
};
var EReg = function(r,opt) {
	opt = opt.split("u").join("");
	this.r = new RegExp(r,opt);
};
EReg.__name__ = true;
EReg.prototype = {
	match: function(s) {
		if(this.r.global) this.r.lastIndex = 0;
		this.r.m = this.r.exec(s);
		this.r.s = s;
		return this.r.m != null;
	}
	,matched: function(n) {
		if(this.r.m != null && n >= 0 && n < this.r.m.length) return this.r.m[n]; else throw "EReg::matched";
	}
	,replace: function(s,by) {
		return s.replace(this.r,by);
	}
};
var HxOverrides = function() { };
HxOverrides.__name__ = true;
HxOverrides.cca = function(s,index) {
	var x = s.charCodeAt(index);
	if(x != x) return undefined;
	return x;
};
HxOverrides.substr = function(s,pos,len) {
	if(pos != null && pos != 0 && len != null && len < 0) return "";
	if(len == null) len = s.length;
	if(pos < 0) {
		pos = s.length + pos;
		if(pos < 0) pos = 0;
	} else if(len < 0) len = s.length + len - pos;
	return s.substr(pos,len);
};
var Std = function() { };
Std.__name__ = true;
Std.string = function(s) {
	return js.Boot.__string_rec(s,"");
};
var StringTools = function() { };
StringTools.__name__ = true;
StringTools.isSpace = function(s,pos) {
	var c = HxOverrides.cca(s,pos);
	return c > 8 && c < 14 || c == 32;
};
StringTools.ltrim = function(s) {
	var l = s.length;
	var r = 0;
	while(r < l && StringTools.isSpace(s,r)) r++;
	if(r > 0) return HxOverrides.substr(s,r,l - r); else return s;
};
StringTools.rtrim = function(s) {
	var l = s.length;
	var r = 0;
	while(r < l && StringTools.isSpace(s,l - r - 1)) r++;
	if(r > 0) return HxOverrides.substr(s,0,l - r); else return s;
};
StringTools.trim = function(s) {
	return StringTools.ltrim(StringTools.rtrim(s));
};
var haxe = {};
haxe.io = {};
haxe.io.Path = function(path) {
	var c1 = path.lastIndexOf("/");
	var c2 = path.lastIndexOf("\\");
	if(c1 < c2) {
		this.dir = HxOverrides.substr(path,0,c2);
		path = HxOverrides.substr(path,c2 + 1,null);
		this.backslash = true;
	} else if(c2 < c1) {
		this.dir = HxOverrides.substr(path,0,c1);
		path = HxOverrides.substr(path,c1 + 1,null);
	} else this.dir = null;
	var cp = path.lastIndexOf(".");
	if(cp != -1) {
		this.ext = HxOverrides.substr(path,cp + 1,null);
		this.file = HxOverrides.substr(path,0,cp);
	} else {
		this.ext = null;
		this.file = path;
	}
};
haxe.io.Path.__name__ = true;
haxe.io.Path.withoutDirectory = function(path) {
	var s = new haxe.io.Path(path);
	s.dir = null;
	return s.toString();
};
haxe.io.Path.prototype = {
	toString: function() {
		return (this.dir == null?"":this.dir + (this.backslash?"\\":"/")) + this.file + (this.ext == null?"":"." + this.ext);
	}
};
var js = {};
js.Boot = function() { };
js.Boot.__name__ = true;
js.Boot.__string_rec = function(o,s) {
	if(o == null) return "null";
	if(s.length >= 5) return "<...>";
	var t = typeof(o);
	if(t == "function" && (o.__name__ || o.__ename__)) t = "object";
	switch(t) {
	case "object":
		if(o instanceof Array) {
			if(o.__enum__) {
				if(o.length == 2) return o[0];
				var str = o[0] + "(";
				s += "\t";
				var _g1 = 2;
				var _g = o.length;
				while(_g1 < _g) {
					var i = _g1++;
					if(i != 2) str += "," + js.Boot.__string_rec(o[i],s); else str += js.Boot.__string_rec(o[i],s);
				}
				return str + ")";
			}
			var l = o.length;
			var i1;
			var str1 = "[";
			s += "\t";
			var _g2 = 0;
			while(_g2 < l) {
				var i2 = _g2++;
				str1 += (i2 > 0?",":"") + js.Boot.__string_rec(o[i2],s);
			}
			str1 += "]";
			return str1;
		}
		var tostr;
		try {
			tostr = o.toString;
		} catch( e ) {
			return "???";
		}
		if(tostr != null && tostr != Object.toString) {
			var s2 = o.toString();
			if(s2 != "[object Object]") return s2;
		}
		var k = null;
		var str2 = "{\n";
		s += "\t";
		var hasp = o.hasOwnProperty != null;
		for( var k in o ) {
		if(hasp && !o.hasOwnProperty(k)) {
			continue;
		}
		if(k == "prototype" || k == "__class__" || k == "__super__" || k == "__interfaces__" || k == "__properties__") {
			continue;
		}
		if(str2.length != 2) str2 += ", \n";
		str2 += s + k + " : " + js.Boot.__string_rec(o[k],s);
		}
		s = s.substring(1);
		str2 += "\n" + s + "}";
		return str2;
	case "function":
		return "<function>";
	case "string":
		return o;
	default:
		return String(o);
	}
};
String.__name__ = true;
Array.__name__ = true;
var q = window.jQuery;
js.JQuery = q;
q.fn.iterator = function() {
	return { pos : 0, j : this, hasNext : function() {
		return this.pos < this.j.length;
	}, next : function() {
		return $(this.j[this.pos++]);
	}};
};
Client.main();
})();
