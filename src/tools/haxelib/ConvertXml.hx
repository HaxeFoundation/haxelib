package tools.haxelib;
import haxe.Json;

class ConvertXml
{
	public static function convert(inXml:String) {
		// Set up the default JSON structure
		var json = {
			"name": "",
			"url" : "",
			"license": "",
			"tags": [],
			"description": "",
			"version": "0.0.1",
			"releasenote": "",
			"contributors": [],
			"dependencies": {}
		};

		// Parse the XML and set the JSON
		var xml = Xml.parse(inXml);
		var project = xml.firstChild();
		json.name = project.get("name");
		json.license = project.get("license");
		json.url = project.get("url");
		for (node in project)
		{
			switch (node.nodeType)
			{
				case Xml.Element:
					switch (node.nodeName)
					{
						case "tag": 
							json.tags.push(node.get("v"));
						case "user":
							json.contributors.push(node.get("name"));
						case "version":
							json.version = node.get("name");
							json.releasenote = node.firstChild().toString();
						case "description":
							json.description = node.firstChild().toString();
						case "depends":
							var name = node.get("name");
							var version = node.get("version");
							if (version == null) version = "";
							Reflect.setField(json.dependencies, name, version);
						default: 
					}
				default: 
			}
		}

		return json;
	}

	public static function prettyPrint(json:Dynamic, indent="") {
		var sb = new StringBuf();
		sb.add("{\n");

		var firstRun = true;
		for (f in Reflect.fields(json))
		{
			if (!firstRun) sb.add(",\n");
			firstRun = false;

			var value = switch (f) {
				case "dependencies":
					var d = Reflect.field(json, f);
					prettyPrint(d, indent + "  ");
				default: 
					Json.stringify(Reflect.field(json, f));
			}
			sb.add(indent+'  "$f": $value');
		}

		sb.add('\n$indent}');
		return sb.toString();
	}
}