'use strict';

exports.handler = async function (context, event, callback) {
  const authHandler = require(Runtime.getAssets()['/passcode.js'].path);
  authHandler(context, event, callback);

  let response = new Twilio.Response();
  response.appendHeader('Content-Type', 'application/json');

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
    // Remove participant from conversation
    const participants = await conversationsClient.conversations(room.sid).participants.list();
    const participantToRemove = participants.find((participant) => {
      // Here we need to convert the participant identities from ascii to utf-8 to preserve special characters
      return Buffer.from(participant.identity, 'ascii').toString('utf-8') === event.user_identity;
    });
    await conversationsClient.conversations(room.sid).participants(participantToRemove.sid).remove();
  } catch (e) {
    console.log(e);
    response.setStatusCode(500);
    response.setBody({
      error: {
        message: 'error removing conversation participant',
        explanation: e.message,
      },
    });
    return callback(null, response);
  }

  response.setStatusCode(200);
  response.setBody({
    removed: true,
  });

  callback(null, response);
};
