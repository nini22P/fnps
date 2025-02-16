import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:fnps/hive/hive_types.dart';
import 'package:fnps/models/content.dart';

part 'download_item.freezed.dart';
part 'download_item.g.dart';

@HiveType(typeId: downloadStatusTypeId)
enum DownloadStatus {
  @HiveField(0)
  queued,
  @HiveField(1)
  downloading,
  @HiveField(2)
  completed,
  @HiveField(3)
  failed,
  @HiveField(4)
  paused,
  @HiveField(5)
  canceled,
}

@HiveType(typeId: extractStatusTypeId)
enum ExtractStatus {
  @HiveField(0)
  queued,
  @HiveField(1)
  extracting,
  @HiveField(2)
  completed,
  @HiveField(3)
  failed,
  @HiveField(4)
  notNeeded,
}

@freezed
@HiveType(typeId: downloadItemTypeId)
abstract class DownloadItem extends HiveObject with _$DownloadItem {
  DownloadItem._();

  factory DownloadItem({
    @HiveField(0) required String id,
    @HiveField(1) required String filename,
    @HiveField(2) required List<String> directory,
    @HiveField(3) @Default(0) double progress,
    @HiveField(4) @Default(0) int size,
    @HiveField(5) required Content content,
    @HiveField(6) @Default(DownloadStatus.queued) DownloadStatus downloadStatus,
    @HiveField(7) @Default(ExtractStatus.queued) ExtractStatus extractStatus,
  }) = _DownloadItem;

  factory DownloadItem.fromJson(Map<String, dynamic> json) =>
      _$DownloadItemFromJson(json);
}
