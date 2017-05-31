# AsyncNinja Design Guidelines

## API Design Guidelines

Use original [API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)

## Code Style

Enforced by [SwiftLint](https://github.com/realm/SwiftLint)

## Versioning

Use semantic version with caveats.

`SWIFT_MAJOR.SWIFT_MINOR.ASYNCNINJA_PATCH`

| version component  |backward incompatible changes|
|--------------------|-----------------------------|
| `SWIFT_MAJOR `     | allowed                     |
| `SWIFT_MINOR `     | discouraged                 |
| `ASYNCNINJA_PATCH` | denied                      |

## Documentation

* At least 99% of public interfaces

## Test

* At least 60% of code coverage
