'use strict';
const axios = require('axios');

const AccessToken = Twilio.jwt.AccessToken;
const VideoGrant = AccessToken.VideoGrant;
const ChatGrant = AccessToken.ChatGrant;
const MAX_ALLOWED_SESSION_DURATION = 14400;

exports.handler = async function (context, event, callback) {
  console.log('join-room', event);
  const authHandler = require(Runtime.getAssets()['/passcode.js'].path);
  authHandler(context, event, callback);

  const common = require(Runtime.getAssets()['/common.js'].path);
  const { response, getPlaybackGrant } = common(context, event, callback);

  const client = context.getTwilioClient();
  const conversationsClient = client.conversations.services(context.CONVERSATIONS_SERVICE_SID);

  let room, conversation;

  try {
    room = await client.video.rooms(event.room_name).fetch();
  } catch (e) {
    console.error(e);
    response.setStatusCode(500);

    if (e.code === 20404) {
      response.setBody({
        error: {
          message: 'room not found',
          explanation: e.message,
        },
      });
    } else {
      response.setBody({
        error: {
          message: 'error fetching room',
          explanation: e.message,
        },
      });
    }
    return callback(null, response);
  }

  try {
    conversation = await conversationsClient.conversations(room.sid).fetch();
  } catch (e) {
    console.error(e);
    response.setStatusCode(500);
    response.setBody({
      error: {
        message: 'error fetching conversation',
        explanation: e.message,
      },
    });
    return callback(null, response);
  }

  try {
    // Add participant to conversation
    await conversationsClient.conversations(room.sid).participants.create({
      identity: event.user_identity,
      attributes: JSON.stringify({
        role: 'audience',
        hand_raised: false,
      }),
    });
  } catch (e) {
    if (e.code !== 50433) {
      response.setStatusCode(500);
      response.setBody({
        error: {
          message: 'error creating conversation participant',
          explanation: e.message,
        },
      });
      return callback(null, response);
    } else {
      response.setStatusCode(500);
      response.setBody({
        error: {
          message: 'Participant already exists',
          explanation: e.message,
        },
      });
      return callback(null, response);
    }
  }

  let playbackGrant;
  try {
    playbackGrant = await getPlaybackGrant(JSON.parse(conversation.attributes).playerStreamerSid);
  } catch (e) {
    console.error(e);
    response.setStatusCode(500);
    response.setBody({
      error: {
        message: 'error getting playback grant',
        explanation: e.message,
      },
    });
    return callback(null, response);
  }

  // Create token
  const token = new AccessToken(context.ACCOUNT_SID, context.TWILIO_API_KEY_SID, context.TWILIO_API_KEY_SECRET, {
    ttl: MAX_ALLOWED_SESSION_DURATION,
  });

  // Add chat grant to token
  const chatGrant = new ChatGrant({ serviceSid: context.CONVERSATIONS_SERVICE_SID });
  token.addGrant(chatGrant);

  // Add participant's identity to token
  token.identity = event.user_identity;

  // Add video grant to token
  const videoGrant = new VideoGrant({ room: event.room_name });
  token.addGrant(videoGrant);

  // Add player grant to token
  token.addGrant({
    key: 'player',
    player: playbackGrant,
    toPayload: () => playbackGrant,
  });

  // Return token
  response.setStatusCode(200);
  response.setBody({
    token: token.toJwt(),
    room_sid: room.sid,
    conversation_sid: conversation.sid,
  });

  callback(null, response);
};
