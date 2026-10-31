const encoder = new TextEncoder();

function digest(text: string): Promise<ArrayBuffer> {
  return crypto.subtle.digest("SHA-256", encoder.encode(text));
}

/**
 * Compares digests, so the check takes the same time for any token length.
 * A secret that was never set refuses everyone.
 */
export async function presentsToken(request: Request, secret: string | undefined): Promise<boolean> {
  if (!secret) return false;
  const header = request.headers.get("Authorization") ?? "";
  const presented = header.startsWith("Bearer ") ? header.slice("Bearer ".length) : "";
  const [given, wanted] = await Promise.all([digest(presented), digest(secret)]);
  return crypto.subtle.timingSafeEqual(given, wanted);
}
