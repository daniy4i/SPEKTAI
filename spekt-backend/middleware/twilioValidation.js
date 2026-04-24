/**
 * middleware/twilioValidation.js
 *
 * Validates that inbound requests to /twilio/* actually came from Twilio.
 * Uses Twilio's X-Twilio-Signature header + HMAC-SHA1 verification.
 *
 * Only enforced when NODE_ENV === 'production' and TWILIO_AUTH_TOKEN is set.
 * In development the middleware is a no-op so local testing with curl works.
 *
 * Usage:
 *   const validateTwilio = require('../middleware/twilioValidation');
 *   router.post('/voice', validateTwilio, handler);
 */

const twilio = require('twilio');

/**
 * Express middleware.
 * Rejects with 403 if the request signature doesn't match.
 */
function validateTwilio(req, res, next) {
  // Skip in development or when auth token is not configured
  if (process.env.NODE_ENV !== 'production' || !process.env.TWILIO_AUTH_TOKEN) {
    return next();
  }

  const signature  = req.headers['x-twilio-signature'];
  const authToken  = process.env.TWILIO_AUTH_TOKEN;
  const requestUrl = `${process.env.BASE_URL}${req.originalUrl}`;
  const params     = req.body ?? {};

  const valid = twilio.validateRequest(authToken, signature, requestUrl, params);

  if (!valid) {
    console.warn('[TwilioValidation] Invalid signature from', req.ip);
    return res.status(403).json({ error: 'Invalid Twilio signature' });
  }

  next();
}

module.exports = validateTwilio;
