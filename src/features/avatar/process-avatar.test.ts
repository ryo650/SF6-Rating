import sharp from "sharp";
import { describe, expect, it } from "vitest";
import {
  AvatarValidationError,
  MAX_AVATAR_BYTES,
  processAvatar,
} from "./process-avatar";

describe("processAvatar", () => {
  it.each(["jpeg", "png", "webp"] as const)(
    "decodes, crops, and re-encodes %s as square WebP",
    async (format) => {
      const pipeline = sharp({
        create: {
          width: 800,
          height: 400,
          channels: 3,
          background: "#f97316",
        },
      });
      const source = await pipeline[format]().toBuffer();
      const processed = await processAvatar(
        source.buffer.slice(
          source.byteOffset,
          source.byteOffset + source.byteLength,
        ) as ArrayBuffer,
      );

      expect(processed.width).toBe(400);
      expect(processed.height).toBe(400);
      expect(processed.byteSize).toBeGreaterThan(0);
      expect(processed.sha256).toMatch(/^[0-9a-f]{64}$/);
      expect((await sharp(processed.buffer).metadata()).format).toBe("webp");
    },
  );

  it("rejects SVG even when the decoder supports it", async () => {
    const svg = new TextEncoder().encode(
      '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"/>',
    );
    await expect(processAvatar(svg.buffer)).rejects.toEqual(
      expect.objectContaining({ code: "avatar_format" }),
    );
  });

  it("rejects empty and oversized input before decoding", async () => {
    await expect(processAvatar(new ArrayBuffer(0))).rejects.toBeInstanceOf(
      AvatarValidationError,
    );
    await expect(
      processAvatar(new ArrayBuffer(MAX_AVATAR_BYTES + 1)),
    ).rejects.toEqual(expect.objectContaining({ code: "avatar_size" }));
  });
});
