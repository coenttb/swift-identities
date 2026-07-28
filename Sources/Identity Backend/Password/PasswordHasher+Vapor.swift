import Vapor

//
//  PasswordHasher+Vapor.swift
//  swift-identities
//
//  Vapor implementation of PasswordHasher using Bcrypt
//

#if canImport(Vapor)
    import Dependencies
    import Vapor

    extension PasswordHasher {
        /// Live implementation using Vapor's Bcrypt on a thread pool
        ///
        /// Bcrypt work runs on `NIOThreadPool.singleton` so async contexts are never
        /// blocked — and so hashing needs no `\.application` dependency. The previous
        /// form read the Vapor Application purely for its thread pool, which made the
        /// hasher unresolvable in scope-less phases (the Identity Backend migrator's
        /// DEBUG seed runs during the app's hoisted pre-scope migration and tripped
        /// the loud Witness test-fallback diagnostic on `VaporApplicationKey`).
        ///
        /// This is automatically used when the Vapor trait is enabled in Package.swift.
        public static var vapor: Self {
            Self(
                hash: { password, cost in
                    try await NIOThreadPool.singleton.runIfActive {
                        try Bcrypt.hash(password, cost: cost)
                    }
                },
                verify: { password, hash in
                    try await NIOThreadPool.singleton.runIfActive {
                        try Bcrypt.verify(password, created: hash)
                    }
                }
            )
        }
    }

    extension PasswordHasher: Dependency.Key {
        public static let liveValue: PasswordHasher = .vapor
    }
#endif
