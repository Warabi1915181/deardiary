//
//  Font_Extension.swift
//  Dear Diary
//
//  Created by Ho Ting Cheung on 01/05/2026.
//

import SwiftUI

extension Font {
  static let regular = Font.custom("PlayfairDisplay-Regular", size: 16)
  static let bold = Font.custom("PlayfairDisplay-Bold", size: 16)
  static let fancy = Font.custom("GreatVibes-Regular", size: 16)
	static func regular(size: CGFloat = 16) -> Font {
		return Font.custom("PlayfairDisplay-Regular", size: size)
	}
	static func bold(size: CGFloat = 16) -> Font {
		return Font.custom("PlayfairDisplay-Bold", size: size)
	}
	static func fancy(size: CGFloat = 16) -> Font {
		return Font.custom("GreatVibes-Regular", size: size)
	}
}
