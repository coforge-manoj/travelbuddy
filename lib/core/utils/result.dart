import 'package:ai_travel_assistant/core/errors/failures.dart';

/// A lightweight Either-style wrapper so use cases and repositories can
/// return either a success value or a [Failure] without throwing exceptions
/// across layer boundaries.
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(Failure failure) = ResultFailure<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is ResultFailure<T>;

  T? get valueOrNull => switch (this) {
        Success<T>(value: final v) => v,
        ResultFailure<T>() => null,
      };

  Failure? get failureOrNull => switch (this) {
        Success<T>() => null,
        ResultFailure<T>(failure: final f) => f,
      };

  R fold<R>(R Function(Failure failure) onFailure, R Function(T value) onSuccess) {
    return switch (this) {
      Success<T>(value: final v) => onSuccess(v),
      ResultFailure<T>(failure: final f) => onFailure(f),
    };
  }
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class ResultFailure<T> extends Result<T> {
  const ResultFailure(this.failure);
  final Failure failure;
}

/// Transforms a successful [Result]'s value while passing failures through
/// untouched — the workhorse for converting data-layer models to domain
/// entities inside repository implementations.
extension ResultMapping<T> on Result<T> {
  Result<R> map<R>(R Function(T value) transform) {
    return fold(
      (failure) => Result<R>.failure(failure),
      (value) => Result<R>.success(transform(value)),
    );
  }
}
