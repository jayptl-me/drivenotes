import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'note_model.g.dart';

// NOTE: After changing this model (e.g., making `id` nullable, using `lastModified`),
// you must run the build runner to regenerate the 'note_model.g.dart' file:
// flutter pub run build_runner build --delete-conflicting-outputs

@JsonSerializable()
class NoteModel {
  final String? id; // Made nullable
  final String title;
  final String content;
  final DateTime lastModified;
  final List<String> tags;

  const NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.lastModified,
    this.tags = const [],
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) =>
      _$NoteModelFromJson(json);

  Map<String, dynamic> toJson() => _$NoteModelToJson(this);

  NoteModel copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? lastModified,
    List<String>? tags,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      lastModified: lastModified ?? this.lastModified,
      tags: tags ?? this.tags,
    );
  }
}
