import SwiftUI

// Bascule de langue in-app (FR/EN). Réactif : les vues qui affichent du texte
// observent `Loc.shared` et se redessinent au changement.
// ponytail: traductions colocalisées au point d'appel via s(en, fr) — pas de
// String Catalog ni de swap de Bundle (qui exigerait un redémarrage). Passer à
// un .xcstrings si le nombre de langues dépasse 2.
@MainActor
final class Loc: ObservableObject {
    static let shared = Loc()

    @Published var lang: String {
        didSet { UserDefaults.standard.set(lang, forKey: "cubby.lang") }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "cubby.lang") {
            lang = saved
        } else {
            lang = Locale.current.language.languageCode?.identifier == "fr" ? "fr" : "en"
        }
    }

    func s(_ en: String, _ fr: String) -> String { lang == "fr" ? fr : en }
}
