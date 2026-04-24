# SPEKT Backend Deployment

## Deploy to Railway

1. Go to railway.app and sign in with GitHub
2. Click "New Project" → "Deploy from GitHub repo"
3. Select the LannaiOSApp-main repo
4. Set the ROOT DIRECTORY to: spekt-backend
5. Railway will auto-detect Node.js and run `node server.js`

## Set Environment Variables in Railway Dashboard

Go to your project → Variables tab and add:

| Variable | Value |
|----------|-------|
| OPENAI_API_KEY | Your OpenAI key |
| TWILIO_ACCOUNT_SID | From twilio.com/console |
| TWILIO_AUTH_TOKEN | From twilio.com/console |
| TWILIO_PHONE_NUMBER | +19107735824 |
| BASE_URL | https://YOUR-APP.up.railway.app (set after first deploy) |
| ALLOWED_ORIGIN | * |

## After First Deploy

1. Copy your Railway public URL (shown in Railway dashboard)
2. Update BASE_URL variable in Railway to match that URL
3. Go to Twilio Console → Phone Numbers → +1 (910) 773-5824
4. Set Voice webhook to: POST https://YOUR-URL.up.railway.app/twilio/voice
5. Save in Twilio Console

## Verify Deploy Worked

Visit: https://YOUR-URL.up.railway.app/health
Should return: {"status":"ok","ts":"..."}

## Test the Pipeline

1. Call +1 (910) 773-5824 from any phone
2. Have a short conversation
3. Hang up
4. Wait 30-60 seconds
5. Hit: GET https://YOUR-URL.up.railway.app/api/calls/latest
6. Should return your call with status "ready" and results
