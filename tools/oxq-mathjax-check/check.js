const fs=require('fs');
const {mathjax}=require('mathjax-full/js/mathjax.js');
const {TeX}=require('mathjax-full/js/input/tex.js');
const {liteAdaptor}=require('mathjax-full/js/adaptors/liteAdaptor.js');
const {RegisterHTMLHandler}=require('mathjax-full/js/handlers/html.js');
const {AllPackages}=require('mathjax-full/js/input/tex/AllPackages.js');
const {SVG}=require('mathjax-full/js/output/svg.js');
const adaptor=liteAdaptor(); RegisterHTMLHandler(adaptor);
const tex=new TeX({packages:AllPackages.concat(['mathtools']).filter(p=>!['bussproofs','noundefined','noerrors'].includes(p)), formatError:(j,e)=>{throw e;}});
const doc=mathjax.document('',{InputJax:tex,OutputJax:new SVG({fontCache:'none'})});
const items=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
let bad=0;
for(const it of items){
  try{ doc.convert(it.tex,{display:it.display}); }
  catch(e){ bad++; console.log('ERR line',it.line,':',e.message.split('\n')[0],'\n   ',it.tex.slice(0,100).replace(/\n/g,' ')); }
}
console.log('checked',items.length,'errors',bad);
