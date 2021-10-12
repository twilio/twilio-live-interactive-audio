'use strict';

module.exports = async (context, event, callback) => {
  let response = new Twilio.Response();
  response.appendHeader('Content-Type', 'application/json');

  if (context.PASSCODE !== event.passcode) {
    response.setStatusCode(401);
    response.setBody({
      error: {
        message: 'passcode incorrect',
        explanation: 'The passcode used to validate application users is incorrect.',
      },
    });
    return callback(null, response);
  }
};
