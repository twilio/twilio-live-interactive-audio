const axios = require('axios');

exports.handler = async function (context, event, callback) {
  const authHandler = require(Runtime.getAssets()['/passcode.js'].path);
  authHandler(context, event, callback);

  const common = require(Runtime.getAssets()['/common.js'].path);
  const { axiosClient, response } = common(context, event, callback);

  const client = context.getTwilioClient();
  const conversationsClient = client.conversations.services(context.CONVERSATIONS_SERVICE_SID);

  try {
    // Stop room
    const room = await client.video.rooms(event.room_name).update({ status: 'completed' });

    // Get playerStreamerSid and mediaProcessorSid from conversation attributes
    const conversation = await conversationsClient.conversations(room.sid).fetch();
    const { playerStreamerSid, mediaProcessorSid } = JSON.parse(conversation.attributes);

    // delete conversation
    await conversationsClient.conversations(room.sid).remove();

    // Stop MediaProcessor
    await axiosClient(`MediaProcessors/${mediaProcessorSid}`, {
      method: 'post',
      data: 'Status=ENDED',
    });

    // Stop PlayerStreamer
    await axiosClient(`PlayerStreamers/${playerStreamerSid}`, {
      method: 'post',
      data: 'Status=ENDED',
    });
  } catch (e) {
    console.log(e);
    response.setStatusCode(500);
    response.setBody({
      error: {
        message: 'error deleting room',
        explanation: e.message,
      },
    });
    return callback(null, response);
  }

  response.setBody({
    deleted: true,
  });

  callback(null, response);
};
