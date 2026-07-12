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

  // Semantic type roles. Call sites name the role, never a raw size, so the
  // scale stays a system instead of a per-view guess.
  // Point-size scale (as call sites reason about it): 14 · 16 · 18 · 20 · 24 · 40 · 48.
  //   body cluster  — metadata / body / bodyEmphasis
  //   titles        — cardTitle / entryTitle
  //   display       — displayNumber / screenTitle
  static let metadata = regular(size: 14) // dates, captions, footnotes
  static let body = regular(size: 16) // default body copy
  static let bodyEmphasis = regular(size: 18) // lead body line
  static let sectionHeader = regular(size: 20) // list section / category name
  static let cardTitle = bold(size: 20) // card header label
  static let cardTitleCompact = bold(size: 14) // card header at accessibility sizes
  static let entryTitle = bold(size: 24) // memory / entry title, list context
  static let entryTitleLarge = regularItalic(size: 40) // memory title, detail screen
  static let displayNumber = fancy(size: 40) // large focal number
  static let screenTitle = regularItalic(size: 48) // screen / nav header
}
