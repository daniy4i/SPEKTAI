/**
 * transcription.js
 *
 * Downloads a Twilio recording and sends it to OpenAI Whisper.
 * Twilio recording URLs require Basic auth (AccountSid:AuthToken).
 * We stream the audio directly into a File object for the OpenAI SDK —
 * no disk I/O required.
 */

const { toFile } = require('openai');

/**
 * @param {import('openai').OpenAI} openai
 * @param {string} recordingUrl  - Twilio recording URL (ending in .mp3)
 * @returns {Promise<string>}    - Transcript text
 */
async function transcribeRecording(openai, recordingUrl) {
  // 1. Download from Twilio with Basic auth
  const auth = Buffer.from(
    `${process.env.TWILIO_ACCOUNT_SID}:${process.env.TWILIO_AUTH_TOKEN}`
  ).toString('base64');

  const mp3Url = recordingUrl.endsWith('.mp3')
    ? recordingUrl
    : `${recordingUrl}.mp3`;

  const response = await fetch(mp3Url, {
    headers: { Authorization: `Basic ${auth}` },
  });

  if (!response.ok) {
    throw new Error(`Failed to download recording: ${response.status} ${response.statusText}`);
  }

  // 2. Buffer the audio
  const audioBuffer = await response.arrayBuffer();

  // 3. Wrap as a File for the OpenAI SDK
  const audioFile = await toFile(Buffer.from(audioBuffer), 'recording.mp3', {
    type: 'audio/mpeg',
  });

  // 4. Send to Whisper
  const transcription = await openai.audio.transcriptions.create({
    file:  audioFile,
    model: 'whisper-1',
    language: 'en',
  });

  return transcription.text;
}

module.exports = { transcribeRecording };
