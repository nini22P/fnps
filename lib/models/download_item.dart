import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:vita_dl/hive/hive_types.dart';
import 'package:vita_dl/models/content.dart';

part 'download_item.freezed.dart';
part 'download_item.g.dart';

@HiveType(typeId: downloadStatusTypeId)
enum DownloadStatus {
  @HiveField(0)
  enqueued,
  @HiveField(1)
  running,
  @HiveField(2)
  paused,
  @HiveField(3)
  complete,
  @HiveField(4)
  failed,
  @HiveField(5)
  notFound,
  @HiveField(6)
  waitingToRetry,
  @HiveField(7)
  canceled,
}

@HiveType(typeId: extractStatusTypeId)
enum ExtractStatus {
  @HiveField(0)
  enqueued,
  @HiveField(1)
  running,
  @HiveField(2)
  complete,
  @HiveField(3)
  failed,
}

@freezed
@HiveType(typeId: downloadItemTypeId)
abstract class DownloadItem extends HiveObject with _$DownloadItem {
  DownloadItem._();

  factory DownloadItem({
    @HiveField(0) required Content content,
    @HiveField(1) @Default(0) double progress,
    @HiveField(2)
    @Default(DownloadStatus.enqueued)
    DownloadStatus downloadStatus,
    @HiveField(3) @Default(ExtractStatus.enqueued) ExtractStatus extractStatus,
    @HiveField(4) @Default(0) int fileSize,
  }) = _DownloadItem;

  factory DownloadItem.fromJson(Map<String, dynamic> json) =>
      _$DownloadItemFromJson(json);
}
