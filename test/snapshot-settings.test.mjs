import test from 'node:test';import assert from 'node:assert/strict';
import {browserSnapshot} from '../src/browser-snapshot.mjs';
test('snapshot carries the shared twelve choices and safe subscription metadata only',()=>{
 const now=Date.now();const result=browserSnapshot({fetchedAt:now,buckets:[]},{fetchedAt:now},now,{visible:{short:false,plan:true,secret:'DO_NOT_SHARE'},planBadge:'Pro',renewalDate:'2026-12-13',planSource:'manual',language:'en',purchaseDate:'private',email:'private',auth:'private'});
 assert.equal(result.visible.short,false);assert.equal(Object.keys(result.visible).length,12);assert.equal(result.planBadge,'Pro');assert.equal(result.renewalDate,'2026-12-13');assert.equal(result.planSource,'manual');
 assert.ok(!JSON.stringify(result).includes('private'));assert.ok(!JSON.stringify(result).includes('DO_NOT_SHARE'));
});
test('malformed plan metadata remains unknown, not a paid plan',()=>{
 const value=browserSnapshot({}, {},Date.now(),{planBadge:'Pro secretly',renewalDate:'2026-02-30',planSource:'untrusted'});
 assert.equal(value.planBadge,'?');assert.equal(value.renewalDate,null);assert.equal(value.planSource,'unknown');
});
