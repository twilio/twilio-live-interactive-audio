# Twilio Live Interactive Audio
:warning: We are no longer allowing new customers to onboard to Twilio Live. Effective November 30, 2023, Twilio Live will End of Life. If you are an existing Live customers, we have created this [Migration Guide](https://support.twilio.com/hc/en-us/articles/10623861544987-Twilio-Live-Migration-Guide) to help you identify an alternative solution for your use case.

## What is it

This project demonstrates an interactive live audio streaming app that uses [Twilio Live](https://www.twilio.com/docs/live) and [Twilio Video](https://www.twilio.com/docs/video). The project is setup as a monorepo that contains the frontend reference applications for iOS. 

## Features

* Deploy the backend to Twilio Serverless in just a few minutes.
* Create or join a stream as a speaker and collaborate with other users.

## Getting Started 

This section describes the steps required for all developers to get started with their respective platform.

### Requirements

* [Node.js v14+](https://nodejs.org/en/download/)
* NPM v7+ (upgrade from NPM 6 with `npm install --global npm`)

### Setup Enviromenment

Copy the `.env.example` file to `.env` and perform the following one-time steps before deploying your application. 

#### Set your Account Sid and Auth Token

Update the ACCOUNT_SID and AUTH_TOKEN `.env` entries with the Account SID and Auth Token found on the [Twilio Console home page](https://twilio.com/console).

#### Set your API Key and API Key Secret 

Create an API Key and Secret and update the TWILIO_API_KEY_SID and TWILIO_API_KEY_SECRET `.env` entries. You can create a new API Key and Secret in the Twilio Console by navigating to `Account -> API Keys`.

#### Provide a Twilio Conversations Service SID 

Update the CONVERSATIONS_SERVICE_SID `.env` entry with your Default Service SID found in `Conversations -> Manage -> Services` or use a new Twilio Conversations Service SID that can be created in the Twilio console.

#### Provide a passcode

Update PASSCODE with a 6 digit numeric passcode. The value may be anything you choose.

#### Install Dependencies

Once you have setup all your environment variables, run `npm install` to install all dependencies from NPM.

### Deploy the app to Twilio

Once the application environment has been configured and dependencies have been installed, you can deploy the app backend using the following command.

```shell
npm run deploy

Backend URL: https://twilio-live-interactive-audio-7873-dev.twil.io
```

If you make any changes to the application, then you can run `npm run deploy` again and subsequent deploys will override your existing app.

If you encounter any deploy errors, try to run `npm run remove` and then `npm run deploy` again.

#### Max Stream Duration

The app is configured to automatically end a stream after it has been running for 30 minutes. This limitation is in place to limit the [charges applied to your Twilio account](https://www.twilio.com/live/pricing) during early testing.

Max duration is specified when the reference backend creates a `PlayerStreamer` and `MediaProcessor`. To change the max duration, edit [this source code](functions/create-room.js#L48) before deploying the app.

### Run the iOS app

#### Configure Backend URL

1.  Replace `BACKEND_URL` in the [app source](https://github.com/twilio/twilio-live-interactive-audio/blob/task/video-7065-ios-ci-config/apps/ios/LiveStream/LiveStream/API/Core/API.swift) with the public URL from the backend deployment

#### Run

1. Run the app
1. Enter any unique name in the `Name` field
1. Enter the passcode from the backend deployment in the `Passcode` field
1. Tap `Sign in`
1. Tap a room in the list to join or tap `Create new room` to create a new room

## Services Used

This application uses Twilio Functions and Twilio Conversations in addition to Twilio Video Rooms and Twilio Live resources. Note that by deploying and using this application, your will be incurring usage for these services and will be billed for usage.
