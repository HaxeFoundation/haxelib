package tests.util;

import haxe.ds.GenericStack;

import sys.io.File;
import sys.FileSystem;

/** Object that can generate a directory structure and check if it has changed. **/
class DirectoryState {
	final root:String;
	final dirs:Array<String>;
	final fileContentByPath:Map<String, String>;

	public function new(root:String, dirs:Array<String>, fileContentByPath:Map<String, String>) {
		this.root = root;
		this.dirs = [for (dir in dirs) '$root/$dir'];
		this.fileContentByPath = [for (path => content in fileContentByPath) '$root/$path' => content];
	}

	/** Empties the root directory and creates all the directories and files **/
	public function build():Void {
		HaxelibTests.deleteDirectory(root);
		FileSystem.createDirectory(root);
		generate();
	}

	/** Creates all directories and files without emptying first. **/
	public function add():Void {
		generate();
	}

	function generate():Void {
		for (dir in dirs)
			FileSystem.createDirectory(dir);
		for (path => content in fileContentByPath)
			File.saveContent(path, content);
	}

	/** Confirms that the object matches the root directory. If it does not, an exception is thrown. **/
	public function confirmMatch():Void {
		final dirsLeft = dirs.copy();
		final filesLeft = fileContentByPath.copy();

		final toCheck = new GenericStack<String>();
		toCheck.add(root);

		while (!toCheck.isEmpty()) {
			final cur = toCheck.pop();
			if (!FileSystem.isDirectory(cur)) {
				final expected = filesLeft[cur];
				if (expected == null)
					throw 'File $cur is not expected to exist';
				final content = File.getContent(cur);
				if (expected != content)
					throw 'File $cur was expect to contain `$expected`, but instead contains `$content`';
				// otherwise it is good!
				filesLeft.remove(cur);
				continue;
			}

			final subItems = FileSystem.readDirectory(cur);
			if (subItems.length != 0) {
				var hasChildDir = false;
				for (item in subItems) {
					final fullPath = '$cur/$item';
					if (FileSystem.isDirectory(fullPath))
						hasChildDir = true;
					toCheck.add('$cur/$item');
				}
				if (hasChildDir)
					continue;
			}
			// otherwise the directory is empty
			final wasExpected = dirsLeft.remove(cur);
			if (!wasExpected)
				throw 'Dir $cur is not expected to exist';
		}
		// if all the directories and files we expected are gone, then it was all correct
		if (dirsLeft.length > 0)
			throw 'Expected directories were not found: $dirsLeft';

		final filesIterator = filesLeft.keys();
		if (filesIterator.hasNext()) {
			final files = [for (file in filesIterator) file];
			throw 'Expected files were not found: $files';
		}
	}
}
