// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'file_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FileOperationError {

 String get field0;
/// Create a copy of FileOperationError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileOperationErrorCopyWith<FileOperationError> get copyWith => _$FileOperationErrorCopyWithImpl<FileOperationError>(this as FileOperationError, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as FileOperationError;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileOperationError&&(identical(other.field0, _this.field0) || other.field0 == _this.field0));
}


@override
int get hashCode {
  final _this = this as FileOperationError;
  return Object.hash(runtimeType,_this.field0);
}

@override
String toString() {
  final _this = this as FileOperationError;
  return 'FileOperationError(field0: ${_this.field0})';
}


}

/// @nodoc
abstract mixin class $FileOperationErrorCopyWith<$Res>  {
  factory $FileOperationErrorCopyWith(FileOperationError value, $Res Function(FileOperationError) _then) = _$FileOperationErrorCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$FileOperationErrorCopyWithImpl<$Res>
    implements $FileOperationErrorCopyWith<$Res> {
  _$FileOperationErrorCopyWithImpl(this._self, this._then);

  final FileOperationError _self;
  final $Res Function(FileOperationError) _then;

/// Create a copy of FileOperationError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? field0 = null,}) {
  return _then(_self.copyWith(
field0: null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [FileOperationError].
extension FileOperationErrorPatterns on FileOperationError {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( FileOperationError_Io value)?  io,TResult Function( FileOperationError_InvalidName value)?  invalidName,TResult Function( FileOperationError_DestinationExists value)?  destinationExists,TResult Function( FileOperationError_UnsupportedSymlink value)?  unsupportedSymlink,TResult Function( FileOperationError_InvalidPath value)?  invalidPath,required TResult orElse(),}){
final _that = this;
switch (_that) {
case FileOperationError_Io() when io != null:
return io(_that);case FileOperationError_InvalidName() when invalidName != null:
return invalidName(_that);case FileOperationError_DestinationExists() when destinationExists != null:
return destinationExists(_that);case FileOperationError_UnsupportedSymlink() when unsupportedSymlink != null:
return unsupportedSymlink(_that);case FileOperationError_InvalidPath() when invalidPath != null:
return invalidPath(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( FileOperationError_Io value)  io,required TResult Function( FileOperationError_InvalidName value)  invalidName,required TResult Function( FileOperationError_DestinationExists value)  destinationExists,required TResult Function( FileOperationError_UnsupportedSymlink value)  unsupportedSymlink,required TResult Function( FileOperationError_InvalidPath value)  invalidPath,}){
final _that = this;
switch (_that) {
case FileOperationError_Io():
return io(_that);case FileOperationError_InvalidName():
return invalidName(_that);case FileOperationError_DestinationExists():
return destinationExists(_that);case FileOperationError_UnsupportedSymlink():
return unsupportedSymlink(_that);case FileOperationError_InvalidPath():
return invalidPath(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( FileOperationError_Io value)?  io,TResult? Function( FileOperationError_InvalidName value)?  invalidName,TResult? Function( FileOperationError_DestinationExists value)?  destinationExists,TResult? Function( FileOperationError_UnsupportedSymlink value)?  unsupportedSymlink,TResult? Function( FileOperationError_InvalidPath value)?  invalidPath,}){
final _that = this;
switch (_that) {
case FileOperationError_Io() when io != null:
return io(_that);case FileOperationError_InvalidName() when invalidName != null:
return invalidName(_that);case FileOperationError_DestinationExists() when destinationExists != null:
return destinationExists(_that);case FileOperationError_UnsupportedSymlink() when unsupportedSymlink != null:
return unsupportedSymlink(_that);case FileOperationError_InvalidPath() when invalidPath != null:
return invalidPath(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String field0)?  io,TResult Function( String field0)?  invalidName,TResult Function( String field0)?  destinationExists,TResult Function( String field0)?  unsupportedSymlink,TResult Function( String field0)?  invalidPath,required TResult orElse(),}) {final _that = this;
switch (_that) {
case FileOperationError_Io() when io != null:
return io(_that.field0);case FileOperationError_InvalidName() when invalidName != null:
return invalidName(_that.field0);case FileOperationError_DestinationExists() when destinationExists != null:
return destinationExists(_that.field0);case FileOperationError_UnsupportedSymlink() when unsupportedSymlink != null:
return unsupportedSymlink(_that.field0);case FileOperationError_InvalidPath() when invalidPath != null:
return invalidPath(_that.field0);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String field0)  io,required TResult Function( String field0)  invalidName,required TResult Function( String field0)  destinationExists,required TResult Function( String field0)  unsupportedSymlink,required TResult Function( String field0)  invalidPath,}) {final _that = this;
switch (_that) {
case FileOperationError_Io():
return io(_that.field0);case FileOperationError_InvalidName():
return invalidName(_that.field0);case FileOperationError_DestinationExists():
return destinationExists(_that.field0);case FileOperationError_UnsupportedSymlink():
return unsupportedSymlink(_that.field0);case FileOperationError_InvalidPath():
return invalidPath(_that.field0);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String field0)?  io,TResult? Function( String field0)?  invalidName,TResult? Function( String field0)?  destinationExists,TResult? Function( String field0)?  unsupportedSymlink,TResult? Function( String field0)?  invalidPath,}) {final _that = this;
switch (_that) {
case FileOperationError_Io() when io != null:
return io(_that.field0);case FileOperationError_InvalidName() when invalidName != null:
return invalidName(_that.field0);case FileOperationError_DestinationExists() when destinationExists != null:
return destinationExists(_that.field0);case FileOperationError_UnsupportedSymlink() when unsupportedSymlink != null:
return unsupportedSymlink(_that.field0);case FileOperationError_InvalidPath() when invalidPath != null:
return invalidPath(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class FileOperationError_Io extends FileOperationError {
  const FileOperationError_Io(this.field0): super._();
  

@override final  String field0;

/// Create a copy of FileOperationError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileOperationError_IoCopyWith<FileOperationError_Io> get copyWith => _$FileOperationError_IoCopyWithImpl<FileOperationError_Io>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FileOperationError_Io&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'FileOperationError.io(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $FileOperationError_IoCopyWith<$Res> implements $FileOperationErrorCopyWith<$Res> {
  factory $FileOperationError_IoCopyWith(FileOperationError_Io value, $Res Function(FileOperationError_Io) _then) = _$FileOperationError_IoCopyWithImpl;
@override @useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$FileOperationError_IoCopyWithImpl<$Res>
    implements $FileOperationError_IoCopyWith<$Res> {
  _$FileOperationError_IoCopyWithImpl(this._self, this._then);

  final FileOperationError_Io _self;
  final $Res Function(FileOperationError_Io) _then;

/// Create a copy of FileOperationError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(FileOperationError_Io(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FileOperationError_InvalidName extends FileOperationError {
  const FileOperationError_InvalidName(this.field0): super._();
  

@override final  String field0;

/// Create a copy of FileOperationError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileOperationError_InvalidNameCopyWith<FileOperationError_InvalidName> get copyWith => _$FileOperationError_InvalidNameCopyWithImpl<FileOperationError_InvalidName>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FileOperationError_InvalidName&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'FileOperationError.invalidName(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $FileOperationError_InvalidNameCopyWith<$Res> implements $FileOperationErrorCopyWith<$Res> {
  factory $FileOperationError_InvalidNameCopyWith(FileOperationError_InvalidName value, $Res Function(FileOperationError_InvalidName) _then) = _$FileOperationError_InvalidNameCopyWithImpl;
@override @useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$FileOperationError_InvalidNameCopyWithImpl<$Res>
    implements $FileOperationError_InvalidNameCopyWith<$Res> {
  _$FileOperationError_InvalidNameCopyWithImpl(this._self, this._then);

  final FileOperationError_InvalidName _self;
  final $Res Function(FileOperationError_InvalidName) _then;

/// Create a copy of FileOperationError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(FileOperationError_InvalidName(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FileOperationError_DestinationExists extends FileOperationError {
  const FileOperationError_DestinationExists(this.field0): super._();
  

@override final  String field0;

/// Create a copy of FileOperationError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileOperationError_DestinationExistsCopyWith<FileOperationError_DestinationExists> get copyWith => _$FileOperationError_DestinationExistsCopyWithImpl<FileOperationError_DestinationExists>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FileOperationError_DestinationExists&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'FileOperationError.destinationExists(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $FileOperationError_DestinationExistsCopyWith<$Res> implements $FileOperationErrorCopyWith<$Res> {
  factory $FileOperationError_DestinationExistsCopyWith(FileOperationError_DestinationExists value, $Res Function(FileOperationError_DestinationExists) _then) = _$FileOperationError_DestinationExistsCopyWithImpl;
@override @useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$FileOperationError_DestinationExistsCopyWithImpl<$Res>
    implements $FileOperationError_DestinationExistsCopyWith<$Res> {
  _$FileOperationError_DestinationExistsCopyWithImpl(this._self, this._then);

  final FileOperationError_DestinationExists _self;
  final $Res Function(FileOperationError_DestinationExists) _then;

/// Create a copy of FileOperationError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(FileOperationError_DestinationExists(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FileOperationError_UnsupportedSymlink extends FileOperationError {
  const FileOperationError_UnsupportedSymlink(this.field0): super._();
  

@override final  String field0;

/// Create a copy of FileOperationError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileOperationError_UnsupportedSymlinkCopyWith<FileOperationError_UnsupportedSymlink> get copyWith => _$FileOperationError_UnsupportedSymlinkCopyWithImpl<FileOperationError_UnsupportedSymlink>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FileOperationError_UnsupportedSymlink&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'FileOperationError.unsupportedSymlink(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $FileOperationError_UnsupportedSymlinkCopyWith<$Res> implements $FileOperationErrorCopyWith<$Res> {
  factory $FileOperationError_UnsupportedSymlinkCopyWith(FileOperationError_UnsupportedSymlink value, $Res Function(FileOperationError_UnsupportedSymlink) _then) = _$FileOperationError_UnsupportedSymlinkCopyWithImpl;
@override @useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$FileOperationError_UnsupportedSymlinkCopyWithImpl<$Res>
    implements $FileOperationError_UnsupportedSymlinkCopyWith<$Res> {
  _$FileOperationError_UnsupportedSymlinkCopyWithImpl(this._self, this._then);

  final FileOperationError_UnsupportedSymlink _self;
  final $Res Function(FileOperationError_UnsupportedSymlink) _then;

/// Create a copy of FileOperationError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(FileOperationError_UnsupportedSymlink(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FileOperationError_InvalidPath extends FileOperationError {
  const FileOperationError_InvalidPath(this.field0): super._();
  

@override final  String field0;

/// Create a copy of FileOperationError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileOperationError_InvalidPathCopyWith<FileOperationError_InvalidPath> get copyWith => _$FileOperationError_InvalidPathCopyWithImpl<FileOperationError_InvalidPath>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FileOperationError_InvalidPath&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'FileOperationError.invalidPath(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $FileOperationError_InvalidPathCopyWith<$Res> implements $FileOperationErrorCopyWith<$Res> {
  factory $FileOperationError_InvalidPathCopyWith(FileOperationError_InvalidPath value, $Res Function(FileOperationError_InvalidPath) _then) = _$FileOperationError_InvalidPathCopyWithImpl;
@override @useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$FileOperationError_InvalidPathCopyWithImpl<$Res>
    implements $FileOperationError_InvalidPathCopyWith<$Res> {
  _$FileOperationError_InvalidPathCopyWithImpl(this._self, this._then);

  final FileOperationError_InvalidPath _self;
  final $Res Function(FileOperationError_InvalidPath) _then;

/// Create a copy of FileOperationError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(FileOperationError_InvalidPath(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
