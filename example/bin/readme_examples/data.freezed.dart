// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Person3 {

 String get name; int get age;
/// Create a copy of Person3
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Person3CopyWith<Person3> get copyWith => _$Person3CopyWithImpl<Person3>(this as Person3, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Person3&&(identical(other.name, name) || other.name == name)&&(identical(other.age, age) || other.age == age));
}


@override
int get hashCode => Object.hash(runtimeType,name,age);

@override
String toString() {
  return 'Person3(name: $name, age: $age)';
}


}

/// @nodoc
abstract mixin class $Person3CopyWith<$Res>  {
  factory $Person3CopyWith(Person3 value, $Res Function(Person3) _then) = _$Person3CopyWithImpl;
@useResult
$Res call({
 String name, int age
});




}
/// @nodoc
class _$Person3CopyWithImpl<$Res>
    implements $Person3CopyWith<$Res> {
  _$Person3CopyWithImpl(this._self, this._then);

  final Person3 _self;
  final $Res Function(Person3) _then;

/// Create a copy of Person3
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? age = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,age: null == age ? _self.age : age // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Person3].
extension Person3Patterns on Person3 {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Person3 value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Person3() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Person3 value)  $default,){
final _that = this;
switch (_that) {
case _Person3():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Person3 value)?  $default,){
final _that = this;
switch (_that) {
case _Person3() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  int age)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Person3() when $default != null:
return $default(_that.name,_that.age);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  int age)  $default,) {final _that = this;
switch (_that) {
case _Person3():
return $default(_that.name,_that.age);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  int age)?  $default,) {final _that = this;
switch (_that) {
case _Person3() when $default != null:
return $default(_that.name,_that.age);case _:
  return null;

}
}

}

/// @nodoc


class _Person3 implements Person3 {
  const _Person3(this.name, this.age);
  

@override final  String name;
@override final  int age;

/// Create a copy of Person3
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$Person3CopyWith<_Person3> get copyWith => __$Person3CopyWithImpl<_Person3>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Person3&&(identical(other.name, name) || other.name == name)&&(identical(other.age, age) || other.age == age));
}


@override
int get hashCode => Object.hash(runtimeType,name,age);

@override
String toString() {
  return 'Person3(name: $name, age: $age)';
}


}

/// @nodoc
abstract mixin class _$Person3CopyWith<$Res> implements $Person3CopyWith<$Res> {
  factory _$Person3CopyWith(_Person3 value, $Res Function(_Person3) _then) = __$Person3CopyWithImpl;
@override @useResult
$Res call({
 String name, int age
});




}
/// @nodoc
class __$Person3CopyWithImpl<$Res>
    implements _$Person3CopyWith<$Res> {
  __$Person3CopyWithImpl(this._self, this._then);

  final _Person3 _self;
  final $Res Function(_Person3) _then;

/// Create a copy of Person3
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? age = null,}) {
  return _then(_Person3(
null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,null == age ? _self.age : age // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
