# API Key Setup Guide

This project uses a secure method to store the X.AI API key that allows you to commit to GitHub without exposing your secret.

## Quick Setup

1. **Copy the example file:**
   ```bash
   cp Secrets.xcconfig.example Secrets.xcconfig
   ```

2. **Edit `Secrets.xcconfig` and add your actual API key:**
   ```
   XAI_API_KEY = xai-your-actual-api-key-here
   ```

3. **Add the xcconfig file to your Xcode project:**
   - Open Xcode
   - Right-click on the project root in the navigator
   - Select "Add Files to ChristmasWishlist..."
   - Select `Secrets.xcconfig`
   - Make sure "Copy items if needed" is **UNCHECKED** (file should stay at root)
   - Click "Add"

4. **Link the xcconfig file to your build configurations:**
   - Select the project in the navigator (top "ChristmasWishlist" item)
   - Select the "ChristmasWishlist" target
   - Go to the "Info" tab
   - Under "Configurations", expand "Debug"
   - Click the dropdown next to "ChristmasWishlist" and select "Secrets.xcconfig"
   - Do the same for "Release"
   - Do the same for "ChristmasWishlistTests" Debug and Release
   - Do the same for "ChristmasWishlistUITests" Debug and Release

5. **Verify it's working:**
   - Build and run the app
   - Check the console - you should see: `XAIService: Found API key in Info.plist`
   - Try pasting a product URL - the title should be cleaned by AI

## How It Works

- `Secrets.xcconfig` is in `.gitignore` - it will never be committed to GitHub
- `Secrets.xcconfig.example` is committed - it's a template for other developers
- `Info.plist` uses `$(XAI_API_KEY)` which gets the value from the xcconfig file
- The API key is injected at build time, not stored in source code

## Backup Your API Key

Since `Secrets.xcconfig` is gitignored, make sure to:
- Keep a backup of your API key in a secure password manager
- Or store it in a private backup location
- The file is safe to include in Time Machine backups (it's just ignored by git)

## Troubleshooting

If the API key isn't working:
1. Make sure `Secrets.xcconfig` exists (not just the .example file)
2. Verify the xcconfig is linked in all build configurations
3. Clean build folder (Cmd+Shift+K) and rebuild
4. Check console logs for API key detection messages




