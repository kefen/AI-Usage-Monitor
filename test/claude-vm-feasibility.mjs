import assert from 'node:assert/strict';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {join,resolve} from 'node:path';
import {spawnSync} from 'node:child_process';
import {inventory,inspectStatusline} from '../tools/claude-data-probe.mjs';

const prefix=process.env.CLAUDE_SANDBOX_PREFIX;
assert(prefix,'Expected isolated install prefix');
const root=resolve(prefix),evidence=resolve('evidence');
await mkdir(evidence,{recursive:true});
const home=join(root,'test-home'),config=join(home,'.claude');
await mkdir(config,{recursive:true});
const env={...process.env,HOME:home,USERPROFILE:home,CLAUDE_CONFIG_DIR:config,DISABLE_AUTOUPDATER:'1',CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:'1'};
for(const key of Object.keys(env))if(/^(ANTHROPIC_|CLAUDE_CODE_OAUTH_TOKEN|CLAUDE_WEB_COOKIE|OTEL_)/.test(key))delete env[key];
const pkgRoot=join(root,'node_modules','@anthropic-ai','claude-code');
const pkg=JSON.parse(await readFile(join(pkgRoot,'package.json'),'utf8'));
assert.equal(pkg.version,'2.1.330');
const bin=resolve(pkgRoot,typeof pkg.bin==='string'?pkg.bin:pkg.bin.claude);
assert(bin.startsWith(pkgRoot));
function run(args){
  const r=spawnSync(bin,args,{env,cwd:home,encoding:'utf8',timeout:45000,maxBuffer:1048576,windowsHide:true});
  assert(!r.error,'Official CLI launch failed or timed out');return r;
}
const version=run(['--version']);assert.equal(version.status,0);assert.match(version.stdout,/2\.1\.330/);
const help=run(['--help']);assert.equal(help.status,0);assert.match(help.stdout,/auth/);
const auth=run(['auth','status']);
let login;try{login=JSON.parse(auth.stdout)}catch{throw Error('Official CLI auth status did not return JSON; not treating it as verified signed-out state')}
assert.equal(auth.status,1);assert.equal(login.loggedIn,false);assert.equal(login.authMethod,'none');
const now=Date.now();
const synthetic={version:pkg.version,model:{id:'fixture-model'},session_id:'fixture-only',rate_limits:{five_hour:{used_percentage:0,resets_at:Math.floor(now/1000)+1800},seven_day:{used_percentage:80,resets_at:Math.floor(now/1000)+86400}},context_window:{used_percentage:25,current_usage:{input_tokens:20,output_tokens:5,cache_read_input_tokens:10,cache_creation_input_tokens:0}},cost:{total_cost_usd:0.01},credential:'MUST_NOT_ESCAPE',cwd:'MUST_NOT_ESCAPE'};
const pipe=spawnSync(process.execPath,[resolve('tools/claude-data-probe.mjs'),'--stdin'],{env,cwd:home,input:JSON.stringify(synthetic),encoding:'utf8',timeout:10000});
assert.equal(pipe.status,0);assert(!pipe.stdout.includes('MUST_NOT_ESCAPE'));
const parsed=JSON.parse(pipe.stdout);assert.equal(parsed.limits.seven_day.remainingPercentage,20);assert.equal(parsed.notificationEligible,false);
assert.equal(inspectStatusline({},now).limits.seven_day.remainingPercentage,null);
const report={schema:1,platform:process.platform,architecture:process.arch,officialCliVersion:pkg.version,officialCliLaunch:true,officialHelp:true,signedOutAuthStatus:{exitCode:auth.status,loggedIn:login.loggedIn,authMethod:login.authMethod},statuslineJsonPipe:{passed:true,synthetic:true,liveClaudeCallback:false},metadataInventory:await inventory({home,env}),liveSubscriptionQuotaVerified:false,liveAccountSwitchVerified:false,liveNotificationVerified:false,credentialsSupplied:false,settingsInstalled:false,source:'Official pinned npm package; signed-out CLI and synthetic stdin contract only',checkedAt:new Date().toISOString()};
await writeFile(join(evidence,'claude-vm-result.json'),JSON.stringify(report,null,2));
await writeFile(join(evidence,'synthetic-statusline-projection.json'),JSON.stringify(parsed,null,2));
console.log(JSON.stringify(report,null,2));
