import haxe.io.Bytes;
import haxe.io.BytesOutput;
import sys.FileSystem;
import sys.io.File;
import targets.hashlink.NativeDependencies;
import targets.hashlink.HashLinkBytecode;
import targets.hashlink.WindowsExecutable;
import targets.hashlink.HashLink;

@:access(targets.hashlink.NativeDependencies)
@:access(targets.hashlink.WindowsExecutable)
@:access(targets.hashlink.HashLink)
class PackagingRegressionTest {
	static function check(value:Bool, message:String):Void {
		if(!value) throw message;
	}
	static function rejects(action:Void->Void, message:String):Void {
		var rejected = false;
		try action() catch(e:Dynamic) rejected = true;
		check(rejected, message);
	}
	static function put32(bytes:Bytes, at:Int, value:Int):Void {
		for(i in 0...4) bytes.set(at + i, (value >>> (i * 8)) & 255);
	}
	static function main():Void {
		var project = FileSystem.fullPath('.');
		rejects(() -> { FileUtil.validateOutputDirectory('.', project); }, 'Reject project deletion');
		rejects(() -> { FileUtil.validateOutputDirectory('..', project); }, 'Reject ancestor deletion');
		rejects(() -> { FileUtil.validateOutputDirectory('', project); }, 'Reject empty output');
		rejects(() -> { FileUtil.validateOutputDirectory(haxe.io.Path.isAbsolute(project) && project.charAt(1) == ':' ? project.substr(0, 3) : '/', project); }, 'Reject filesystem root');
		rejects(() -> { FileUtil.validateOutputDirectory('README.md', project); }, 'Reject file output');
		check(FileUtil.validateOutputDirectory('bin/regression-output', project).indexOf('regression-output') >= 0, 'Allow package directory');
		rejects(() -> FileUtil.validateProjectName('../escape'), 'Reject project path traversal');
		rejects(() -> FileUtil.validateProjectName("bad$name"), 'Reject shell substitution');
		FileUtil.validateProjectName('My Game');

		FileSystem.createDirectory('bin/regression-fixtures/nested');
		File.saveContent('bin/regression-fixtures/nested/data.txt', 'archive content');
		File.saveContent('bin/regression-fixtures/empty.txt', '');
		FileUtil.zipFolder('bin/regression.zip', 'bin/regression-fixtures/');
		var entries = haxe.zip.Reader.readZip(new haxe.io.BytesInput(File.getBytes('bin/regression.zip')));
		var found = false;
		for(entry in entries) {
			check(entry.fileName != '' && !StringTools.startsWith(entry.fileName, '/'), 'Valid relative ZIP names');
			if(entry.fileName == 'nested/data.txt') {
				found = true;
				check(haxe.zip.Reader.unzip(entry).toString() == 'archive content', 'ZIP payload roundtrip');
			}
		}
		check(found, 'ZIP preserves nested filename with trailing slash input');

		rejects(() -> { NativeDependencies.strings('native'); }, 'Reject mistyped config');
		rejects(() -> { NativeDependencies.strings(['ok', 42]); }, 'Reject mixed config');
		rejects(() -> { NativeDependencies.strings(['']); }, 'Reject empty config entry');
		rejects(() -> { NativeDependencies.inspectPE(Bytes.alloc(12)); }, 'Reject truncated PE');
		rejects(() -> { NativeDependencies.cstring(Bytes.ofString('no terminator'), 0); }, 'Reject unterminated imports');
		var pe = Bytes.alloc(512);
		put32(pe, 12, 0x1000); // section virtual address
		put32(pe, 8, 0x100); // virtual size
		put32(pe, 16, 16); // raw size
		put32(pe, 20, 128); // raw offset
		check(NativeDependencies.peRvaOffset(pe, 0x1004, 0, 1) == 132, 'Resolve file-backed RVA');
		check(NativeDependencies.peRvaOffset(pe, 0x1020, 0, 1) == -1, 'Reject zero-filled virtual RVA');
		put32(pe, 20, 510);
		check(NativeDependencies.peRvaOffset(pe, 0x1004, 0, 1) == -1, 'Reject RVA beyond file');

		var elf = Bytes.alloc(256);
		elf.set(4, 1); elf.set(5, 1);
		put32(elf, 28, 52); elf.set(42, 32); elf.set(44, 2);
		put32(elf, 52, 1); put32(elf, 56, 0); put32(elf, 60, 0x1000); put32(elf, 68, 256);
		put32(elf, 84, 2); put32(elf, 88, 128); put32(elf, 100, 24);
		put32(elf, 128, 1); put32(elf, 132, 0);
		put32(elf, 136, 5); put32(elf, 140, 0x10C0);
		elf.blit(192, Bytes.ofString('libdemo.so\x00'), 0, 11);
		check(NativeDependencies.inspectELF(elf).join(',') == 'libdemo.so', 'Resolve ELF dependencies');
		elf.set(42, 0);
		rejects(() -> { NativeDependencies.inspectELF(elf); }, 'Reject undersized ELF headers');

		var hl = new BytesOutput();
		hl.writeString('HLB'); hl.writeByte(4);
		for(value in [0, 0, 0, 3, 0, 0, 2, 0, 0, 0]) hl.writeByte(value);
		var strings = ['?sample', 'sample', 'function'];
		var table = strings.join('\x00') + '\x00';
		hl.writeInt32(table.length); hl.writeString(table);
		for(value in strings) hl.writeByte(value.length);
		for(value in [0, 2, 0, 0, 1, 2, 0, 1]) hl.writeByte(value);
		File.saveBytes('bin/native-imports.hl', hl.getBytes());
		var natives = HashLinkBytecode.natives('bin/native-imports.hl');
		check(natives.length == 1 && natives[0].name == 'sample' && !natives[0].optional, 'Required import overrides earlier optional import');
		check(WindowsExecutable.calculateChecksum(Bytes.alloc(65536), 64) == 65536, 'PE checksum preserves file length');
		FileSystem.createDirectory('bin/launcher fixture');
		File.saveContent('bin/launcher fixture/run.sh', HashLink.linuxRunScript('My Game'));
		File.saveContent('bin/launcher fixture/My Game.x64', "#!/bin/sh\nprintf '%s\\n' \"$LD_LIBRARY_PATH\" \"$@\"\nexit 7\n");
		Sys.println('Packaging regression tests passed.');
	}
}
