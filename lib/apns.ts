import http2 from 'node:http2';
import { SignJWT, importPKCS8 } from 'jose';

const APNS_PRODUCTION_HOST = 'https://api.push.apple.com';
const APNS_SANDBOX_HOST = 'https://api.sandbox.push.apple.com';

let cachedProviderToken: { token: string; issuedAt: number } | undefined;

// APNs provider (JWT) tokens are valid for up to 60 minutes — reuse within
// that window instead of re-signing on every push.
async function getProviderToken(): Promise<string> {
  const keyId = process.env.APNS_KEY_ID;
  const teamId = process.env.APNS_TEAM_ID;
  const privateKeyPem = process.env.APNS_PRIVATE_KEY;
  if (!keyId || !teamId || !privateKeyPem) {
    throw new Error('APNs environment variables are not configured');
  }

  if (cachedProviderToken && Date.now() - cachedProviderToken.issuedAt < 55 * 60 * 1000) {
    return cachedProviderToken.token;
  }

  const key = await importPKCS8(privateKeyPem.replace(/\\n/g, '\n'), 'ES256');
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: 'ES256', kid: keyId })
    .setIssuedAt()
    .setIssuer(teamId)
    .sign(key);

  cachedProviderToken = { token, issuedAt: Date.now() };
  return token;
}

export interface PushNotificationParams {
  deviceToken: string;
  environment: 'sandbox' | 'production';
  title: string;
  body: string;
  data?: Record<string, unknown>;
}

// Sends a single alert push directly over HTTP/2 — no push-hosting service,
// per the architecture baseline (§0). Node's http2 module (Edge Runtime has
// no equivalent) is why every route that calls this must run on Node.js.
export async function sendPushNotification(params: PushNotificationParams): Promise<void> {
  const bundleId = process.env.APNS_BUNDLE_ID;
  if (!bundleId) {
    throw new Error('APNS_BUNDLE_ID environment variable is not set');
  }

  const providerToken = await getProviderToken();
  const host = params.environment === 'production' ? APNS_PRODUCTION_HOST : APNS_SANDBOX_HOST;

  const payload = {
    aps: { alert: { title: params.title, body: params.body }, sound: 'default' },
    data: params.data ?? {},
  };

  await new Promise<void>((resolve, reject) => {
    const client = http2.connect(host);
    client.on('error', reject);

    const req = client.request({
      ':method': 'POST',
      ':path': `/3/device/${params.deviceToken}`,
      authorization: `bearer ${providerToken}`,
      'apns-topic': bundleId,
      'apns-push-type': 'alert',
      'content-type': 'application/json',
    });

    let status = 0;
    let responseBody = '';

    req.on('response', (headers) => {
      status = Number(headers[':status']);
    });
    req.setEncoding('utf8');
    req.on('data', (chunk) => {
      responseBody += chunk;
    });
    req.on('end', () => {
      client.close();
      if (status >= 200 && status < 300) {
        resolve();
      } else {
        reject(new Error(`APNs push failed (${status}): ${responseBody}`));
      }
    });
    req.on('error', (err) => {
      client.close();
      reject(err);
    });

    req.end(JSON.stringify(payload));
  });
}
