import * as jose from 'jose';
import { ConfigService } from './ConfigService';

let privateKey: jose.KeyLike;

async function ensureKeys() {
    if (!privateKey) {
        const keys = await jose.generateKeyPair('EdDSA');
        privateKey = keys.privateKey;
    }
}

export class AuthService {
    static getAuthServerUrl() {
        const domain = ConfigService.getAuthDomain();
        return `https://sessions.${domain}`;
    }

    static async generateTokens(uuid: string, name: string) {
        // Try fetching from server first
        try {
            const authServerUrl = this.getAuthServerUrl();
            console.log(`Fetching auth tokens from ${authServerUrl}/game-session/child`);
            
            const response = await fetch(`${authServerUrl}/game-session/child`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    uuid,
                    name,
                    scopes: ['hytale:server', 'hytale:client']
                })
            });

            if (response.ok) {
                const data = await response.json() as { IdentityToken?: string; identityToken?: string; SessionToken?: string; sessionToken?: string };
                console.log('Auth tokens received from server');
                return {
                    identityToken: data.IdentityToken || data.identityToken,
                    sessionToken: data.SessionToken || data.sessionToken
                };
            }
        } catch (e) {
            console.warn('Failed to fetch auth tokens from server, falling back to local generation:', e);
        }

        // Fallback: Generate locally
        await ensureKeys();
        
        const issuer = this.getAuthServerUrl();
        const now = Math.floor(Date.now() / 1000);
        const exp = now + 36000;

        const identityToken = await new jose.SignJWT({
            sub: uuid,
            name: name,
            username: name,
            entitlements: ['game.base'],
            scope: 'hytale:server hytale:client',
            jti: crypto.randomUUID(),
        })
            .setProtectedHeader({ alg: 'EdDSA', kid: '2025-10-01', typ: 'JWT' })
            .setIssuedAt(now)
            .setExpirationTime(exp)
            .setIssuer(issuer)
            .sign(privateKey);

        const sessionToken = await new jose.SignJWT({
            sub: uuid,
            scope: 'hytale:server',
            jti: crypto.randomUUID(),
        })
            .setProtectedHeader({ alg: 'EdDSA', kid: '2025-10-01', typ: 'JWT' })
            .setIssuedAt(now)
            .setExpirationTime(exp)
            .setIssuer(issuer)
            .sign(privateKey);

        return { identityToken, sessionToken };
    }
}
