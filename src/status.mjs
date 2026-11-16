import { mkdir, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import {version} from './version.mjs';
export async function recordStatus(path, stage, details = {}) {
  const status = { version, stage, updatedAt:new Date().toISOString() };
  for (const key of ['port','targetCount','mountedCount','nextUsageAt','usageReadAt']) {
    if (Number.isInteger(details[key]) && details[key] >= 0) status[key] = details[key];
  }
  if (typeof details.quotaAvailable === 'boolean') status.quotaAvailable = details.quotaAvailable;
  if (typeof details.usageAvailable === 'boolean') status.usageAvailable = details.usageAvailable;
  if(['full','scroll','compact','hidden'].includes(details.sidebarMode))status.sidebarMode=details.sidebarMode;
  if(['available','scroll-space','limited-space','disabled','official-controls-priority','sidebar-unrecognized'].includes(details.sidebarReason))status.sidebarReason=details.sidebarReason;
  await mkdir(dirname(path), {recursive:true});
  await writeFile(path, JSON.stringify(status,null,2), 'utf8');
}
