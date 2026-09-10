import SwiftUI

enum AppTheme {
    /// Tasarımdaki koyu lacivert (başlıklar, logo, birincil butonlar)
    static let navy = Color(red: 0.043, green: 0.180, blue: 0.388)      // #0B2E63

    /// Tasarımdaki canlı mavi (aktif sekme, vurgular)
    static let primary = Color(red: 0.031, green: 0.239, blue: 0.569)   // #083D91

    /// Ekran arka planı (çok açık mavimsi gri)
    static let background = Color(red: 0.965, green: 0.969, blue: 0.984) // #F6F7FB

    /// Kart arka planı (beyaz)
    static let card = Color.white

    /// Input alanlarının arka planı (açık gri-mavi)
    static let inputBackground = Color(red: 0.929, green: 0.937, blue: 0.965) // #EDEFF6
}
