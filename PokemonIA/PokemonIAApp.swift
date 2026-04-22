import SwiftUI

@main
struct PokemonIAApp: App {
    var body: some Scene {
        WindowGroup {
            PokemonListViewFactory.make()
        }
    }
}
