# Patch Boot Script Documentation

This script is designed to extract and patch the boot image using a provided OTA zip and patched kernel.

## Usage
```bash
./patch-boot.sh <path_to_ota_zip> <path_to_patched_kernel_zip> [workdir]
```

### Arguments
- `<path_to_ota_zip>`: Path to the OTA zip file.
- `<path_to_patched_kernel_zip>`: Path to the zip file containing the patched kernel. (Anykernel3)
- `[workdir]`: Optional. Specify a directory to store all output files and use for relative paths. Defaults to the current directory.

### Steps Performed
1. Extract `payload.bin` from the OTA zip.
2. Extract images from `payload.bin`.
3. Extract `Image` from the patched kernel zip.
4. Replace the kernel in `boot.img` with the patched `Image`.
5. Repack the `boot.img` to create `new-boot.img`.

### Output
- `new-boot.img`: The patched boot image ready for use.

### Notes
- Ensure all required dependencies (`payload-dumper-go`, `magiskboot`) are installed and available in your PATH.
- Use the `WORKDIR` environment variable to override the default working directory for all output files.

### Example
```bash
./patch-boot.sh factory-ota.zip patched-kernel.zip path/to/workdir
```