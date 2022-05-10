#!/usr/bin/env node

require('dotenv').config();
const client = require('twilio')(process.env.ACCOUNT_SID, process.env.AUTH_TOKEN);
const { cli } = require('cli-ux');

(async () => {
  try {
    cli.action.start('removing');
    const services = await client.serverless.services.list();
    const app = services.find((service) => service.friendlyName.includes("twilio-live-interactive-audio"));
    if (app) {
      await client.serverless.services(app.sid).remove();
    }
    cli.action.stop('done');
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
})();
