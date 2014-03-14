import haxe.unit.TestRunner;
import tests.*;

class HaxelibTests {
	static function main():Void {
		var r = new TestRunner();

		r.add(new TestSemVer());
		r.add(new TestData());
		
		var success = r.run();
		Sys.exit(success ? 0 : 1);
	}
}