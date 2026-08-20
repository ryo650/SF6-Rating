import { fetchProcessedProviderAvatar } from "@/features/auth/provider-avatar";
import { getVerifiedUser } from "@/features/auth/session";

export async function GET() {
  try {
    const user = await getVerifiedUser();
    const avatar = await fetchProcessedProviderAvatar(user);
    if (!avatar) return new Response(null, { status: 404 });

    const body = avatar.buffer.buffer.slice(
      avatar.buffer.byteOffset,
      avatar.buffer.byteOffset + avatar.buffer.byteLength,
    ) as ArrayBuffer;
    return new Response(body, {
      headers: {
        "Cache-Control": "private, no-store",
        "Content-Type": "image/webp",
        "Content-Length": String(avatar.byteSize),
        "X-Content-Type-Options": "nosniff",
      },
    });
  } catch {
    return new Response(null, {
      status: 404,
      headers: { "Cache-Control": "private, no-store" },
    });
  }
}
