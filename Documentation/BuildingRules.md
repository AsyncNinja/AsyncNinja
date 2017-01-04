# AsyncNinja Building Rules

## API Design Guidelines

Use original [API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)

## Code Style

Use [code style guide](https://github.com/raywenderlich/swift-style-guide)

## Versioning

Use semantic version with caveats.

`SWIFT_MAJOR.SWIFT_MINOR.ASYNCNINJA_PATCH`

| version component  |backward incompatible changes|
|--------------------|-----------------------------|
| `SWIFT_MAJOR `     | allowed                     |
| `SWIFT_MINOR `     | discouraged                 |
| `ASYNCNINJA_PATCH` | denied                      |

The current version is prerelease `0.x.x`. This means that backward compatibility can be broken much oftener but backward compatibility will be kept through patches of the same minor version.

## Documentation

At least 90% of public interfaces

## Test

* At least 60% of code coverage
