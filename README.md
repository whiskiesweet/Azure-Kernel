## Build

<table>
<tr>
<td width="64" align="center"><img src="https://llvm.org/img/LLVMWyvernSmall.png" width="40"/></td>
<td><b>LLVM / Clang</b> — 19 & 22<br/><sub>The compiler stack behind every build — <code>clang</code>, <code>ld.lld</code>, <code>llvm-ar</code>, and the rest of the LLVM toolchain that turns kernel source into a working <code>Image</code>.</sub></td>
</tr>
<tr>
<td width="64" align="center"><img src="https://resukisu.github.io/logo.svg" width="40"/></td>
<td><b>ReSuKiSU</b><br/><sub>The primary root manager here — a KernelSU fork built for stability, with optional KPM support when you need it.</sub></td>
</tr>
<tr>
<td width="64" align="center"><img src="https://github.com/KernelSU-Next/KernelSU-Next/blob/dev/assets/kernelsu_next.png?raw=true" width="40"/></td>
<td><b>KernelSU Next</b><br/><sub>A lighter alternative when you don't need KPM — same kernel-based root foundation, fewer moving parts.</sub></td>
</tr>
<tr>
<td width="64" align="center">🛡️</td>
<td><b>SUSFS</b> <code>v2.2.0</code><br/><sub>Keeps root invisible to apps that go looking for it, running quietly alongside whichever root manager you pick.</sub></td>
</tr>
<tr>
<td width="64" align="center">📦</td>
<td><b>AnyKernel3</b><br/><sub>Takes the finished kernel image and wraps it into a ZIP your recovery can actually flash — no manual repacking required.</sub></td>
</tr>
<tr>
<td width="64" align="center">⚙️</td>
<td><b>GitHub Actions</b><br/><sub>Runs the whole pipeline end to end on <code>ubuntu-latest</code>, triggered whenever you fire off <code>workflow_dispatch</code>.</sub></td>
</tr>
</table>

<br/>

## Matrix Build

| Variant | CLANG-19 | CLANG-22 | SUSFS
|---|---|---|--|
| **KSUN** | ✅ | ✅ | ✅|
| **ReSuKiSU** | ✅ | ✅ | ✅|
| **VNL** | ✅ | ✅ | ❌|

<br/>

## Credits

- [**ramabondanp**](https://github.com/ramabondanp) — Source Kernel
- [**LLVM Project**](https://llvm.org) — Toolchain Clang/LLVM
- [**tiann**](https://github.com/tiann/KernelSU) — KernelSU Manager
- [**KernelSU-Next**](https://github.com/KernelSU-Next/KernelSU-Next) Team — KernelSU-Next Manager
- [**ReSuKiSU**](https://github.com/ReSukiSU/ReSukiSU) Team —  ReSuKiSU Manager
- [**simonpunk**](https://gitlab.com/simonpunk/susfs4ksu) — Patch SUSFS
- [**osm0sis**](https://github.com/osm0sis/AnyKernel3) — Template Packaging AnyKernel3

<br/>

---

<div align="center">
  <sub>Made with Love </sub>
</div>
