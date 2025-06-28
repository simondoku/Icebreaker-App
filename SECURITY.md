# 🔒 Security Setup Instructions

## API Key Configuration

Your `Info.plist` file contains sensitive API keys and should never be committed to the repository.

### Setup Steps:

1. **Copy the template:**

   ```bash
   cp Icebreaker/Icebreaker/Info.plist.template Icebreaker/Icebreaker/Info.plist
   ```

2. **Add your API key:**

   - Open `Icebreaker/Icebreaker/Info.plist`
   - Replace `YOUR_API_KEY_HERE` with your actual DeepSeek API key
   - Save the file

3. **The file is already in .gitignore** so it won't be committed

### For Team Members:

When setting up the project:

1. Clone the repository
2. Copy `Info.plist.template` to `Info.plist`
3. Add your own API key to the `Info.plist` file
4. Never commit the `Info.plist` file with real API keys

## Other Sensitive Files Protected:

- `GoogleService-Info.plist` (Firebase configuration)
- `Info.plist` (API keys)
- `.env` files
- Any `.key` or `.secret` files
