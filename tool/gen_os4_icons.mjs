// OS4 ImageVector -> Dart. Preserves closed subpaths and five weights.
// SPDX-License-Identifier: Apache-2.0
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const source=path.resolve(process.argv.find(x=>x.startsWith('--source='))?.slice(9)||path.join(root,'demo/miuix'));
const dir=path.join(source,'miuix-icons/src/commonMain/kotlin/top/yukonga/miuix/kmp/icon/os4');
const weights=['Light','Normal','Regular','Medium','Demibold'];
const icons=[];
for(const file of fs.readdirSync(dir).filter(f=>f.endsWith('.kt')).sort()) {
  const text=fs.readFileSync(path.join(dir,file),'utf8');
  const name=file.slice(0,-3), variants=[];
  for(const weight of weights) {
    const begin=text.indexOf('val MiuixIcons.Os4.'+weight+'.'+name+':');
    const next=text.indexOf('\nval MiuixIcons.',begin+1);
    if(begin<0)throw Error(file+': missing '+weight);
    const body=text.slice(begin,next<0?text.length:next);
    const viewport=Number(body.match(/viewportWidth = ([\d.]+)f/)[1]);
    const height=Number(body.match(/viewportHeight = ([\d.]+)f/)[1]);
    if(viewport!==height || (body.match(/addPath\(/g)||[]).length!==1 || !body.includes('PathFillType.NonZero') || !/fillAlpha = 1f/.test(body))throw Error(file+': unsupported vector layout');
    const group=body.match(/group\(scaleY = -1.0f, translationX = (-?[\d.]+)f, translationY = ([\d.]+)f\)/);
    if(!group || Number(group[2])!==viewport)throw Error(file+': unknown transform');
    const block=body.match(/pathData = listOf\(([\s\S]*?)\),\s*fill =/)[1];
    let x=0,y=0,sx=0,sy=0; const commands=[];
    for(const m of block.matchAll(/PathNode\.(\w+)(?:\(([^)]*)\))?/g)) {
      const args=(m[2]?.match(/-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/g)||[]).map(Number);
      const p=args.join(' ');
      switch(m[1]) {
        case 'MoveTo': [x,y]=args;[sx,sy]=args;commands.push('M '+p);break;
        case 'LineTo': [x,y]=args;commands.push('L '+p);break;
        case 'HorizontalTo': x=args[0];commands.push('L '+x+' '+y);break;
        case 'VerticalTo': y=args[0];commands.push('L '+x+' '+y);break;
        case 'QuadTo': [x,y]=args.slice(2);commands.push('Q '+p);break;
        case 'CurveTo': [x,y]=args.slice(4);commands.push('C '+p);break;
        case 'Close': [x,y]=[sx,sy];commands.push('Z');break;
        default: throw Error(file+': unsupported node '+m[1]);
      }
    }
    if(!commands.length || !commands.includes('Z'))throw Error(file+': empty or open glyph');
    variants.push({viewport, offsetX:Number(group[1]), mirror:body.includes('autoMirror = true'), data:commands.join(' ')});
  }
  icons.push({name:name[0].toLowerCase()+name.slice(1),variants});
}
if(icons.length!==176)throw Error('Expected 176 icons, got '+icons.length);
let out="// Miuix Flutter 移植版 - OS4 Icons（自动生成）\n// 源自 compose-miuix-ui/miuix 的 icon/os4/*.kt，基准 3f7debbf。\n// 由 tool/gen_os4_icons.mjs 生成，保留 176 个图标 × 5 字重及全部闭合路径。\n// SPDX-License-Identifier: Apache-2.0\n\nimport 'package:flutter/widgets.dart';\nimport '../foundation/miuix_vector_icon.dart';\nimport 'miuix_extended_icons.dart';\n\n/// 对应 Kotlin MiuixIcons.Os4，与原 extended 图标独立。\nclass MiuixOs4Icons {\n  const MiuixOs4Icons.internal();\n  List<String> get names => List.unmodifiable(_data.keys);\n  MiuixVectorIcon? byName(String name, [MiuixIconWeight weight = MiuixIconWeight.regular]) {\n    final variants = _data[name];\n    if (variants == null) return null;\n    final v = variants[weight.index];\n    return _cache.putIfAbsent('$name#${weight.index}', () => MiuixVectorIcon(\n      name: 'os4.$name.${weight.name}', viewport: Size.square(v.viewport),\n      intrinsicSize: const Size(24, 24), autoMirror: v.mirror, paths: [MiuixVectorPath(\n        groupTransform: Matrix4.identity()..translateByDouble(v.offsetX, v.viewport, 0, 1)..scaleByDouble(1, -1, 1, 1),\n        build: () => miuixParsePath(v.data),\n      )],\n    ));\n  }\n";
out+=icons.map(i=>'  MiuixVectorIcon get '+i.name+" => byName('"+i.name+"')!;\n").join('')+'}\n';
out+='class _Glyph { const _Glyph(this.viewport, this.offsetX, this.mirror, this.data); final double viewport; final double offsetX; final bool mirror; final String data; }\nfinal _cache = <String, MiuixVectorIcon>{};\nconst _data = <String, List<_Glyph>>{\n';
for(const icon of icons)out+="  '"+icon.name+"': [\n"+icon.variants.map(v=>'    _Glyph('+v.viewport+', '+v.offsetX+', '+v.mirror+", '"+v.data+"'),\n").join('')+'  ],\n';
out+='};\n';
fs.writeFileSync(path.join(root,'lib/src/theme/miuix/icon/miuix_os4_icons.dart'),out);
console.log('Generated '+icons.length+' OS4 icons / '+icons.length*5+' variants.');
