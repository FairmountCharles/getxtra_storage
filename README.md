# getxtra_storage

> A modern, community-maintained continuation of GetStorage for the GetXtra ecosystem.

## Overview

`getxtra_storage` consolidates the work of the original `get_storage` project and subsequent WASM-compatible forks into a single package aligned with the modern `getxtra` ecosystem.

The goal is simple:

- Preserve the familiar GetStorage API.
- Support modern Flutter and Dart releases.
- Incorporate WebAssembly-compatible web improvements.
- Eliminate dependency chains that require maintaining multiple forks.
- Provide a stable migration path for existing GetStorage applications.

---

## Why getxtra_storage Exists

`getxtra_storage` was not originally planned as a standalone project.

Like many Flutter developers, we found ourselves maintaining a growing chain of local patches simply to remain compatible with modern Flutter SDKs and web targets.

### The Dependency Chain Problem

Historically, the storage ecosystem looked something like:

```text
get_storage_wasm
        │
        ▼
   get_storage
        │
        ▼
       get
```

As Flutter evolved, incompatibilities began appearing throughout the stack.

In particular, newer Flutter SDK releases introduced breaking changes that affected GetX itself. Fixing those issues locally solved the immediate problem, but exposed a second issue: `get_storage` depended on the published `get` package, not the patched version.

The chain continued:

1. Patch GetX locally.
2. Point GetStorage at the patched GetX.
3. Patch GetStorage locally.
4. Point GetStorage WASM at the patched GetStorage.
5. Maintain multiple interconnected forks.

At some point, maintaining several tightly-coupled forks became more complicated than maintaining a single coherent storage package.

### The WASM Opportunity

The excellent `get_storage_wasm` project introduced WebAssembly compatibility improvements and modernized portions of the original web implementation.

Rather than choosing between:

- Original `get_storage`
- WASM-compatible forks
- Local compatibility patches

we consolidated the work into a single package.

### The Goal

`getxtra_storage` exists to provide:

- A storage package aligned with the GetXtra ecosystem.
- Compatibility with modern Flutter and Dart releases.
- Consolidated WebAssembly improvements.
- Continued support for mobile, desktop, and web platforms.
- A familiar API for existing GetStorage users.

### Lineage

```text
Original Lineage

get
 └── get_storage
      └── get_storage_wasm


Modern Consolidation

getxtra
 └── getxtra_storage
```

---

## Acknowledgements

Special thanks to:

- Jonatas Borges and the GetX/GetStorage contributors.
- The GetStorage community.
- lcw99 for WebAssembly compatibility work.
- Everyone who maintained local patches and compatibility forks along the way.

`getxtra_storage` should be viewed as a continuation of that work rather than a replacement for it.

---

## Features

- Fast in-memory key/value storage.
- Persistent disk-backed storage.
- Browser localStorage support.
- WebAssembly-friendly web implementation.
- Named storage containers.
- Change listeners.
- Key-specific listeners.
- ReadWriteValue persistent property helpers.
- Android, iOS, macOS, Windows, Linux, and Web support.

---

## Installation

```yaml
dependencies:
  getxtra_storage:
    git:
      url: https://github.com/FairmountCharles/getxtra_storage.git
```

---

## Basic Usage

```dart
await GetStorage.init();

final box = GetStorage();

await box.write('username', 'john');

print(box.read('username'));
```

### Remove Data

```dart
await box.remove('username');
```

### Erase Container

```dart
await box.erase();
```

### Listen For Changes

```dart
final dispose = box.listen(() {
  print('Storage changed');
});

dispose();
```

### Listen To A Specific Key

```dart
box.listenKey('username', (value) {
  print(value);
});
```

---

## ReadWriteValue Helpers

```dart
final username = ''.val('username');

username.val = 'john.doe';

print(username.val);
```

---

## Platform Support

| Platform | Status |
|-----------|----------|
| Android | Supported |
| iOS | Supported |
| macOS | Supported |
| Windows | Supported |
| Linux | Supported |
| Web | Supported |
| WebAssembly | Supported / In Progress |

---

## Migration From get_storage

### Before

```dart
import 'package:get_storage/get_storage.dart';
```

### After

```dart
import 'package:getxtra_storage/getxtra_storage.dart';
```

If your application already uses standard GetStorage APIs, migration should be straightforward.

---

## Roadmap

- Complete GetXtra dependency migration.
- Preserve GetStorage API compatibility.
- Continue modernizing web and WASM support.
- Improve storage durability and recovery.
- Expand automated test coverage.
- Publish stable releases.

---

## Community

Issues, pull requests, testing, bug reports, and migration feedback are welcome.

The long-term success of `getxtra_storage` depends on community participation.
