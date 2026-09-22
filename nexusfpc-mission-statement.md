# NexusFPC Mission Statement

## Purpose

NexusFPC is a focused downstream distribution of Free Pascal.

Its purpose is not to replace Free Pascal, compete with it, or create a separate Pascal ecosystem. Its purpose is to narrow the enormous surface area of the upstream compiler and libraries to the platforms and use cases Nexus actually intends to support, so those targets can be understood deeply, tested comprehensively, maintained efficiently, and released quickly and reliably.

Free Pascal has accumulated decades of platform support, compatibility layers, libraries, packages, back ends, and historical targets. That breadth is one of its great accomplishments. It reflects an enormous amount of engineering by generations of Free Pascal contributors, including work on architectures, operating systems, runtimes, code generators, linkers, package ecosystems, and targets that few other compilers have ever attempted to support.

NexusFPC deliberately makes a different tradeoff.

It supports a smaller, explicitly defined set of modern targets. Code, packages, compatibility layers, platform implementations, and toolchain machinery that have no meaningful role in that supported set may be removed. Reducing that surface area allows the remaining compiler, RTL, libraries, build machinery, and tests to receive substantially more focused attention.

The goal is not maximum compatibility or maximum target count.

The goal is an excellent, dependable, maintainable Pascal toolchain for modern Nexus application development.

A tool that attempts to serve every possible use case can become too broad to make any one of them exceptional. NexusFPC instead concentrates its engineering effort on a smaller audience and a smaller set of targets, with the intent that the resulting toolchain become genuinely dependable and essential for the people whose needs it serves.

## Supported Targets

The following are currently supported.

| Platform | CPUs to retain |
|---|---|
| Windows desktop | x86-64, ARM64 |
| Windows Server | x86-64 |
| Linux desktop/server | x86-64, ARM64 |
| macOS | ARM64 and Intel x86-64 |
| Android | ARM64; x86-64 for emulator testing |
| iPhone/iPad | ARM64 |
| iOS Simulator | ARM64, x86-64 |

## Relationship to Free Pascal

NexusFPC remains downstream of Free Pascal by design.

General compiler improvements, optimizer fixes, RTL fixes, language corrections, and broadly useful features should be contributed to upstream Free Pascal whenever practical. NexusFPC should inherit those improvements through normal synchronization rather than becoming a competing development center.

In general:

```text
General FPC bug, fix, or feature
    → contribute upstream to Free Pascal

NexusFPC pruning, release, integration, or reduced-tree issue
    → contribute to NexusFPC
```

NexusFPC exists to curate, narrow, test, and release a focused subset of FPC—not to fragment FPC development.

The fact that NexusFPC removes a target or subsystem is not a judgment that the removed work was poor, obsolete in every context, or unworthy of preservation. Some of the code removed from NexusFPC represents remarkably ambitious compiler engineering. The JVM target is an obvious example: Pascal targeting the JVM is technically interesting and reflects substantial work by the developers who created and maintained it. It is simply not part of the problem NexusFPC intends to solve.

That distinction matters.

NexusFPC removes things because they are outside its mission, not because they lack value.

## Compatibility Philosophy

Nexus will not depend on NexusFPC-specific language features, ABI changes, proprietary behavior, or other changes that force developers to use NexusFPC.

A developer who needs a platform, target, package, or compatibility feature intentionally omitted from NexusFPC should remain free to use upstream Free Pascal or another compatible FPC toolchain.

For packages specifically, upstream FPC contains many useful packages that are inappropriate for inclusion in the NexusFPC core distribution. Packages near the upper edge of usefulness for Nexus may instead be imported into a Nexus-specific package repository, where their inclusion is an explicit decision and they can be analyzed, maintained, tested, and updated independently.

Where practical, imported packages will remain current with relevant upstream development. Their continued inclusion will not be assumed merely because they historically shipped with FPC; each package must justify its place on its own merits and against the alternatives available to Nexus.

NexusFPC may change defaults, remove unsupported targets, retire obsolete compatibility paths, simplify maintenance, replace internal machinery with stronger external tooling, and adopt useful upstream development features as part of its supported baseline. Those decisions should improve the focused Nexus toolchain without making Nexus source needlessly dependent on a private compiler dialect.

## Scope

NexusFPC will prioritize the platforms, CPUs, runtime facilities, packages, and toolchain components that materially support modern Nexus development.

Code that exists only to support obsolete, irrelevant, historical, or unsupported environments may be removed when doing so reduces maintenance burden and simplifies the remaining system.

Interesting technology is not sufficient reason for inclusion.

A subsystem can be clever, mature, useful to other developers, or historically important and still be outside the NexusFPC mission. NexusFPC is not intended to preserve every capability Free Pascal has accumulated. Upstream Free Pascal remains the proper home for that breadth.

The goal is a compiler distribution small enough to understand, test comprehensively, maintain confidently, evolve deliberately, and release quickly.

## Maintenance Model

NexusFPC will periodically synchronize with upstream Free Pascal and selectively retain changes relevant to the Nexus-supported surface.

As NexusFPC becomes more focused, upstream remains an important source of compiler engineering, bug fixes, optimizer improvements, platform work, RTL development, and new ideas.

NexusFPC should minimize unnecessary divergence so useful upstream work can continue to flow downstream naturally.

Where mature external tooling provides a stronger long-term implementation than NexusFPC maintaining equivalent infrastructure itself, NexusFPC may prefer the external tool rather than preserving internal machinery solely because it already exists. Such decisions should reduce ownership and maintenance burden without compromising the supported toolchain.

## Community

NexusFPC should strengthen, not weaken, the broader Free Pascal ecosystem.

The breadth that NexusFPC deliberately avoids remains valuable in upstream Free Pascal. The developers who built and continue to maintain that breadth have made possible an unusually capable Pascal ecosystem, and NexusFPC directly benefits from their work.

Developers who discover Free Pascal through Nexus may become FPC users or contributors. Bugs found through Nexus may produce fixes useful to upstream FPC. Contributors working on general-purpose compiler improvements should be encouraged to submit them upstream first.

A healthy relationship looks like:

```text
Free Pascal
    broad upstream compiler
        ↓
NexusFPC
    focused, curated, tested downstream
        ↓
Nexus developers and users
        ↓
general fixes and improvements
        ↖ upstream Free Pascal
```

NexusFPC should be proud of its Free Pascal ancestry while being equally clear that it serves a narrower purpose.

## Mission

> **NexusFPC exists to provide a focused, modern, rapidly maintainable Free Pascal toolchain for Nexus while remaining compatible with and supportive of the broader Free Pascal ecosystem.**
>
> **We narrow the problem so we can understand it deeply, test it thoroughly, maintain it quickly, and release it confidently. We preserve upstream breadth by respecting where it belongs rather than carrying all of it downstream.**
>
> **We do not remove things because they are bad. We remove things because they are not ours to own.**
