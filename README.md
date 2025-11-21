# PakScape

PakScape is a simple Quake `.pak` and `.pk3` archive viewer inspired by PakScape and originally developed by Peter Engström. It renders the archive directory tree, lets you add/remove files, and export modified archives.

## Building

Use Xcode (macOS) to open `PakScape.xcodeproj` and build the project. There is also a [GitHub Actions workflow](.github/workflows/build.yml) that compiles the app on `macos-latest` and uploads a release artifact.

## Allowing PakScape to Run on macOS

If you downloaded `PakScape.app` from the internet and macOS prevents it from launching, restore execution permissions and remove the quarantine flag with the following steps:

1. Open Terminal (Applications → Utilities) so you can type commands against the `.app` bundle.
2. Drag `PakScape.app` (or the folder that contains it) into the Terminal window so the path is inserted automatically, or type the path directly.
3. Make the app executable:

   ```bash
   sudo chmod +x /path/to/PakScape.app
   ```

4. Clear the quarantine attribute that may block launch:

   ```bash
   sudo xattr -r -d com.apple.quarantine /path/to/PakScape.app
   ```

After running those commands you should be able to open PakScape without further warnings.

## License

The project follows the same licenses as the original tools it is based on.
