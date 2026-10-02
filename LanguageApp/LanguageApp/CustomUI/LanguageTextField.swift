//
//  LanguageTextField.swift
//  LanguageApp
//
//  Text field that opens the keyboard of the language being learned (e.g. Japanese while typing
//  a Japanese word), if the learner has that keyboard installed. iOS only lets an app pick among
//  the keyboards enabled in Settings ▸ General ▸ Keyboard ▸ Keyboards.
//

import SwiftUI
import UIKit

struct LanguageTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    /// BCP-47 locale of the language being typed, e.g. "ja-JP" (the course's speech locale).
    let locale: String
    @Binding var isFocused: Bool
    var isEnabled = true
    var font: UIFont = UIFont(name: "Nunito-SemiBold", size: 20) ?? .systemFont(ofSize: 20, weight: .semibold)
    var textColor: UIColor = .label
    var onSubmit: (() -> Void)?

    func makeUIView(context: Context) -> KeyboardLanguageTextField {
        let field = KeyboardLanguageTextField()
        field.delegate = context.coordinator
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.returnKeyType = .done
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: KeyboardLanguageTextField, context: Context) {
        context.coordinator.parent = self
        // Don't overwrite marked (not yet committed) text of Japanese / Chinese / Korean input.
        if field.text != text, field.markedTextRange == nil {
            field.text = text
        }
        field.placeholder = placeholder
        field.font = font
        field.textColor = textColor
        field.isEnabled = isEnabled
        field.languageLocale = locale

        if isFocused, isEnabled, !field.isFirstResponder {
            DispatchQueue.main.async { field.becomeFirstResponder() }
        } else if (!isFocused || !isEnabled), field.isFirstResponder {
            DispatchQueue.main.async { field.resignFirstResponder() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: LanguageTextField

        init(parent: LanguageTextField) { self.parent = parent }

        @objc func textChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.isFocused { parent.isFocused = true }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.isFocused { parent.isFocused = false }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit?()
            return false
        }
    }
}

/// `UITextField` whose keyboard is the installed keyboard matching `languageLocale`.
final class KeyboardLanguageTextField: UITextField {
    var languageLocale: String? {
        didSet {
            guard oldValue != languageLocale, isFirstResponder else { return }
            reloadInputViews()
        }
    }

    override var textInputMode: UITextInputMode? {
        if let locale = languageLocale, let mode = Self.installedInputMode(for: locale) {
            return mode
        }
        return super.textInputMode
    }

    /// Installed keyboard for a locale: exact match ("ja-JP"), then same language ("zh-CN" → "zh-Hans").
    static func installedInputMode(for locale: String) -> UITextInputMode? {
        let wanted = locale.lowercased()
        let language = String(wanted.prefix(while: { $0 != "-" && $0 != "_" }))
        let modes = UITextInputMode.activeInputModes
        return modes.first { $0.primaryLanguage?.lowercased() == wanted }
            ?? modes.first { mode in
                guard let primary = mode.primaryLanguage?.lowercased() else { return false }
                return primary == language || primary.hasPrefix(language + "-")
            }
    }

    static func hasKeyboard(for locale: String) -> Bool {
        installedInputMode(for: locale) != nil
    }
}
