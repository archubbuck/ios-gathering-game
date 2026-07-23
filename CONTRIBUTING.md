# Contributing

Thanks for considering contributing to iOS Full-Stack Starter!

## How to contribute

1. Fork the repository
2. Create a feature branch: `git checkout -b my-feature`
3. Make your changes
4. Run `npm run lint && npm run typecheck` to verify the backend
5. Open the `.swiftpm` in Swift Playgrounds or Xcode to verify the iOS app builds
6. Commit with a descriptive message
7. Push and open a pull request

## Guidelines

- Keep the template minimal — features should be general enough to be useful across different kinds of iOS apps
- Follow existing patterns: `lib/*.ts` for backend helpers, `ViewModels/` for ObservableObjects, `Views/` for SwiftUI
- All API routes must be auth-protected via `requireAuth` unless explicitly public
- Database changes must include a migration in `migrations/`
