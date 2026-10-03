import { createHash } from "node:crypto";
import sharp, { type Metadata } from "sharp";

export const MAX_AVATAR_BYTES = 5 * 1024 * 1024;
export const MAX_AVATAR_PIXELS = 16_777_216;
export const MAX_AVATAR_DIMENSION = 512;

const allowedFormats = new Set(["jpeg", "png", "webp"]);

export class AvatarValidationError extends Error {
  constructor(public readonly code: string) {
    super(code);
    this.name = "AvatarValidationError";
  }
}

export type ProcessedAvatar = {
  buffer: Buffer;
  byteSize: number;
  width: number;
  height: number;
  sha256: string;
};

export async function processAvatar(
  input: ArrayBuffer,
): Promise<ProcessedAvatar> {
  if (input.byteLength < 1 || input.byteLength > MAX_AVATAR_BYTES) {
    throw new AvatarValidationError("avatar_size");
  }

  const source = Buffer.from(input);
  const probe = sharp(source, {
    animated: true,
    failOn: "warning",
    limitInputPixels: MAX_AVATAR_PIXELS,
  });

  let metadata: Metadata;
  try {
    metadata = await probe.metadata();
  } catch {
    throw new AvatarValidationError("avatar_decode");
  }

  if (!metadata.format || !allowedFormats.has(metadata.format)) {
    throw new AvatarValidationError("avatar_format");
  }

  if ((metadata.pages ?? 1) > 1) {
    throw new AvatarValidationError("avatar_animated");
  }

  if (!metadata.width || !metadata.height) {
    throw new AvatarValidationError("avatar_dimensions");
  }

  if (metadata.width * metadata.height > MAX_AVATAR_PIXELS) {
    throw new AvatarValidationError("avatar_pixels");
  }

  let output: Buffer;
  try {
    output = await sharp(source, {
      animated: false,
      failOn: "warning",
      limitInputPixels: MAX_AVATAR_PIXELS,
    })
      .rotate()
      .resize({
        width: Math.min(MAX_AVATAR_DIMENSION, metadata.width, metadata.height),
        height: Math.min(MAX_AVATAR_DIMENSION, metadata.width, metadata.height),
        fit: "cover",
        position: "centre",
        withoutEnlargement: true,
      })
      .webp({ quality: 82, effort: 4 })
      .toBuffer();
  } catch {
    throw new AvatarValidationError("avatar_processing");
  }

  const outputMetadata = await sharp(output).metadata();
  if (
    outputMetadata.format !== "webp" ||
    !outputMetadata.width ||
    !outputMetadata.height ||
    outputMetadata.width !== outputMetadata.height ||
    outputMetadata.width > MAX_AVATAR_DIMENSION
  ) {
    throw new AvatarValidationError("avatar_processing");
  }

  return {
    buffer: output,
    byteSize: output.byteLength,
    width: outputMetadata.width,
    height: outputMetadata.height,
    sha256: createHash("sha256").update(output).digest("hex"),
  };
}
