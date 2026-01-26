import { Elysia, t } from 'elysia';
import { AuthService } from '../services/AuthService';

export const authRoutes = new Elysia({ prefix: '/game-session' })
  .post('/child', async ({ body }) => {
    // The client sends: { uuid, name, scopes }
    const { name, uuid } = body as { name: string, uuid: string };
    
    console.log(`[Auth] Login request for user: ${name} (${uuid})`);

    const tokens = await AuthService.generateTokens(uuid, name);
    
    // Return PascalCase keys as expected by AuthService.dart (it checks both, but let's be safe)
    return {
      IdentityToken: tokens.identityToken,
      SessionToken: tokens.sessionToken
    };
  }, {
    body: t.Object({
      name: t.String(),
      uuid: t.String(),
      scopes: t.Array(t.String())
    })
  });
