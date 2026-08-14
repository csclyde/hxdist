package targets;

import haxe.io.Path;

class JavaScript extends Target {
	public function new(dd:String, pd:String, pn:String) {
		super(dd, pd, pn);
	}

	public override function compile(hxml:String, outputDir:String) {
		if(Sys.command('haxe', [hxml]) != 0)
			Term.error('Compilation failed!');

		var hxmlContent = Target.parseHxml(projDir, hxml);
		var out = getHxmlParam(hxmlContent, '-js');
		if(out == null || out == '')
			Term.error('The JavaScript build did not provide a -js output file.');
		if(!Path.isAbsolute(out)) out = Path.normalize(projDir + '/' + out);

		var packageDir = outputDir + '/js_web/';
		Term.print('Packaging ' + packageDir + '...');
		FileUtil.createDirectory(packageDir);
		sys.io.File.saveContent(packageDir + '/index.html', htmlTemplate);
		FileUtil.copyFile(out, packageDir + '/game.js');

		FileUtil.zipFolder(outputDir + '/${projName}_js_web.zip', packageDir);
	}

	static var htmlTemplate = '<!DOCTYPE html>\n'
		+ '<html lang="en">\n'
		+ '<head>\n'
		+ '    <meta charset="utf-8">\n'
		+ '    <title>Heaps Game</title>\n'
		+ '    <meta name="viewport" content="width=device-width, initial-scale=1.0, minimum-scale=1.0, maximum-scale=1.0, user-scalable=no, minimal-ui" />\n'
		+ '    <meta name="format-detection" content="telephone=no" />\n'
		+ '    <meta name="apple-mobile-web-app-capable" content="yes" />\n'
		+ '    <meta name="mobile-web-app-capable" content="yes" />\n'
		+ '    <style>body,html { margin:0; padding:0; background-color:black; width:100%; height:100%; } canvas#webgl { width:100%; height:100%; }</style>\n'
		+ '</head>\n'
		+ '<body>\n'
		+ '    <canvas id="webgl"></canvas>\n'
		+ '    <script src="game.js"></script>\n'
		+ '</body>\n'
		+ '</html>\n';
}
