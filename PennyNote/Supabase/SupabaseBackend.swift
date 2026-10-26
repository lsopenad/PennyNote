import Foundation
import Supabase

// Cliente de Supabase de la app. La URL y la anon key llegan al Info.plist desde
// Config/Supabase.xcconfig; si faltan, client es nil y la app muestra cómo configurarlo.
enum SupabaseBackend {
    static let client: SupabaseClient? = {
        guard let configuration = Configuration(bundle: .main) else { return nil }
        return SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.anonKey,
            options: SupabaseClientOptions(
                // La sesión guardada vale aunque esté caducada: la app funciona sin red y el SDK la
                // renueva en cuanto vuelve la conexión.
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }()

    struct Configuration {
        let url: URL
        let anonKey: String

        init?(bundle: Bundle) {
            let urlText = (bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String ?? "")
                .trimmingCharacters(in: .whitespaces)
            let anonKey = (bundle.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String ?? "")
                .trimmingCharacters(in: .whitespaces)

            // Un "https://..." escrito tal cual en el .xcconfig llega cortado en "https:", porque
            // "//" empieza un comentario: hay que escribirlo como https:/$()/...
            guard
                let url = URL(string: urlText),
                url.scheme == "https",
                url.host?.isEmpty == false,
                !anonKey.isEmpty
            else {
                Log.auth.error("Falta la configuración de Supabase o no es válida (SUPABASE_URL / SUPABASE_ANON_KEY en Config/Supabase.xcconfig)")
                return nil
            }
            self.url = url
            self.anonKey = anonKey
        }
    }
}
