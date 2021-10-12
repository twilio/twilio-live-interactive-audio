'use strict';

const querystring = require('querystring');

const AccessToken = Twilio.jwt.AccessToken;
const VideoGrant = AccessToken.VideoGrant;
const ChatGrant = AccessToken.ChatGrant;
const MAX_ALLOWED_SESSION_DURATION = 14400;

exports.handler = async function (context, event, callback) {
  const authHandler = require(Runtime.getAssets()['/passcode.js'].path);
  authHandler(context, event, callback);

  const common = require(Runtime.getAssets()['/common.js'].path);
  const { axiosClient, response } = common(context, event, callback);

  const client = context.getTwilioClient();
  const conversationsClient = client.conversations.services(context.CONVERSATIONS_SERVICE_SID);

  let room, playerStreamer, mediaProcessor, conversation;

  try {
    // Create video room
    room = await client.video.rooms.create({ uniqueName: event.room_name, type: 'group' });
  } catch (e) {
    console.error(e);
    response.setStatusCode(500);

    if (e.code === 53113) {
      response.setBody({
        error: {
          message: 'room already exists',
          explanation: e.message,
        },
      });
    } else {
      response.setBody({
        error: {
          message: 'error creating room',
          explanation: e.message,
        },
      });
    }
    return callback(null, response);
  }

  try {
    // Create PlayerStreamer
    playerStreamer = await axiosClient('PlayerStreamers', {
      method: 'post',
      data: 'Video=false',
    });

    // Create mediaProcessor
    mediaProcessor = await axiosClient('MediaProcessors', {
      method: 'post',
      data: querystring.stringify({
        Extension: context.MEDIA_EXTENSION,
        ExtensionContext: JSON.stringify({
          room: { name: room.sid },
          outputs: [playerStreamer.data.sid],
          video: false
        }),
      }),
    });
  } catch (e) {
    console.error(e);
    response.setStatusCode(500);
    response.setBody({
      error: {
        message: 'error creating stream',
        explanation: e.message,
      },
    });

    return callback(null, response);
  }

  try {
    // Here we add a timer to close the conversation after the maximum length of a room (24 hours).
    // This helps to clean up old conversations since there is a limit that a single participant
    // can not be added to more than 1,000 open conversations.
    conversation = await conversationsClient.conversations.create({
      uniqueName: room.sid,
      friendlyName: event.room_name,
      'timers.closed': 'P1D',
      attributes: JSON.stringify({
        stream_url: playerStreamer.data.playback_url,
        playerStreamerSid: playerStreamer.data.sid,
        mediaProcessorSid: mediaProcessor.data.sid,
      }),
    });
  } catch (e) {
    console.error(e);
    response.setStatusCode(500);
    response.setBody({
      error: {
        message: 'error creating conversation',
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
        role: 'moderator',
        currently_speaking: false,
        muted: false,
      }),
    });
  } catch (e) {
    // Ignore "Participant already exists" error (50433)
    if (e.code !== 50433) {
      response.setStatusCode(500);
      response.setBody({
        error: {
          message: 'error creating conversation participant',
          explanation: e.message,
        },
      });
      return callback(null, response);
    }
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

  // Add video grant to stage token
  const videoGrant = new VideoGrant({ room: event.room_name });
  token.addGrant(videoGrant);

  console.log('Created room:', event.room_name);
  console.log('PlayerStreamer SID:', playerStreamer.data.sid);
  console.log('MediaProcessor SID:', mediaProcessor.data.sid);
  console.log('Conversation SID:', conversation.sid);

  // Return token
  response.setStatusCode(200);
  response.setBody({
    token: token.toJwt(),
    room_sid: room.sid,
    conversation_sid: conversation.sid,
  });

  callback(null, response);
};
