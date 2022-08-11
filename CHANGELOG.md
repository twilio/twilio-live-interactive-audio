# 1.1.1 (In progress)

- Updated the default media extension (as listed in [.env.example](.env.example)) to use version 2 of the Audio Mixer. See the Audio Mixer's [changelog](https://www.twilio.com/docs/live/audio-mixer-changelog) for more information.

# 1.1.0 (May 27, 2022)

- Use Swift Package Manager instead of CocoaPods to manage dependencies for the iOS app. Xcode will install dependencies automatically instead of having to run `pod install`.
- Add `npm run remove` command so that customers have an easy way to reset the deploy and start over if they run into issues. See the [readme](https://github.com/twilio/twilio-live-interactive-audio#deploy-the-app-to-twilio) for more info.
