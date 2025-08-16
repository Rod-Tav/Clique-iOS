//
//  ExpandableText.swift
//  Clique
//
//  Created by Rod Tavangar on 12/11/24.
//

import SwiftUI

struct ExpandableText: View {
    @State private var currentLineLimit: Int?
    @State private var isTruncated: Bool = false
    @State private var isExpanded: Bool = false
    
    private var text: AttributedString
    private var initialLineLimit: Int
    
    init(_ text: String, lineLimit: Int = 2) {
        self.text = AttributedString(text)
        self.initialLineLimit = lineLimit
        self._currentLineLimit = State(initialValue: lineLimit)
    }
    
    init(_ text: AttributedString, lineLimit: Int = 3) {
        self.text = text
        self.initialLineLimit = lineLimit
        self._currentLineLimit = State(initialValue: lineLimit)
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(text)
                .lineLimit(currentLineLimit)
//                .truncated(text, $isTruncated)
                .onTapGesture { toggleExpanded() }
            
            if isTruncated || isExpanded {
                Group {
                    if isExpanded { // to prevent animation
                        Button("less") {
                            toggleExpanded()
                        }
                    } else {
                        Button("more") {
                            toggleExpanded()
                        }
                    }
                }
                .font(.caption2)
                .foregroundStyle(Color.theme.textSecondary)
            }
        }
    }
    
    private func toggleExpanded() {
        guard isTruncated || isExpanded else { return }
        self.currentLineLimit = self.isTruncated ? nil : initialLineLimit
        isExpanded.toggle()
    }
}

struct TruncatedViewModifier: ViewModifier {
  let text: AttributedString
  @Binding var isTruncated: Bool

  func body(content: Content) -> some View {
    content
      .background(
        ViewThatFits(in: .vertical) {
          Text(self.text)
            .hidden()
            .preference(key: TruncatedPreferenceKey.self, value: false)
          Color.clear
            .preference(key: TruncatedPreferenceKey.self, value: true)
        }
      )
      .onPreferenceChange(TruncatedPreferenceKey.self) { isTruncated in
        self.isTruncated = isTruncated
      }
  }

  struct TruncatedPreferenceKey: PreferenceKey {
    static var defaultValue: Bool = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
      value = nextValue()
    }
  }
}

extension View {
  func truncated(_ text: AttributedString, _ isTruncated: Binding<Bool>) -> some View {
    ModifiedContent(
      content: self,
      modifier: TruncatedViewModifier(text: text, isTruncated: isTruncated)
    )
  }
}
