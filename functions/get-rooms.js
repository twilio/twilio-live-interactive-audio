exports.handler = async function (context, event, callback) {
  const authHandler = require(Runtime.getAssets()['/passcode.js'].path);
  authHandler(context, event, callback);

  let response = new Twilio.Response();
  response.appendHeader('Content-Type', 'application/json');

  const client = context.getTwilioClient();
  const conversationsClient = client.conversations.services(context.CONVERSATIONS_SERVICE_SID);

  const [conversations, videoRooms] = await Promise.all([
    conversationsClient.conversations.list(),
    client.video.rooms.list(),
  ]);

  const streamingRooms = conversations
    .filter((conversation) => videoRooms.some((room) => room.sid === conversation.uniqueName))
    .map((conversation) => ({
      room_name: conversation.friendlyName,
    }));

  response.setBody({
    rooms: streamingRooms,
  });

  callback(null, response);
};
