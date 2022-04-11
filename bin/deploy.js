#!/usr/bin/env node

require('dotenv').config();
const { cli } = require('cli-ux');
const promisify = require('util').promisify;
const exec = promisify(require('child_process').exec);

(async () => {
  try {
    /**
     * Deploy the builds and extract user output from the twilio-run command
     */
    cli.action.start('deploying functions');
    const { stdout } = await exec(`npx twilio-run deploy --region=${process.env.TWILIO_REGION} --override-existing-project`);
    const twilioRunOutputRegex = RegExp('domain\\s+(?<domain>.*)', 'm');
    const match = stdout.match(twilioRunOutputRegex);
    if (match.groups && match.groups.domain) {
      const backendUrl = `https://${match.groups.domain.trim()}`;
      cli.action.stop('done');
      console.log(`Backend URL: ${backendUrl}`);
    } else {
      throw Error('Failed to extract backend url');
    }
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
})();
