#!/usr/bin/env node

/**
 * deploy.js
 * Automated deployment, validation, and rollback script for Vite + React projects on Vercel.
 */

import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import readline from 'readline';

const REQUIRED_ENVS = [
  'VITE_CLERK_PUBLISHABLE_KEY',
  'VITE_SUPABASE_URL',
  'VITE_SUPABASE_ANON_KEY'
];

// Formatting helper
const colors = {
  reset: '\x1b[0m',
  cyan: '\x1b[36m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  gray: '\x1b[90m',
  bold: '\x1b[1m'
};

function printHeader(text) {
  console.log(`\n${colors.cyan}${colors.bold}=== ${text} ===${colors.reset}`);
}

function printSuccess(text) {
  console.log(`${colors.green}✔ ${text}${colors.reset}`);
}

function printWarning(text) {
  console.log(`${colors.yellow}⚠ ${text}${colors.reset}`);
}

function printError(text) {
  console.log(`${colors.red}✘ ${text}${colors.reset}`);
}

function printInfo(text) {
  console.log(`${colors.gray}${text}${colors.reset}`);
}

// Ask user question helper
function askQuestion(query) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  return new Promise((resolve) => rl.question(`${colors.bold}${query}${colors.reset} `, (ans) => {
    rl.close();
    resolve(ans.trim());
  }));
}

// Helper to run shell command and return status
function runCommand(command, errorMessage, inheritIO = true) {
  try {
    execSync(command, { stdio: inheritIO ? 'inherit' : 'pipe' });
    return true;
  } catch (error) {
    if (errorMessage) {
      printError(`${errorMessage}`);
    }
    return false;
  }
}

// Rollback Logic
async function handleRollback() {
  printHeader('Vercel Rollback Sequence');
  
  // Verify Vercel CLI is installed
  try {
    execSync('npx vercel --version', { stdio: 'ignore' });
  } catch (e) {
    printError('Vercel CLI (vercel) is not available. Please install Node.js/npm.');
    process.exit(1);
  }

  printInfo('Fetching recent production deployments...');
  runCommand('npx vercel list --prod', 'Failed to retrieve production deployments.');

  console.log(`\n${colors.cyan}To roll back, please choose one of the following methods:${colors.reset}`);
  console.log(`1. Run interactive rollback:   ${colors.green}npx vercel rollback${colors.reset}`);
  console.log(`2. Rollback to a specific ID:  ${colors.green}npx vercel rollback <deployment-id-or-url>${colors.reset}`);

  const ans = await askQuestion('\nWould you like to run interactive rollback now? (y/n):');
  if (ans.toLowerCase() === 'y' || ans.toLowerCase() === 'yes') {
    runCommand('npx vercel rollback', 'Rollback failed.');
  } else {
    printInfo('Rollback aborted.');
  }
  process.exit(0);
}

// Main execution flow
async function main() {
  const args = process.argv.slice(2);
  if (args.includes('--rollback') || args.includes('-r')) {
    await handleRollback();
    return;
  }

  console.log(`${colors.cyan}${colors.bold}=========================================${colors.reset}`);
  console.log(`${colors.cyan}${colors.bold}     Vercel Deployment Automation        ${colors.reset}`);
  console.log(`${colors.cyan}${colors.bold}=========================================${colors.reset}`);

  // 1. Prerequisites Check
  printHeader('1/5 Checking environment requirements');
  try {
    execSync('node --version', { stdio: 'ignore' });
    printSuccess('Node.js is available.');
  } catch (e) {
    printError('Node.js is not found. Please install Node.js.');
    process.exit(1);
  }

  // Check if vercel config file exists or vercel is available
  try {
    execSync('npx vercel --version', { stdio: 'ignore' });
    printSuccess('Vercel runner is available.');
  } catch (e) {
    printWarning('Vercel CLI package is not installed. We will use npx to run it on-demand.');
  }

  // 2. Git Status Check
  printHeader('2/5 Checking git status');
  let cleanTree = false;
  try {
    const gitStatus = execSync('git status --porcelain', { encoding: 'utf8' });
    if (gitStatus.trim().length > 0) {
      printWarning('You have uncommitted changes in your working tree:');
      console.log(gitStatus);
      const answer = await askQuestion('Do you want to proceed with deployment anyway? (y/n):');
      if (answer.toLowerCase() !== 'y' && answer.toLowerCase() !== 'yes') {
        printError('Deployment cancelled to commit changes.');
        process.exit(1);
      }
    } else {
      printSuccess('Git working tree is clean. Ready to deploy.');
      cleanTree = true;
    }
  } catch (e) {
    printWarning('Git is not initialized or not found. Skipping git status check.');
  }

  // 3. Env Variables Mapping
  printHeader('3/5 Mapping environment variables');
  const localEnvs = {};
  
  // Try loading env files
  const envFiles = ['.env.local', '.env'];
  let loadedFile = null;
  for (const file of envFiles) {
    if (fs.existsSync(file)) {
      loadedFile = file;
      const content = fs.readFileSync(file, 'utf8');
      content.split('\n').forEach(line => {
        const trimmed = line.trim();
        if (trimmed && !trimmed.startsWith('#')) {
          const eqIdx = trimmed.indexOf('=');
          if (eqIdx > 0) {
            const key = trimmed.substring(0, eqIdx).trim();
            const val = trimmed.substring(eqIdx + 1).trim().replace(/^['"]|['"]$/g, '');
            localEnvs[key] = val;
          }
        }
      });
      break;
    }
  }

  if (loadedFile) {
    printSuccess(`Loaded environment variables from ${loadedFile}`);
  } else {
    printWarning('No local .env or .env.local file found.');
  }

  // Prompt for missing required variables
  for (const envVar of REQUIRED_ENVS) {
    let val = localEnvs[envVar] || process.env[envVar];
    if (!val) {
      printWarning(`Missing required environment variable: ${envVar}`);
      val = await askQuestion(`Enter value for ${envVar}:`);
      if (!val) {
        printError(`${envVar} cannot be empty. Aborting.`);
        process.exit(1);
      }
      localEnvs[envVar] = val;
      // Write it back to .env
      fs.appendFileSync('.env', `\n${envVar}="${val}"`);
      printSuccess(`Saved ${envVar} to .env`);
    }
  }

  // Verify Vercel Login and Link Status
  printInfo('Checking Vercel authentication...');
  const loggedIn = runCommand('npx vercel whoami', null, false);
  if (!loggedIn) {
    printWarning('Not logged in to Vercel. Triggering authentication...');
    runCommand('npx vercel login', 'Login failed.');
  }

  if (!fs.existsSync('.vercel')) {
    printWarning('Project not linked to Vercel. Linking project now...');
    runCommand('npx vercel link', 'Linking project failed.');
  }

  // Sync variables to Vercel
  printInfo('Syncing environment variables to Vercel production...');
  for (const envVar of REQUIRED_ENVS) {
    const val = localEnvs[envVar] || process.env[envVar];
    try {
      // Use echo to pipe the value into vercel env add to prevent prompt hanging
      execSync(`echo "${val}" | npx vercel env add ${envVar} production`, { stdio: 'ignore' });
      printSuccess(`Configured ${envVar} on Vercel production.`);
    } catch (e) {
      printInfo(`[Note] ${envVar} sync completed (might already exist or was skipped).`);
    }
  }

  // 4. Validate Current Build
  printHeader('4/5 Validating build');
  
  if (!fs.existsSync('node_modules')) {
    printInfo('Installing project dependencies...');
    runCommand('npm install', 'Dependency installation failed.');
  }

  printInfo('Compiling project (npm run build)...');
  const buildSuccess = runCommand('npm run build', 'Build compilation failed. Fix code errors before deploying.');
  if (!buildSuccess) {
    process.exit(1);
  }
  printSuccess('Local build compiled successfully.');

  printInfo('Linting code (npm run lint)...');
  const lintSuccess = runCommand('npm run lint', 'Linting failed.');
  if (!lintSuccess) {
    printWarning('Lint issues detected.');
    const proceed = await askQuestion('Do you want to deploy despite lint warnings/errors? (y/n):');
    if (proceed.toLowerCase() !== 'y' && proceed.toLowerCase() !== 'yes') {
      printError('Deployment aborted due to lint failures.');
      process.exit(1);
    }
  } else {
    printSuccess('Code linting checks passed.');
  }

  // 5. Deploy to Production
  printHeader('5/5 Executing deployment');
  printInfo('Running: npx vercel --prod --yes');
  
  const deploySuccess = runCommand('npx vercel --prod --yes', 'Vercel production deployment failed.');
  if (deploySuccess) {
    console.log(`\n${colors.green}${colors.bold}=========================================${colors.reset}`);
    console.log(`${colors.green}${colors.bold}   Deployment Completed Successfully!    ${colors.reset}`);
    console.log(`${colors.green}${colors.bold}=========================================${colors.reset}`);
    printSuccess('Your production site is live.');
  } else {
    console.log(`\n${colors.red}${colors.bold}=========================================${colors.reset}`);
    console.log(`${colors.red}${colors.bold}          Deployment Failed!             ${colors.reset}`);
    console.log(`${colors.red}${colors.bold}=========================================${colors.reset}`);
    printWarning('If you need to roll back to the previous stable release, run:');
    console.log(`    ${colors.yellow}node deploy.js --rollback${colors.reset}\n`);
    process.exit(1);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
