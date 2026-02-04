import 'dart:io';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// 写真の分析結果
class ImageAnalysisResult {
  /// 植物が写っている可能性（0.0〜1.0）
  final double plantConfidence;

  /// 風景写真の可能性（0.0〜1.0）
  final double landscapeConfidence;

  /// 植物が写っているかどうか
  final bool hasPlant;

  /// 風景写真かどうか
  final bool isLandscape;

  /// ML Kit が返した全ラベル（デバッグ用）
  final List<String> allLabels;

  const ImageAnalysisResult({
    required this.plantConfidence,
    required this.landscapeConfidence,
    required this.hasPlant,
    required this.isLandscape,
    required this.allLabels,
  });
}

/// Cloud API による作物同定の結果
class PlantIdResult {
  final String name;
  final double confidence;

  /// サーバー経由（Claude/GPT-4V）の場合、追加の説明が返る
  /// 例: 「トマトの苗、本葉4枚程度。健康状態は良好」
  final String? description;

  const PlantIdResult({
    required this.name,
    required this.confidence,
    this.description,
  });
}

/// ML Kit (オンデバイス) を使った画像分類サービス
class ImageAnalysisService {
  ImageLabeler? _labeler;

  static const _plantLabels = {
    'plant', 'flower', 'tree', 'grass', 'leaf', 'herb',
    'houseplant', 'vegetation', 'shrub', 'garden', 'fruit',
    'vegetable', 'food', 'produce', 'seedling', 'sprout',
  };

  static const _landscapeLabels = {
    'sky', 'landscape', 'mountain', 'building', 'field',
    'cloud', 'outdoor', 'nature', 'horizon', 'farmland',
    'agriculture', 'soil', 'ground', 'land',
  };

  ImageLabeler _getLabeler() {
    _labeler ??= ImageLabeling.client(
      ImageLabelerOptions(confidenceThreshold: 0.4),
    );
    return _labeler!;
  }

  /// 画像を分析し、植物/風景を分類する
  Future<ImageAnalysisResult> analyze(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final labeler = _getLabeler();

    final labels = await labeler.processImage(inputImage);

    double plantConf = 0.0;
    double landscapeConf = 0.0;
    final allLabels = <String>[];

    for (final label in labels) {
      final text = label.label.toLowerCase();
      allLabels.add('${label.label}(${label.confidence.toStringAsFixed(2)})');

      if (_plantLabels.any((p) => text.contains(p))) {
        if (label.confidence > plantConf) {
          plantConf = label.confidence;
        }
      }
      if (_landscapeLabels.any((l) => text.contains(l))) {
        if (label.confidence > landscapeConf) {
          landscapeConf = label.confidence;
        }
      }
    }

    return ImageAnalysisResult(
      plantConfidence: plantConf,
      landscapeConfidence: landscapeConf,
      hasPlant: plantConf >= 0.5,
      isLandscape: landscapeConf >= 0.5 && plantConf < 0.5,
      allLabels: allLabels,
    );
  }

  void dispose() {
    _labeler?.close();
    _labeler = null;
  }
}
