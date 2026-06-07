import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Configuration options for the local client-side image compression.
class ImageCompressionConfig {
  final int quality;
  final int maxDimension;
  final bool continueWithOriginalOnFailure;

  const ImageCompressionConfig({
    this.quality = 80,
    this.maxDimension = 1024,
    this.continueWithOriginalOnFailure = true,
  });
}

class ImageCompressor {
  /// Compresses [originalBytes] using the pure Dart `image` package.
  /// Runs inside a background isolate on mobile/desktop platforms via `compute`
  /// to keep the UI thread fully responsive. Falls back to main thread on web.
  static Future<Uint8List> compress({
    required Uint8List originalBytes,
    required String imageName,
    ImageCompressionConfig config = const ImageCompressionConfig(),
  }) async {
    final double originalSizeKB = originalBytes.lengthInBytes / 1024.0;
    debugPrint(
      '[ImageCompressor] Input Image: "$imageName" | Size: ${originalSizeKB.toStringAsFixed(2)} KB',
    );

    try {
      // Use compute to run the CPU-heavy image processing in a background Isolate
      final Uint8List result = await compute(
        _performCompression,
        _CompressionParams(bytes: originalBytes, config: config),
      );

      final double compressedSizeKB = result.lengthInBytes / 1024.0;
      debugPrint(
        '[ImageCompressor] Compression Success for "$imageName" | New Size: ${compressedSizeKB.toStringAsFixed(2)} KB (Reduced by ${((originalSizeKB - compressedSizeKB) / originalSizeKB * 100).toStringAsFixed(1)}%)',
      );
      return result;
    } catch (e, stackTrace) {
      debugPrint(
        '[ImageCompressor] Error compressing image "$imageName": $e\n$stackTrace',
      );
      if (config.continueWithOriginalOnFailure) {
        debugPrint(
          '[ImageCompressor] Configured fallback active: continuing with original uncompressed image.',
        );
        return originalBytes;
      } else {
        rethrow;
      }
    }
  }
}

class _CompressionParams {
  final Uint8List bytes;
  final ImageCompressionConfig config;

  _CompressionParams({required this.bytes, required this.config});
}

Uint8List _performCompression(_CompressionParams params) {
  final img.Image? decoded = img.decodeImage(params.bytes);
  if (decoded == null) {
    throw Exception(
      'Failed to decode image bytes. Unsupported or corrupted format.',
    );
  }

  img.Image processed = decoded;

  // Proportionally resize if either dimension exceeds maxDimension
  final int maxDim = params.config.maxDimension;
  if (decoded.width > maxDim || decoded.height > maxDim) {
    int targetWidth;
    int targetHeight;

    if (decoded.width > decoded.height) {
      targetWidth = maxDim;
      targetHeight = (decoded.height * (maxDim / decoded.width)).round();
    } else {
      targetHeight = maxDim;
      targetWidth = (decoded.width * (maxDim / decoded.height)).round();
    }

    processed = img.copyResize(
      decoded,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.average,
    );
  }

  // Encode to JPG with specified quality setting
  final Uint8List compressedBytes = Uint8List.fromList(
    img.encodeJpg(processed, quality: params.config.quality),
  );

  return compressedBytes;
}
