import 'dart:typed_data';

import 'package:json_annotation/json_annotation.dart';

part 'epub_isolate_dto.g.dart';

@JsonSerializable()
class BlockStyleDto {
  final double? leftMargin;
  final double? rightMargin;
  final double? topMargin;
  final double? bottomMargin;
  final double? leftIndent;
  final int? alignment;
  final double? maxHeight;
  final double? maxWidth;

  const BlockStyleDto({
    this.leftMargin,
    this.rightMargin,
    this.topMargin,
    this.bottomMargin,
    this.leftIndent,
    this.alignment,
    this.maxHeight,
    this.maxWidth,
  });

  factory BlockStyleDto.fromJson(Map<String, dynamic> json) => _$BlockStyleDtoFromJson(json);
  Map<String, dynamic> toJson() => _$BlockStyleDtoToJson(this);
}

@JsonSerializable()
class ElementStyleDto {
  final double? fontSize;
  final String? fontFamily;
  final int? fontWeight;
  final int? fontStyle;
  final int? decoration;
  final int? color;
  final bool? isDropCaps;

  const ElementStyleDto({
    this.fontSize,
    this.fontFamily,
    this.fontWeight,
    this.fontStyle,
    this.decoration,
    this.color,
    this.isDropCaps,
  });

  factory ElementStyleDto.fromJson(Map<String, dynamic> json) => _$ElementStyleDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ElementStyleDtoToJson(this);
}

@JsonSerializable()
class TextContentDto extends ContentDto {
  final String text;

  const TextContentDto({
    required this.text,
    required super.blockStyle,
    required super.elementStyle,
  }) : super(type: 'text');

  factory TextContentDto.fromJson(Map<String, dynamic> json) => _$TextContentDtoFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$TextContentDtoToJson(this);
}

@JsonSerializable()
class LinkContentDto extends ContentDto {
  @JsonKey(fromJson: ContentDto.fromJson, toJson: _contentToJson)
  final ContentDto src;

  @JsonKey(fromJson: _contentListFromJson, toJson: _contentListToJson)
  final List<ContentDto> footnotes;

  final String href;

  const LinkContentDto({
    required this.src,
    required this.footnotes,
    required this.href,
    required super.blockStyle,
    required super.elementStyle,
  }) : super(type: 'link');

  factory LinkContentDto.fromJson(Map<String, dynamic> json) => _$LinkContentDtoFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$LinkContentDtoToJson(this);
}

@JsonSerializable()
class LineBreakDto extends ContentDto {
  const LineBreakDto({
    required super.blockStyle,
    required super.elementStyle,
  }) : super(type: 'line_break');

  factory LineBreakDto.fromJson(Map<String, dynamic> json) => _$LineBreakDtoFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$LineBreakDtoToJson(this);
}

@JsonSerializable()
class ParagraphBreakDto extends ContentDto {
  const ParagraphBreakDto({
    required super.blockStyle,
    required super.elementStyle,
  }) : super(type: 'paragraph_break');

  factory ParagraphBreakDto.fromJson(Map<String, dynamic> json) => _$ParagraphBreakDtoFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$ParagraphBreakDtoToJson(this);
}

@JsonSerializable()
class ImageBytesDto extends ContentDto {
  final Uint8List bytes;

  const ImageBytesDto({
    required this.bytes,
    required super.blockStyle,
    required super.elementStyle,
  }) : super(type: 'image');

  factory ImageBytesDto.fromJson(Map<String, dynamic> json) => _$ImageBytesDtoFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$ImageBytesDtoToJson(this);
}

abstract class ContentDto {
  final String type;
  final BlockStyleDto blockStyle;
  final ElementStyleDto elementStyle;

  const ContentDto({
    required this.type,
    required this.blockStyle,
    required this.elementStyle,
  });

  Map<String, dynamic> toJson();

  static ContentDto fromJson(Map<String, dynamic> json) {
    switch (json['type'] as String?) {
      case 'text':
        return TextContentDto.fromJson(json);
      case 'link':
        return LinkContentDto.fromJson(json);
      case 'line_break':
        return LineBreakDto.fromJson(json);
      case 'paragraph_break':
        return ParagraphBreakDto.fromJson(json);
      case 'image':
        return ImageBytesDto.fromJson(json);
      default:
        throw StateError('Unknown content type: ${json['type']}');
    }
  }
}

Map<String, dynamic> _contentToJson(ContentDto content) => content.toJson();

List<ContentDto> _contentListFromJson(List<dynamic> json) =>
    json.map((item) => ContentDto.fromJson((item as Map).cast<String, dynamic>())).toList();

List<Map<String, dynamic>> _contentListToJson(List<ContentDto> contents) =>
    contents.map((content) => content.toJson()).toList();
