import readline from 'node:readline';
const input = readline.createInterface({ input: process.stdin });
let initialized = false;
for await (const line of input) {
  const request = JSON.parse(line);
  if (request.method === 'initialize') {
    process.stdout.write(JSON.stringify({ id: request.id, result: {} }) + '\n');
  } else if (request.method === 'initialized') {
    initialized = true;
  } else if (request.method === 'account/rateLimits/read' && initialized) {
    if (process.argv.includes('timeout')) continue;
    if(process.argv.includes('quota-error')){process.stdout.write(JSON.stringify({id:request.id,error:{message:'private server details'}})+'\n');continue;}
    process.stdout.write('{"method":"notification"}\n');
    const result = { sessionPid:process.pid, rateLimits: { primary: { usedPercent: 27, windowDurationMins: 10080, resetsAt: 2000 } } };
    const response = JSON.stringify({ id: request.id, result }) + '\n';
    process.stdout.write(response.slice(0, 15));
    setTimeout(() => process.stdout.write(response.slice(15)), 5);
  } else if (request.method === 'account/usage/read' && initialized) {
    if(process.argv.includes('usage-timeout'))continue;
    if(process.argv.includes('usage-error')){process.stdout.write(JSON.stringify({id:request.id,error:{message:'private server details'}})+'\n');continue;}
    process.stdout.write(JSON.stringify({id:request.id,result:{sessionPid:process.pid,summary:{lifetimeTokens:1234567},dailyUsageBuckets:[]}})+'\n');
  } else {
    process.stdout.write(JSON.stringify({ id: request.id, error: { message: 'unexpected method' } }) + '\n');
  }
}
