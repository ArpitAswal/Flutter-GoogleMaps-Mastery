/// Typed result union returned by all repository methods.
/// Cubits pattern-match on this; raw exceptions never escape the repository layer.
sealed class MapResult<T> {
  const MapResult();
}

final class MapSuccess<T> extends MapResult<T> {
  final T data;
  const MapSuccess(this.data);
}

final class MapFailure<T> extends MapResult<T> {
  final String message;
  const MapFailure(this.message);
}
