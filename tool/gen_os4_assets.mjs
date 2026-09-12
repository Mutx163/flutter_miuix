// OS4 upstream tokens and AGSL -> Flutter GLSL. No external dependencies.
// SPDX-License-Identifier: Apache-2.0
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = path.resolve(process.argv.find(x => x.startsWith('--source='))?.slice(9) || path.join(root, 'demo/miuix'));
const dir = path.join(source, 'miuix-glass/src/commonMain/kotlin/top/yukonga/miuix/kmp/glass');
const outDir = 'lib/src/theme/miuix/glass/';
const header = name => '// Miuix Flutter 移植版 - '+name+'（自动生成）\n// 源自 compose-miuix-ui/miuix 的 miuix-glass，基准 3f7debbf。\n// 由 tool/gen_os4_assets.mjs 生成，请勿手改。\n// SPDX-License-Identifier: Apache-2.0\n\n';
const read = f => fs.readFileSync(path.join(dir, f), 'utf8');
const write = (f,s) => { f=path.join(root,f); fs.mkdirSync(path.dirname(f),{recursive:true}); fs.writeFileSync(f,s); };
const lower = s => s[0].toLowerCase()+s.slice(1);
const models = [...read('GlassStyle.kt').matchAll(/data class (\w+)\(([\s\S]*?)\n\)/g)];
let modelText = header('GlassStyle')+"import 'package:flutter/painting.dart';\nimport 'package:flutter/foundation.dart';\n\n";
for (const [,name,body] of models) {
  const fields = [...body.matchAll(/val (\w+): (\w+)/g)].map(([,n,t])=>[n,t==='Float'?'double':t.startsWith('Glass')?'Miuix'+t:t]);
  modelText += '/// 对应 Kotlin \u0060'+name+'\u0060。\n@immutable\nclass Miuix'+name+' {\n  const Miuix'+name+'({'+fields.map(([n])=>'required this.'+n).join(', ')+ '});\n';
  modelText += fields.map(([n,t])=>'  final '+t+' '+n+';\n').join('');
  modelText += '  Miuix'+name+' copyWith({'+fields.map(([n,t])=>t+'? '+n).join(', ')+'}) => Miuix'+name+'('+fields.map(([n])=>n+': '+n+' ?? this.'+n).join(', ')+');\n}\n\n';
}
write(outDir+'miuix_glass_style.dart',modelText);
// Count parentheses without decrementing on ordinary characters.
function balanced(text,start) { let depth=0; for(let i=start;i<text.length;i++){if(text[i]==='(')depth++;else if(text[i]===')'&&--depth===0)return text.slice(start,i+1);}throw Error('Unbalanced expression'); }
const styles = read('GlassStyles.kt');
let styleText=header('GlassStyles')+"import 'package:flutter/painting.dart';\nimport 'miuix_glass_style.dart';\n\n/// 对应 Kotlin GlassStyles：全部 35 组源端材质参数。\nclass MiuixGlassStyles {\n  MiuixGlassStyles._();\n";
const names=[];
for(const m of styles.matchAll(/val (\w+): GlassStyle = GlassStyle\(/g)) {
  const name=lower(m[1]); names.push(name);
  let expr='GlassStyle'+balanced(styles,m.index+m[0].length-1);
  expr=expr.replace(/Color\(([^()]*)\)/g,(_,args)=>{const p=args.split(',').map(x=>x.trim().replace(/f$/,''));return p.length===1?'Color('+p[0]+')':'Color.from(alpha: '+(p[3]||'1')+', red: '+p[0]+', green: '+p[1]+', blue: '+p[2]+')';});
  expr=expr.replace(/\bGlass\w+/g,n=>'Miuix'+n).replace(/\b(\w+) = /g,'$1: ').replace(/(\d)f\b/g,'$1');
  styleText+='  static const '+name+' = '+expr+';\n';
}
if(names.length!==35)throw Error('Expected 35 styles, got '+names.length);
styleText+='  static const values = <String, MiuixGlassStyle>{'+names.map(n=>"'"+n+"': "+n).join(', ')+'};\n  static MiuixGlassStyle forTheme(bool isDark) => isDark ? commonMediumRegularDark : commonMediumRegularLowLight;\n}\n';
write(outDir+'miuix_glass_styles.dart',styleText);
const shader=read('internal/GlassShader.kt');
const blocks=Object.fromEntries([...shader.matchAll(/(?:private|internal) val (\w+): String = """([\s\S]*?)"""/g)].map(m=>[m[1],m[2]]));
const geometry=Object.fromEntries([...read('internal/GlassGeometry.kt').matchAll(/const val (\w+) = ([\-\d.]+)f/g)].map(m=>[m[1],m[2]]));
function expand(s){return s.replace(/\$(\w+)/g,(_,n)=>geometry[n]??(blocks[n]?expand(blocks[n]):(()=>{throw Error('Unknown shader constant '+n)})()));}
let uniforms=header('Glass shader uniform layouts')+'const miuixGlassUniforms = <String, Map<String, int>>{\n';
for(const [key,file] of [['GLASS_SHADER','glass'],['GLASS_MASK_SHADER','mask'],['GLASS_STROKE_SHADER','stroke'],['GLASS_SHADOW_SHADER','shadow'],['GLASS_RIM_SHADER','rim'],['GLASS_COLOR_BLEND_SHADER','blend']]) {
  let text=expand(blocks[key]); const sampler=/uniform shader child;/.test(text);
  text=text.replace(/uniform shader child;/,'uniform sampler2D child;').replace(/\b(?:float|half)([234])\b/g,'vec$1').replace(/\bhalf\b/g,'float').replace(/vec4 main\(vec2 coord\)/,'vec4 shaderMain(vec2 coord)').replace(/child\.eval\(/g,'sampleChild(');
  if(sampler)text='uniform vec2 u_textureSize;\n'+text.replace('uniform sampler2D child;','uniform sampler2D child;\nvec4 sampleChild(vec2 p) { return texture(child, p / u_textureSize); }');
  text='#version 460 core\n#include <flutter/runtime_effect.glsl>\n// Generated from '+key+'; upstream 3f7debbf.\n// SPDX-License-Identifier: Apache-2.0\n'+text+'\nout vec4 fragColor;\nvoid main() { fragColor = shaderMain(FlutterFragCoord().xy); }\n';
  let index=0; const layout=[];
  for(const [,t,n] of text.matchAll(/uniform (float|vec[234]) (\w+);/g)){layout.push("'"+n+"': "+index);index+=t==='float'?1:Number(t[3]);}
  uniforms+="  '"+file+"': {"+layout.join(', ')+'},\n';
  write('shaders/miuix_os4_'+file+'.frag',text);
}
write(outDir+'internal/miuix_glass_uniforms.dart',uniforms+'};\n');
console.log('Generated 35 styles, '+models.length+' models and 6 OS4 shaders.');
