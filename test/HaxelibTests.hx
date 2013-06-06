import haxe.unit.TestRunner;
import tests.*;

class HaxelibTests {
	static function main(){
		var r = new TestRunner();

		r.add(new TestSemVer());
		
		r.run();
	}
}