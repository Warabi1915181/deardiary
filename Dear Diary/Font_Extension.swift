//
//  Font_Extension.swift
//  Dear Diary
//
//  Created by Ho Ting Cheung on 01/05/2026.
//

import SwiftUI

// Handwritten typography, "drawn on paper":
// - Patrick Hand: neat everyday handwriting — body text, labels, metadata.
// - Caveat: looser, quicker hand — titles and emphasis.
// - Dancing Script: flourish — big numbers and rare script accents.
//
// Caveat draws small for its point size; sized roles that map to it
// scale up so call sites can keep thinking in familiar point sizes.
extension Font {
  private static let caveatScale: CGFloat = 1.2

  static let regular = Font.custom("PatrickHand-Regular", size: 17)
  static let regularItalic = Font.custom("Caveat-Medium", size: 17 * caveatScale)
  static let bold = Font.custom("Caveat-Bold", size: 17 * caveatScale)
  static let fancy = Font.custom("DancingScript-Regular", size: 17)

  static func regular(size: CGFloat = 17) -> Font {
    return Font.custom("PatrickHand-Regular", size: size)
  }
  static func regularItalic(size: CGFloat = 17) -> Font {
    return Font.custom("Caveat-Medium", size: size * caveatScale)
  }
  static func bold(size: CGFloat = 17) -> Font {
    return Font.custom("Caveat-Bold", size: size * caveatScale)
  }
  static func fancy(size: CGFloat = 17) -> Font {
    return Font.custom("DancingScript-Regular", size: size)
  }
}
