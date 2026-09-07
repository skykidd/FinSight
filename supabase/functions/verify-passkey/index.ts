import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import * as jose from 'https://deno.land/x/jose@v4.14.4/index.ts'

serve(async (req) => {
  // 1. Handle CORS (Crucial so your Firebase website is allowed to talk to this script)
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 2. Receive the Face ID receipt from Flutter
    const { email } = await req.json()

    if (!email) {
      throw new Error("Email is required to generate a pass.")
    }

    // 3. Grab your database's master key (Supabase handles this securely behind the scenes)
    const JWT_SECRET = Deno.env.get('SUPABASE_JWT_SECRET')
    const secret = new TextEncoder().encode(JWT_SECRET)

    // 4. The Magic Handshake: Create a real Supabase VIP Pass
    const alg = 'HS256'
    const customToken = await new jose.SignJWT({
      aud: 'authenticated',
      role: 'authenticated', // This tells Supabase "Let them in!"
      email: email,
      app_metadata: { provider: 'corbado' },
    })
      .setProtectedHeader({ alg })
      .setIssuedAt()
      .setExpirationTime('1h') // Token expires in 1 hour for security
      .sign(secret)

    // 5. Hand the new pass back to your Flutter app
    return new Response(
      JSON.stringify({ supabaseToken: customToken }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { 
      status: 400, 
      headers: corsHeaders 
    })
  }
})