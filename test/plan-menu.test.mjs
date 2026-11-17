import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {usagePlanFromLabel,readUsagePlan,usagePlanExpression} from '../src/plan.mjs';

const token='11111111-1111-4111-8111-111111111111';
function menuFixture({expanded=false,otherDialog=false,labels=['额度来源：你的 Pro 套餐'],main=true}={}) {
 let clicks=0,focused=0;
 const button={isConnected:true,focus:()=>focused++,getAttribute:key=>({'aria-label':'用量','aria-expanded':String(expanded),'aria-controls':expanded?'usage-menu':null}[key]??null),closest:()=>null,dispatchEvent:()=>{clicks++;expanded=!expanded;}};
 const original={isConnected:true,focus:()=>focused++};
 const menu={id:'usage-menu',getAttribute:key=>key==='role'?'menu':null,getClientRects:()=>expanded?[{}]:[],contains:node=>node===button,querySelectorAll:()=>labels.map(textContent=>({textContent,childElementCount:0,closest:()=>null}))};
 const hidden={getAttribute:()=> 'dialog',getClientRects:()=>otherDialog?[{}]:[]};
 const context={location:{protocol:'app:'},window:{},PointerEvent:class{},document:{activeElement:button,querySelector:()=>main?{}:null,querySelectorAll:selector=>selector.startsWith('aside.')?[{querySelectorAll:()=>[button]}]:[hidden,menu]}};
 return {run:action=>vm.runInNewContext(usagePlanExpression(action,token),context),context,state:()=>({expanded,clicks,focused}),original};
}

test('only an exact official quota-source sentence identifies the family',()=>{
 for(const [label,expected]of [['额度来源：你的 Pro 套餐','pro'],['額度來源：你的 Plus 方案','plus'],['Quota source: Your ChatGPT Pro plan','pro'],['Rate limit source: your Free plan','free']])assert.equal(usagePlanFromLabel(label),expected);
 for(const label of ['Pro','Pro 100','My account Pro','hello 额度来源：你的 Pro 套餐','额度来源：你的 Pro 套餐 extra','额度来源：你的 Pro 100 套餐',null])assert.equal(usagePlanFromLabel(label),null);
});
test('usage fallback closes its own probe after a known result or failed read',async()=>{
 const target={};for(const failure of [false,true]){
  const phases=[];
  const api={sleep:async()=>{},evaluate:async(_target,_port,expression)=>{
   const phase=expression.includes('"open"')?'open':expression.includes('"close"')?'close':'read';phases.push(phase);
   if(phase==='open')return {trusted:true,opened:true};
   if(phase==='close')return {trusted:true};
   if(failure)throw Error('Renderer closed');return {trusted:true,plan:'pro'};
  }};
  assert.equal(await readUsagePlan(target,9222,api),failure?null:'pro');
  assert.equal(phases[0],'open');assert.equal(phases.at(-1),'close');
 }
});
test('unavailable or conflicting usage controls never become a paid plan',async()=>{
 for(const result of [{trusted:true,opened:false},{mounted:false},{trusted:true,opened:true}]){
  const api={sleep:async()=>{},evaluate:async()=>result};assert.equal(await readUsagePlan({},9222,api),null);
 }
});

test('real expression opens only the usage menu, reads a strict label and restores ownership',()=>{
 const f=menuFixture();assert.equal(f.run('open').opened,true);assert.equal(f.run('read').plan,'pro');f.run('close');
 assert.deepEqual(f.state(),{expanded:false,clicks:2,focused:1});assert.equal(f.context.window.__cqsUsagePlanProbe,undefined);
});
test('pre-existing menus and other visible dialogs are never closed or replaced',()=>{
 const own=menuFixture({expanded:true});own.run('open');assert.equal(own.run('read').plan,'pro');own.run('close');assert.equal(own.state().clicks,0);assert.equal(own.state().expanded,true);
 const other=menuFixture({otherDialog:true});assert.equal(other.run('open').opened,false);other.run('close');assert.equal(other.state().clicks,0);
 const rejected=menuFixture({main:false});assert.equal(rejected.run('open').mounted,false);assert.equal(rejected.state().clicks,0);
});
test('ambiguous labels, free-form plan names and a different probe token fail closed',()=>{
 for(const labels of [['Pro'],['额度来源：你的 Pro 套餐','额度来源：你的 Plus 套餐']]){const f=menuFixture({labels});f.run('open');assert.equal(f.run('read').plan,undefined);f.run('close');}
 const f=menuFixture();f.run('open');vm.runInNewContext(usagePlanExpression('close','22222222-2222-4222-8222-222222222222'),f.context);assert.equal(f.state().expanded,true);f.run('close');
});
