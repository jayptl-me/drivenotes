import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'note_model.g.dart';

@JsonSerializable()
class NoteModel extends Equatable {
  final String id;
  final String title;
  final String? content;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final List<String> tags;

  const NoteModel({
    required this.id,
    required this.title,
    this.content,
    required this.createdAt,
    required this.modifiedAt,
    this.tags = const [],
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) =>
      _$NoteModelFromJson(json);

  Map<String, dynamic> toJson() => _$NoteModelToJson(this);

  NoteModel copyWith({
    String? title,
    String? content,
    DateTime? modifiedAt,
    List<String>? tags,
  }) {
    return NoteModel(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? DateTime.now(),
      tags: tags ?? this.tags,
    );
  }

  @override
  List<Object?> get props => [id, title, content, createdAt, modifiedAt, tags];
}
