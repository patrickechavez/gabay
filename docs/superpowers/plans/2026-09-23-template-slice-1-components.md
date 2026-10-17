# Template Slice 1: Shared Components Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the ios-app-template's reusable form components into Gabay and rebuild `SignInView`, `SignUpView` and `PostEventView` on them, closing the events-platform spec's unmet requirement for inline per-field validation.

**Architecture:** The components are pure SwiftUI views that take their error text as a plain `String?` input. All validation logic lives in the existing `@Observable @MainActor` view models as computed properties, so views stay logic-free and the validation is unit-testable without a UI test. The components draw their own label, border and error text, which is incompatible with `Form`/`Section` chrome, so the three screens move to the template's `ScrollView` + `VStack` layout.

**Tech Stack:** SwiftUI, Swift 6 strict concurrency, Swift Testing (`import Testing`), no new third-party dependencies.

**Source of the port:** `/Users/patrick/Projects/AppTemplate` on branch `supabase`. The reference screen for the target idiom is `AppTemplate/Features/Auth/RegisterView/RegisterView.swift` and its `RegisterViewModel.swift`.

## Global Constraints

- **No em dashes** anywhere: not in plan text, code, comments, commit messages or user-facing copy. Use a comma or a period instead. The template's `DateField.swift` contains one em dash in a comment; this plan already rewrites that comment, so port the version printed here and not the template's original bytes.
- **Never run `xcodebuild` or `xcrun simctl`.** The user runs all builds and tests personally. Write the code, report what should be run, and stop. Do not attempt to verify by building.
- **Swift 6 strict concurrency must be satisfied honestly, not silenced.** No new `@unchecked Sendable`, `nonisolated(unsafe)`, force unwraps or `fatalError` unless justified in the commit message. Nothing in this slice should need any of them.
- **Never edit `Gabay.xcodeproj/project.pbxproj`.** Files under `Gabay/` and `GabayTests/` are auto-included by `PBXFileSystemSynchronizedRootGroup`. Creating a file is enough; editing the project file to register it is wrong and will corrupt the group.
- **Never hand-edit `Gabay/Resources/Localizable.xcstrings`.** Xcode regenerates it from `String(localized:comment:)` and `Text(_:comment:)` call sites at build time. The user's working tree may already contain regenerated entries; leave that file alone entirely.
- **Check for basename and type-name collisions before naming any new file or type.** Two source files sharing a basename in one target risk object-file collisions. Every name this plan introduces was checked against the whole of `Gabay/` and `GabayTests/` on 2026-09-23 and had zero matches, so follow the names given here exactly rather than inventing new ones.
- **Views hold no logic.** Anything conditional beyond simple presentation belongs on the view model as a computed property.
- **Every user-facing string is localized**, via `Text("...", comment: "...")` in views or `String(localized: "...", comment: "...")` in view models. This is why several ported strings differ from the template's, which hardcodes some button titles.
- **No tests for pure UI views.** Test view model computed properties and pure value types. Do not add snapshot or UI tests.

## Scope

**In:** `FieldContainer`, `AppTextField`, `InlineErrorText`, `AsyncButton`, `EmailField`, `PasswordField`, `DateField`, `DateFormat`, `AlertState`, `AlertButton`, `appAlert`, a `String.isValidEmail` helper, and the rebuild of the three screens plus the validation properties on their view models.

**Deliberately out, with reasons:**

- **`PickerField` and `SelectionSheet`.** No field on any of the three screens is a choice from a fixed list, so porting them now would add an unused component. They come with the first screen that needs one.
- **`AlertState.confirmDestructive`.** No consumer in this slice. Port `AlertState` without it.
- **`PhoneField`, `UsernameField`, `SearchField`, `ImagePicker`, `EnvironmentRibbon`, `PrivacyShieldView`, `OfflineBanner`.** Not part of this slice. `OfflineBanner` belongs to Slice 5.
- **`ActionState` and server-supplied per-field messages.** The template's view models read field errors off `APIError.validationErrors` through `ActionState.message(for:)`. `APIError` does not gain `validationErrors` until Slice 2, so every field error in this slice is a local rule. Do not reach for `ActionState`; it does not exist in Gabay yet.
- **`ErrorStateView` and `LoadFailure`.** Untouched. The three screens keep their existing per-screen failure copy rather than deriving text from `LoadFailure`, which is what they do today, so no duplicate mapping is introduced.

## When an error is allowed to appear

This is the one design rule the whole slice hangs on, taken from the template's `RegisterViewModel`:

**An empty field never shows an inline error.** Every local validation rule guards with `!field.isEmpty` first. A required field that is empty communicates through two things already: the red `*` that `FieldContainer` renders, and the submit button being disabled. Telling a user "Title is required" before they have typed anything is hostile, and avoiding it means no focus or "touched" tracking is needed anywhere.

**An inline error therefore means "what you typed is not usable",** never "you have not typed yet". That restricts errors to fields with a format rule: the email address, the password length, the fee, the capacity, and the two links. Title, cause, meeting point and description are required-but-unformatted, so they get `isRequired: true` and no `error:` argument at all. A reviewer should expect that asymmetry rather than flag it.

**Sign-in validates nothing locally.** A format rule on the sign-in email would gate `canSubmit`, and a false negative from a hand-written validator would lock a user out of their own account over an unusual but legal address. Sign-in requires both fields non-empty and lets the server be the judge. `SignInView` adopts the components for consistency and keyboard and autofill behavior, not for validation.

## File Structure

**New files:**

| File | Responsibility |
| --- | --- |
| `Gabay/Components/FieldContainer.swift` | The label, border and error row every field sits inside. Owns the entire visual contract for a field. |
| `Gabay/Components/AppTextField.swift` | `AppTextField` (the general text input), plus `InlineErrorText` (a whole-form error line) and `AsyncButton` (a submit button that shows a spinner). Kept in one file to match the template. |
| `Gabay/Components/EmailField.swift` | `AppTextField` preset for email: keyboard, autocapitalization, autofill. |
| `Gabay/Components/PasswordField.swift` | Secure entry with a reveal toggle. |
| `Gabay/Components/DateFormat.swift` | The date patterns `DateField` can render, and which picker each one implies. Pure value type, unit tested. |
| `Gabay/Components/DateField.swift` | Tap-to-open calendar sheet over an optional `Date` binding. |
| `Gabay/Components/Alert/AlertState.swift` | `AlertState`, `AlertButton` and the `appAlert(_:)` view modifier. |
| `Gabay/Core/Validation/EmailValidation.swift` | `String.isValidEmail`. Domain logic used by view models, so it sits under `Core/`, not with the views. Unit tested. |
| `GabayTests/DateFormatTests.swift` | Covers pattern strings and picker-component inference. |
| `GabayTests/EmailValidationTests.swift` | Covers `isValidEmail`. |
| `GabayTests/SignUpViewModelTests.swift` | Covers the sign-up field errors and `canSubmit`. |

**Modified files:**

| File | Change |
| --- | --- |
| `Gabay/Features/Auth/SignInView.swift` | `SignInViewModel` gains `signInErrorMessage` and clears `failure` on each attempt; `SignInView` rebuilt on the components. |
| `Gabay/Features/Auth/SignUpView.swift` | `SignUpViewModel` gains `emailError` and `passwordError` and gates `canSubmit` on email validity; `SignUpView` rebuilt on the components. |
| `Gabay/Core/Events/PostEventViewModel.swift` | `date` becomes `Date?`; gains five error properties and an `alert` property. |
| `Gabay/Features/Events/PostEventView.swift` | Rebuilt on the components. |
| `GabayTests/PostEventViewModelTests.swift` | `makeValidViewModel` must set the now-optional `date`; new tests for the field errors. |

---

### Task 1: Field primitives and email validation

Ports the four components that everything else depends on, plus the email rule. Nothing consumes them yet, so this task cannot break an existing screen.

**Files:**
- Create: `Gabay/Components/FieldContainer.swift`
- Create: `Gabay/Components/AppTextField.swift`
- Create: `Gabay/Components/EmailField.swift`
- Create: `Gabay/Components/PasswordField.swift`
- Create: `Gabay/Core/Validation/EmailValidation.swift`
- Test: `GabayTests/EmailValidationTests.swift`

**Interfaces:**
- Consumes: `Theme` from `Gabay/DesignSystem/Theme.swift`. Every token used here (`Theme.Spacing.xs/sm/md/lg`, `Theme.Radius.md`, `Theme.Color.danger/separator/secondaryText/primaryText`, `Theme.Font.fieldLabel/fieldError/secondary`, `Theme.Animation.content`) already exists. Do not add tokens.
- Produces, relied on by Tasks 4, 5 and 6:
  - `FieldContainer<Content: View>(label: String?, isRequired: Bool, error: String?, content: () -> Content)`
  - `AppTextField(text: Binding<String>, placeholder: String = "", label: String? = nil, error: String? = nil, isRequired: Bool = false, keyboard: UIKeyboardType = .default, capitalization: TextInputAutocapitalization = .sentences, contentType: UITextContentType? = nil, disableAutocorrection: Bool = false, submitLabel: SubmitLabel = .return)`
  - `InlineErrorText(_ message: String)`
  - `AsyncButton(title: Text, isRunning: Bool, action: @Sendable () async -> Void, role: ButtonRole? = nil)`
  - `EmailField(text: Binding<String>, label: String? = <localized "Email">, error: String? = nil, isRequired: Bool = false)`
  - `PasswordField(text: Binding<String>, label: String? = <localized "Password">, error: String? = nil, isRequired: Bool = false, isNewPassword: Bool = false)`
  - `String.isValidEmail: Bool`

**Note on argument order:** these are memberwise initializers, so Swift requires labeled arguments in declaration order even when earlier defaulted parameters are omitted. Tasks 4 to 6 call them in exactly the order listed above. Do not reorder the stored properties.

- [ ] **Step 1: Write the failing test for email validation**

Create `GabayTests/EmailValidationTests.swift`:

```swift
//
//  EmailValidationTests.swift
//  GabayTests
//

import Testing
@testable import Gabay

struct EmailValidationTests {

    @Test func acceptsAnOrdinaryAddress() {
        #expect("hiker@example.com".isValidEmail)
    }

    @Test func acceptsASubdomain() {
        #expect("organizer@mail.example.co.uk".isValidEmail)
    }

    @Test func rejectsAnEmptyString() {
        #expect("".isValidEmail == false)
    }

    @Test func rejectsAnAddressWithNoAtSign() {
        #expect("hiker.example.com".isValidEmail == false)
    }

    @Test func rejectsAnAddressWithTwoAtSigns() {
        #expect("hiker@example@com".isValidEmail == false)
    }

    @Test func rejectsAnEmptyLocalPart() {
        #expect("@example.com".isValidEmail == false)
    }

    @Test func rejectsADomainWithNoDot() {
        #expect("hiker@example".isValidEmail == false)
    }

    @Test func rejectsADomainThatStartsOrEndsWithADot() {
        #expect("hiker@.example.com".isValidEmail == false)
        #expect("hiker@example.com.".isValidEmail == false)
    }

    @Test func rejectsADomainWithConsecutiveDots() {
        #expect("hiker@example..com".isValidEmail == false)
    }

    @Test func rejectsAnAddressContainingASpace() {
        #expect("hiker @example.com".isValidEmail == false)
    }

    @Test func rejectsAnAddressLongerThanTheRFCLimit() {
        let local = String(repeating: "a", count: 250)
        #expect("\(local)@example.com".isValidEmail == false)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Do not run it yourself. Record in your report that the user should run:

```
xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone SE (2nd generation)' -only-testing:GabayTests/EmailValidationTests
```

Expected at this point: the `GabayTests` target fails to compile with "value of type 'String' has no member 'isValidEmail'".

- [ ] **Step 3: Implement the email rule**

Create `Gabay/Core/Validation/EmailValidation.swift`:

```swift
//
//  EmailValidation.swift
//  Gabay
//

import Foundation

extension String {

    // Deliberately loose. The server is the real authority on whether an
    // address exists; this only catches the typos worth catching before a
    // round trip, without rejecting an unusual but legal address.
    var isValidEmail: Bool {
        guard !isEmpty, !contains(" "), count <= 254 else { return false }

        let parts = split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }

        let domain = parts[1]
        return domain.contains(".")
            && !domain.hasPrefix(".")
            && !domain.hasSuffix(".")
            && !domain.contains("..")
    }
}
```

- [ ] **Step 4: Create the field container**

Create `Gabay/Components/FieldContainer.swift`:

```swift
//
//  FieldContainer.swift
//  Gabay
//

import SwiftUI

// The label, box and error message every text field sits inside.
struct FieldContainer<Content: View>: View {
    let label: String?
    let isRequired: Bool
    let error: String?
    @ViewBuilder let content: () -> Content

    private var hasError: Bool { !(error ?? "").isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if let label {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(label)
                    if isRequired { Text("*").foregroundStyle(Theme.Color.danger) }
                }
                .font(Theme.Font.fieldLabel)
                .foregroundStyle(Theme.Color.secondaryText)
            }

            HStack(spacing: Theme.Spacing.sm) {
                content()
                if isRequired && label == nil {
                    Text("*").foregroundStyle(Theme.Color.danger)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(
                        hasError ? Theme.Color.danger : Theme.Color.separator,
                        lineWidth: 1
                    )
            )

            if hasError, let error {
                Text(error)
                    .font(Theme.Font.fieldError)
                    .foregroundStyle(Theme.Color.danger)
            }
        }
    }
}
```

- [ ] **Step 5: Create the text field, inline error and async button**

Create `Gabay/Components/AppTextField.swift`:

```swift
//
//  AppTextField.swift
//  Gabay
//

import SwiftUI
import UIKit

struct AppTextField: View {

    @Binding var text: String

    var placeholder: String = ""
    var label: String?
    var error: String?
    var isRequired: Bool = false

    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .sentences
    var contentType: UITextContentType?
    var disableAutocorrection: Bool = false
    var submitLabel: SubmitLabel = .return

    var body: some View {
        FieldContainer(label: label, isRequired: isRequired, error: error) {
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(capitalization)
                .textContentType(contentType)
                .autocorrectionDisabled(disableAutocorrection)
                .submitLabel(submitLabel)
                .accessibilityLabel(label.map(Text.init) ?? Text(placeholder))
        }
    }
}

// A failure that belongs to the whole form rather than to one field.
struct InlineErrorText: View {

    private let message: String

    init(_ message: String) {
        self.message = message
    }

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(Theme.Font.secondary)
            .foregroundStyle(Theme.Color.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isStaticText)
    }
}

struct AsyncButton: View {

    let title: Text
    let isRunning: Bool
    let action: @Sendable () async -> Void

    var role: ButtonRole?

    var body: some View {
        Button(role: role) {
            Task { await action() }
        } label: {

            ZStack {
                title.opacity(isRunning ? 0 : 1)
                if isRunning {
                    ProgressView()
                        .tint(.white)
                        .controlSize(.regular)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isRunning)
        .animation(Theme.Animation.content, value: isRunning)
        .accessibilityAddTraits(isRunning ? .updatesFrequently : [])
    }
}
```

- [ ] **Step 6: Create the email and password presets**

Create `Gabay/Components/EmailField.swift`:

```swift
//
//  EmailField.swift
//  Gabay
//

import SwiftUI
import UIKit

// Text field preset for email: email keyboard, no autocapitalization, autofill.
struct EmailField: View {

    @Binding var text: String

    var label: String? = String(localized: "Email", comment: "Label for the email field")
    var error: String?
    var isRequired: Bool = false

    var body: some View {
        AppTextField(
            text: $text,
            placeholder: String(localized: "name@example.com", comment: "Placeholder for the email field"),
            label: label,
            error: error,
            isRequired: isRequired,
            keyboard: .emailAddress,
            capitalization: .never,
            contentType: .emailAddress,
            disableAutocorrection: true
        )
    }
}
```

Create `Gabay/Components/PasswordField.swift`:

```swift
//
//  PasswordField.swift
//  Gabay
//

import SwiftUI
import UIKit

// Password field with a reveal button; set isNewPassword when signing up.
struct PasswordField: View {

    @Binding var text: String

    var label: String? = String(localized: "Password", comment: "Label for the password field")
    var error: String?
    var isRequired: Bool = false
    var isNewPassword: Bool = false
    @State private var isRevealed = false
    @FocusState private var isFocused: Bool

    var body: some View {
        FieldContainer(label: label, isRequired: isRequired, error: error) {
            Group {
                if isRevealed {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(isNewPassword ? .newPassword : .password)
            .focused($isFocused)
            .accessibilityLabel(label.map(Text.init) ?? Text(placeholder))

            Button {
                isRevealed.toggle()
                // Swapping SecureField for TextField rebuilds the view and
                // drops focus, so put the caret back where the user left it.
                isFocused = true
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(Theme.Color.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                isRevealed
                    ? Text("Hide password", comment: "Accessibility label for the password reveal toggle")
                    : Text("Show password", comment: "Accessibility label for the password reveal toggle")
            )
        }
    }

    private var placeholder: String {
        String(localized: "Password", comment: "Placeholder for the password field")
    }
}
```

- [ ] **Step 7: Report the verification command**

Record in your report that the user should run:

```
xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone SE (2nd generation)' -only-testing:GabayTests/EmailValidationTests
```

Expected: 11 tests pass. Do not run it.

- [ ] **Step 8: Commit**

```bash
git add Gabay/Components Gabay/Core/Validation GabayTests/EmailValidationTests.swift
git commit -m "Add the shared field components and the email rule"
```

---

### Task 2: Date field

`PostEventView` needs a required date that starts unset, which is what `DateField`'s optional binding is for. `DateFormat` is a hard dependency of `DateField` and comes with it.

**Files:**
- Create: `Gabay/Components/DateFormat.swift`
- Create: `Gabay/Components/DateField.swift`
- Test: `GabayTests/DateFormatTests.swift`

**Interfaces:**
- Consumes: `FieldContainer` from Task 1, `Theme` tokens `Theme.Spacing.xs/lg`, `Theme.Color.tertiaryText/primaryText/secondaryText`.
- Produces, relied on by Task 6:
  - `DateFormat` enum with `.monthDayYearTime12` and `.custom(String)` among its cases, plus `var pattern: String` and `var components: DatePicker.Components`.
  - `DateField(label: String, date: Binding<Date?>, format: DateFormat = .monthDayYear, placeholder: String = <localized "Select">, error: String? = nil, isRequired: Bool = false, isEnabled: Bool = true, range: ClosedRange<Date>? = nil)`. This one has an explicit `init`, so the parameter order above is the call order.

- [ ] **Step 1: Write the failing test for DateFormat**

Create `GabayTests/DateFormatTests.swift`:

```swift
//
//  DateFormatTests.swift
//  GabayTests
//

import SwiftUI
import Testing
@testable import Gabay

struct DateFormatTests {

    @Test func aDateOnlyFormatAsksForADatePicker() {
        #expect(DateFormat.monthDayYear.components == .date)
        #expect(DateFormat.abbreviated.components == .date)
    }

    @Test func aTimeOnlyFormatAsksForATimePicker() {
        #expect(DateFormat.time12.components == .hourAndMinute)
        #expect(DateFormat.time24.components == .hourAndMinute)
    }

    @Test func aCombinedFormatAsksForBoth() {
        #expect(DateFormat.monthDayYearTime12.components == [.date, .hourAndMinute])
        #expect(DateFormat.isoDateTime.components == [.date, .hourAndMinute])
    }

    @Test func aCustomPatternIsReadToDecideThePicker() {
        #expect(DateFormat.custom("yyyy-MM-dd").components == .date)
        #expect(DateFormat.custom("HH:mm").components == .hourAndMinute)
        #expect(DateFormat.custom("yyyy-MM-dd HH:mm").components == [.date, .hourAndMinute])
    }

    @Test func quotedTextInACustomPatternIsNotReadAsAField() {
        // The "T" and the "at" are literal text, not hour or minute fields.
        #expect(DateFormat.custom("yyyy-MM-dd'T'").components == .date)
        #expect(DateFormat.custom("MMMM d 'at' h:mm a").components == [.date, .hourAndMinute])
    }

    @Test func aCustomPatternCarriesItsOwnPattern() {
        #expect(DateFormat.custom("dd/MM").pattern == "dd/MM")
    }

    @Test func theBuiltInPatternsAreTheDocumentedOnes() {
        #expect(DateFormat.monthDayYear.pattern == "MM/dd/yyyy")
        #expect(DateFormat.iso.pattern == "yyyy-MM-dd")
        #expect(DateFormat.monthDayYearTime12.pattern == "MM/dd/yyyy h:mm a")
    }
}
```

- [ ] **Step 2: Report that the test should fail**

Do not run it. Record that the user should run:

```
xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone SE (2nd generation)' -only-testing:GabayTests/DateFormatTests
```

Expected at this point: compile failure, "cannot find 'DateFormat' in scope".

- [ ] **Step 3: Create DateFormat**

Create `Gabay/Components/DateFormat.swift`:

```swift
//
//  DateFormat.swift
//  Gabay
//

import SwiftUI

// Patterns DateField can render; use .custom for anything not listed.
enum DateFormat: Hashable, Sendable {

    // Numeric dates
    case monthDayYear           // 04/23/1998
    case dayMonthYear           // 23/04/1998
    case yearMonthDay           // 1998/04/23
    case dotted                 // 23.04.1998
    case iso                    // 1998-04-23
    case shortMonthDayYear      // 04/23/98

    // Written dates
    case abbreviated            // Apr 23, 1998
    case full                   // April 23, 1998
    case dayFirstAbbreviated    // 23 Apr 1998
    case withWeekday            // Thu, Apr 23, 1998
    case fullWithWeekday        // Thursday, April 23, 1998
    case monthYear              // April 1998

    // Date and time
    case monthDayYearTime12     // 04/23/1998 5:30 PM
    case monthDayYearTime24     // 04/23/1998 17:30
    case isoDateTime            // 1998-04-23 17:30
    case iso8601                // 1998-04-23T17:30:00+0000

    // Time only
    case time12                 // 5:30 PM
    case time24                 // 17:30
    case time24WithSeconds      // 17:30:45

    case custom(String)

    var pattern: String {
        switch self {
        case .monthDayYear: "MM/dd/yyyy"
        case .dayMonthYear: "dd/MM/yyyy"
        case .yearMonthDay: "yyyy/MM/dd"
        case .dotted: "dd.MM.yyyy"
        case .iso: "yyyy-MM-dd"
        case .shortMonthDayYear: "MM/dd/yy"
        case .abbreviated: "MMM d, yyyy"
        case .full: "MMMM d, yyyy"
        case .dayFirstAbbreviated: "d MMM yyyy"
        case .withWeekday: "EEE, MMM d, yyyy"
        case .fullWithWeekday: "EEEE, MMMM d, yyyy"
        case .monthYear: "MMMM yyyy"
        case .monthDayYearTime12: "MM/dd/yyyy h:mm a"
        case .monthDayYearTime24: "MM/dd/yyyy HH:mm"
        case .isoDateTime: "yyyy-MM-dd HH:mm"
        case .iso8601: "yyyy-MM-dd'T'HH:mm:ssZ"
        case .time12: "h:mm a"
        case .time24: "HH:mm"
        case .time24WithSeconds: "HH:mm:ss"
        case let .custom(pattern): pattern
        }
    }

    // A format that prints a time has to let the user choose one.
    var components: DatePicker.Components {
        switch self {
        case .time12, .time24, .time24WithSeconds:
            .hourAndMinute
        case .monthDayYearTime12, .monthDayYearTime24, .isoDateTime, .iso8601:
            [.date, .hourAndMinute]
        case let .custom(pattern):
            Self.components(inferredFrom: pattern)
        default:
            .date
        }
    }

    // A custom pattern has to be read to know which picker to show.
    private static func components(inferredFrom pattern: String) -> DatePicker.Components {
        // Anything inside quotes is literal text, not a field.
        let fields = pattern.split(separator: "'", omittingEmptySubsequences: false)
            .enumerated()
            .filter { $0.offset.isMultiple(of: 2) }
            .map(\.element)
            .joined()

        let hasDate = fields.contains { "yYMdDEL".contains($0) }
        let hasTime = fields.contains { "hHmsa".contains($0) }

        return switch (hasDate, hasTime) {
        case (true, true): [.date, .hourAndMinute]
        case (false, true): .hourAndMinute
        default: .date
        }
    }
}
```

- [ ] **Step 4: Create DateField**

Create `Gabay/Components/DateField.swift`. Note the comment on the locale line: the template's original uses an em dash there, and this version does not. Use this version.

```swift
//
//  DateField.swift
//  Gabay
//

import SwiftUI

// Tap to open a calendar sheet; the optional binding allows a placeholder.
struct DateField: View {

    let label: String

    @Binding var date: Date?

    var placeholder: String
    var error: String?
    var isRequired: Bool = false
    var isEnabled: Bool = true

    // Limits the selectable dates when set.
    var range: ClosedRange<Date>?

    private let format: DateFormat
    private let formatter: DateFormatter

    @State private var isPresented = false

    init(
        label: String,
        date: Binding<Date?>,
        format: DateFormat = .monthDayYear,
        placeholder: String = String(localized: "Select", comment: "Placeholder for a date field"),
        error: String? = nil,
        isRequired: Bool = false,
        isEnabled: Bool = true,
        range: ClosedRange<Date>? = nil
    ) {
        self.label = label
        _date = date
        self.format = format
        self.placeholder = placeholder
        self.error = error
        self.isRequired = isRequired
        self.isEnabled = isEnabled
        self.range = range

        let formatter = DateFormatter()
        formatter.dateFormat = format.pattern
        // Current locale, not POSIX, so month and weekday names stay localized.
        formatter.locale = Locale.current
        self.formatter = formatter
    }

    var body: some View {
        FieldContainer(label: label, isRequired: isRequired, error: error) {
            Button {
                isPresented = true
            } label: {
                HStack {
                    Text(date.map(formatter.string(from:)) ?? placeholder)
                        .foregroundStyle(
                            date == nil ? Theme.Color.tertiaryText : Theme.Color.primaryText
                        )

                    Spacer()

                    Image(systemName: format.components == .hourAndMinute ? "clock" : "calendar")
                        .font(.footnote)
                        .foregroundStyle(Theme.Color.secondaryText)
                }
                // Spacer() is not hit-testable, so give the whole row a shape to tap.
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
            .accessibilityLabel(Text(label))
        }
        .sheet(isPresented: $isPresented) {
            DateSheet(title: label, date: $date, components: format.components, range: range)
        }
    }
}

// Kept file-private: nothing outside DateField presents it.
private struct DateSheet: View {

    let title: String
    @Binding var date: Date?
    var components: DatePicker.Components
    var range: ClosedRange<Date>?

    // Edits stay local until Done, so Cancel leaves the binding untouched.
    @State private var selection: Date
    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        date: Binding<Date?>,
        components: DatePicker.Components = .date,
        range: ClosedRange<Date>? = nil
    ) {
        self.title = title
        _date = date
        self.components = components
        self.range = range
        _selection = State(wrappedValue: date.wrappedValue ?? Date())
    }

    var body: some View {
        NavigationStack {
            VStack {
                styledPicker
                    .labelsHidden()

                Spacer()
            }
            .padding(Theme.Spacing.lg)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Text("Cancel", comment: "Dismisses the date picker without choosing")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        date = selection
                        dismiss()
                    } label: {
                        Text("Done", comment: "Confirms the chosen date")
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    // The calendar grid has nothing to show when only a time is wanted.
    @ViewBuilder
    private var styledPicker: some View {
        if components == .hourAndMinute {
            picker.datePickerStyle(.wheel)
        } else {
            picker.datePickerStyle(.graphical)
        }
    }

    @ViewBuilder
    private var picker: some View {
        if let range {
            DatePicker("", selection: $selection, in: range, displayedComponents: components)
        } else {
            DatePicker("", selection: $selection, displayedComponents: components)
        }
    }
}
```

- [ ] **Step 5: Report the verification command**

Record that the user should run:

```
xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone SE (2nd generation)' -only-testing:GabayTests/DateFormatTests
```

Expected: 7 tests pass. Do not run it.

- [ ] **Step 6: Commit**

```bash
git add Gabay/Components/DateFormat.swift Gabay/Components/DateField.swift GabayTests/DateFormatTests.swift
git commit -m "Add the date field component"
```

---

### Task 3: Alert state

**Files:**
- Create: `Gabay/Components/Alert/AlertState.swift`

**Interfaces:**
- Produces, relied on by Task 6:
  - `AlertState(title: String, message: String? = nil, buttons: [AlertButton])`
  - `AlertState.notice(_ title: String, _ message: String? = nil) -> AlertState`
  - `AlertButton(title: String, role: ButtonRole? = nil, action: () -> Void = {})`
  - `View.appAlert(_ state: Binding<AlertState?>) -> some View`

**No test.** This is a presentation value type whose only behavior is handing its buttons to SwiftUI's `alert`. A test asserting that `notice` produces one button titled "OK" would restate the implementation rather than check anything.

**Two deliberate differences from the template**, both of which a reviewer should expect:

1. The factory is named `notice`, not `error`. Gabay's first consumer is the "Submitted" confirmation on the organizer form, and `AlertState.error("Submitted", ...)` would read as the opposite of what it does. The template's `confirmDestructive` factory is not ported at all, since nothing in this slice confirms a destructive action.
2. The button title is localized. The template hardcodes `"OK"`; Gabay localizes every user-facing string.

- [ ] **Step 1: Create the alert state**

Create `Gabay/Components/Alert/AlertState.swift`:

```swift
//
//  AlertState.swift
//  Gabay
//

import SwiftUI

// An alert a view model can raise without knowing anything about SwiftUI's
// presentation machinery. Setting it to nil dismisses.
struct AlertState: Identifiable {
    let id = UUID()
    let title: String
    var message: String?
    var buttons: [AlertButton]

    // One button that only dismisses. Covers both a confirmation and a
    // failure, which is why it is not called `error`.
    static func notice(_ title: String, _ message: String? = nil) -> AlertState {
        AlertState(
            title: title,
            message: message,
            buttons: [AlertButton(title: String(localized: "OK", comment: "Dismisses an alert"))]
        )
    }
}

struct AlertButton: Identifiable {
    let id = UUID()
    let title: String
    var role: ButtonRole?
    var action: () -> Void = {}
}

extension View {

    func appAlert(_ state: Binding<AlertState?>) -> some View {
        alert(
            state.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { state.wrappedValue != nil },
                set: { if !$0 { state.wrappedValue = nil } }
            ),
            presenting: state.wrappedValue
        ) { alert in
            ForEach(alert.buttons) { button in
                Button(button.title, role: button.role, action: button.action)
            }
        } message: { alert in
            if let message = alert.message { Text(message) }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Gabay/Components/Alert/AlertState.swift
git commit -m "Add the alert state component"
```

---

### Task 4: Rebuild the sign-in screen

**Files:**
- Modify: `Gabay/Features/Auth/SignInView.swift` (both the view model and the view live in this one file; keep it that way)

**Interfaces:**
- Consumes: `EmailField`, `PasswordField`, `InlineErrorText`, `AsyncButton` from Task 1.
- Produces: `SignInViewModel.signInErrorMessage: String?`. `SignInViewModel.init(session:)` and `SignInView.init(viewModel:makeSignUpViewModel:)` keep their current signatures, so `AppDependencies` and `RootView` need no change. Do not touch them.

**Behavior changes, all intended:**

- The `Form` becomes a `ScrollView` with a `VStack`. The components draw their own labels and borders, so keeping them inside `Form` rows would double the chrome.
- The failure alert becomes an `InlineErrorText` under the fields, matching the template's `generalError` treatment. The copy is unchanged.
- `failure` is cleared at the start of each attempt, so a retry does not show the previous attempt's error while it is running. This is a real fix: today the alert's binding clears `failure` on dismiss, but the inline text has no dismiss step.
- `isShowingFailure` is deleted. Nothing else references it; it existed only to drive the alert.

**No local validation here,** by design. See "When an error is allowed to appear" above: a format rule on this screen would gate `canSubmit` and could lock a user out of a valid account.

- [ ] **Step 1: Replace the file**

Replace the entire contents of `Gabay/Features/Auth/SignInView.swift` with:

```swift
//
//  SignInView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import SwiftUI

@Observable
@MainActor
final class SignInViewModel {

    var email = ""
    var password = ""

    private(set) var isSigningIn = false
    private(set) var failure: LoadFailure?

    @ObservationIgnored private let session: Session

    init(session: Session) {
        self.session = session
    }

    // Sign-in deliberately has no inline field validation. A local rule here
    // would gate canSubmit, and a false negative would lock someone out of
    // their own account over an unusual but legal address. The server decides.
    var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !isSigningIn
    }

    var signInErrorMessage: String? {
        guard let failure, failure.isUserFacing else { return nil }
        return String(
            localized: "Check your email and password, then try again.",
            comment: "Shown when sign-in fails"
        )
    }

    func signIn() async {
        guard canSubmit else { return }

        failure = nil
        isSigningIn = true
        defer { isSigningIn = false }

        do {
            try await session.login(email: email, password: password)
        } catch {
            failure = LoadFailure.classify(error)
        }
    }
}

struct SignInView: View {

    @State private var viewModel: SignInViewModel
    @State private var isShowingSignUp = false

    let makeSignUpViewModel: () -> SignUpViewModel

    init(viewModel: SignInViewModel, makeSignUpViewModel: @escaping () -> SignUpViewModel) {
        _viewModel = State(wrappedValue: viewModel)
        self.makeSignUpViewModel = makeSignUpViewModel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    EmailField(
                        text: $viewModel.email,
                        isRequired: true
                    )

                    PasswordField(
                        text: $viewModel.password,
                        isRequired: true
                    )

                    if let message = viewModel.signInErrorMessage {
                        InlineErrorText(message)
                    }

                    AsyncButton(
                        title: Text("Sign In", comment: "Button that submits the sign-in form"),
                        isRunning: viewModel.isSigningIn,
                        action: { await viewModel.signIn() }
                    )
                    .disabled(!viewModel.canSubmit)
                }
                .padding(Theme.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text("Gabay", comment: "Title of the sign-in screen"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSignUp = true
                    } label: {
                        Text("Sign Up", comment: "Opens the account creation screen")
                    }
                }
            }
            .sheet(isPresented: $isShowingSignUp) {
                SignUpView(viewModel: makeSignUpViewModel())
            }
        }
    }
}
```

- [ ] **Step 2: Confirm nothing else referenced the deleted member**

Run:

```bash
cd /Users/patrick/Projects/Gabay && grep -rn "isShowingFailure" Gabay/Features/Auth GabayTests
```

Expected: no output for `SignInViewModel`. If `SignUpViewModel.isShowingFailure` still matches, that is fine, Task 5 removes it. If anything in `GabayTests` matches for sign-in, stop and report it rather than deleting a test.

- [ ] **Step 3: Report the verification command**

Record that the user should build and run the full suite:

```
xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone SE (2nd generation)'
```

Do not run it.

- [ ] **Step 4: Commit**

```bash
git add Gabay/Features/Auth/SignInView.swift
git commit -m "Rebuild the sign-in screen on the shared components"
```

---

### Task 5: Rebuild the sign-up screen

**Files:**
- Modify: `Gabay/Features/Auth/SignUpView.swift`
- Test: `GabayTests/SignUpViewModelTests.swift` (create)

**Interfaces:**
- Consumes: `EmailField`, `PasswordField`, `InlineErrorText`, `AsyncButton` from Task 1; `String.isValidEmail` from Task 1.
- Produces: `SignUpViewModel.emailError: String?`, `SignUpViewModel.passwordError: String?`, `SignUpViewModel.signUpErrorMessage: String?`. `init(session:)` and `SignUpView.init(viewModel:)` keep their current signatures.

**Behavior changes:**

- `canSubmit` now requires a well-formed email, not merely a non-empty one. This is safe here in a way it is not on sign-in: the account does not exist yet, so a rejected address costs a correction rather than access to an existing account.
- The "At least 8 characters." `Form` footer is replaced by `passwordError`, which says the same thing only when the password is actually too short. The old footer string becomes unused and Xcode will drop it from `Localizable.xcstrings` on the next build; do not edit that file by hand.
- `isShowingFailure` and the failure alert are replaced by `signUpErrorMessage` and `InlineErrorText`.
- `failure` is cleared at the start of each attempt, for the same reason as Task 4.

- [ ] **Step 1: Write the failing tests**

Create `GabayTests/SignUpViewModelTests.swift`:

```swift
//
//  SignUpViewModelTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

@MainActor
struct SignUpViewModelTests {

    private func makeViewModel() -> SignUpViewModel {
        SignUpViewModel(session: Session(auth: StubAuthenticating(), tokenStore: StubTokenStore()))
    }

    @Test func anUntouchedEmailShowsNoError() {
        #expect(makeViewModel().emailError == nil)
    }

    @Test func aMalformedEmailShowsAnError() {
        let viewModel = makeViewModel()
        viewModel.email = "hiker@example"
        #expect(viewModel.emailError != nil)
    }

    @Test func aWellFormedEmailShowsNoError() {
        let viewModel = makeViewModel()
        viewModel.email = "hiker@example.com"
        #expect(viewModel.emailError == nil)
    }

    @Test func anUntouchedPasswordShowsNoError() {
        #expect(makeViewModel().passwordError == nil)
    }

    @Test func aShortPasswordShowsAnError() {
        let viewModel = makeViewModel()
        viewModel.password = "short"
        #expect(viewModel.passwordError != nil)
    }

    @Test func aLongEnoughPasswordShowsNoError() {
        let viewModel = makeViewModel()
        viewModel.password = "longenough"
        #expect(viewModel.passwordError == nil)
    }

    @Test func cannotSubmitAnEmptyForm() {
        #expect(makeViewModel().canSubmit == false)
    }

    @Test func cannotSubmitWithAMalformedEmail() {
        let viewModel = makeViewModel()
        viewModel.email = "hiker@example"
        viewModel.password = "longenough"
        #expect(viewModel.canSubmit == false)
    }

    @Test func cannotSubmitWithAShortPassword() {
        let viewModel = makeViewModel()
        viewModel.email = "hiker@example.com"
        viewModel.password = "short"
        #expect(viewModel.canSubmit == false)
    }

    @Test func canSubmitOnceBothFieldsAreValid() {
        let viewModel = makeViewModel()
        viewModel.email = "hiker@example.com"
        viewModel.password = "longenough"
        #expect(viewModel.canSubmit)
    }
}
```

The `Session` construction above is the same one `GabayTests/SessionTests.swift` already uses: `Session(auth: any Authenticating, tokenStore: any TokenStoring)`, with the `StubAuthenticating` and `StubTokenStore` doubles from `GabayTests/Support/TestDoubles.swift`. Neither double needs configuring here, because these tests never call `register()`; they only read computed properties.

- [ ] **Step 2: Report that the tests should fail**

Do not run them. Record that the user should run:

```
xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone SE (2nd generation)' -only-testing:GabayTests/SignUpViewModelTests
```

Expected at this point: compile failure, "value of type 'SignUpViewModel' has no member 'emailError'".

- [ ] **Step 3: Replace the file**

Replace the entire contents of `Gabay/Features/Auth/SignUpView.swift` with:

```swift
//
//  SignUpView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import SwiftUI

@Observable
@MainActor
final class SignUpViewModel {

    var email = ""
    var password = ""

    private(set) var isRegistering = false
    private(set) var failure: LoadFailure?

    @ObservationIgnored private let session: Session

    // A backend-defined minimum; the form just avoids an obviously-too-short
    // password making a wasted round trip.
    private static let minimumPasswordLength = 8

    init(session: Session) {
        self.session = session
    }

    // An empty field is never an inline error. It shows as the required
    // marker and a disabled button, so only a filled-in field can be wrong.
    var emailError: String? {
        guard !email.isEmpty, !email.trimmed.isValidEmail else { return nil }
        return String(
            localized: "Enter a valid email address.",
            comment: "Validation message shown for a malformed email address"
        )
    }

    var passwordError: String? {
        guard !password.isEmpty, password.count < Self.minimumPasswordLength else { return nil }
        return String(
            localized: "Use at least \(Self.minimumPasswordLength) characters.",
            comment: "Validation message shown when a password is too short"
        )
    }

    var signUpErrorMessage: String? {
        guard let failure, failure.isUserFacing else { return nil }
        return String(localized: "Try again in a moment.", comment: "Shown when sign-up fails")
    }

    var canSubmit: Bool {
        email.trimmed.isValidEmail
            && password.count >= Self.minimumPasswordLength
            && !isRegistering
    }

    func register() async -> Bool {
        guard canSubmit else { return false }

        failure = nil
        isRegistering = true
        defer { isRegistering = false }

        do {
            try await session.register(email: email.trimmed, password: password)
            return true
        } catch {
            failure = LoadFailure.classify(error)
            return false
        }
    }
}

struct SignUpView: View {

    @State private var viewModel: SignUpViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: SignUpViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    EmailField(
                        text: $viewModel.email,
                        error: viewModel.emailError,
                        isRequired: true
                    )

                    PasswordField(
                        text: $viewModel.password,
                        error: viewModel.passwordError,
                        isRequired: true,
                        isNewPassword: true
                    )

                    if let message = viewModel.signUpErrorMessage {
                        InlineErrorText(message)
                    }

                    AsyncButton(
                        title: Text("Create Account", comment: "Button that submits the sign-up form"),
                        isRunning: viewModel.isRegistering,
                        action: {
                            if await viewModel.register() { dismiss() }
                        }
                    )
                    .disabled(!viewModel.canSubmit)
                }
                .padding(Theme.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text("Sign Up", comment: "Title of the account creation screen"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel", comment: "Closes the sign-up screen without creating an account")
                    }
                }
            }
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
```

**On the `trimmed` helper:** `PostEventViewModel.swift` already declares an identical `private extension String { var trimmed: String }`. Both are `private`, so they are file-scoped and do not collide. Do not promote either to internal in this task; if a third copy is ever needed, that is the moment to extract one shared helper.

**On `dismiss()` inside `AsyncButton`:** the action closure is `@Sendable () async -> Void`. `dismiss` is a `DismissAction` captured from the environment and calling it from an async context is valid because the closure body runs on the main actor through the `@MainActor` view model call that precedes it. If the compiler disagrees, wrap the dismissal as `await MainActor.run { dismiss() }` and say so in your report rather than adding `@unchecked Sendable` anywhere.

- [ ] **Step 4: Report the verification command**

Record that the user should run:

```
xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone SE (2nd generation)' -only-testing:GabayTests/SignUpViewModelTests
```

Expected: 10 tests pass. Do not run it.

- [ ] **Step 5: Commit**

```bash
git add Gabay/Features/Auth/SignUpView.swift GabayTests/SignUpViewModelTests.swift
git commit -m "Rebuild the sign-up screen with inline field validation"
```

---

### Task 6: Rebuild the organizer form

The largest task, and the one where inline validation earns its keep: six fields, four of which have a format rule that can fail.

**Files:**
- Modify: `Gabay/Core/Events/PostEventViewModel.swift`
- Modify: `Gabay/Features/Events/PostEventView.swift`
- Modify: `GabayTests/PostEventViewModelTests.swift`

**Interfaces:**
- Consumes: `AppTextField`, `InlineErrorText`, `AsyncButton` from Task 1; `DateField` and `DateFormat` from Task 2; `AlertState` and `appAlert` from Task 3.
- Produces: no new public surface for later tasks. `PostEventViewModel.init(events:parser:)` keeps its signature, so `AppDependencies.makePostEventViewModel()` needs no change. Do not touch it.

**The one breaking change:** `PostEventViewModel.date` changes from `Date` to `Date?`, initialized to `nil`.

This is not cosmetic. Today the field is pre-filled with `Date()`, so an organizer who never touches it silently posts a hike starting at the moment they tapped Submit. An optional with a required marker makes the omission visible and is what `DateField` is built for.

**Two consequences the implementer must handle:**

1. `submit()` must unwrap it. Add `let date` to the existing `guard`.
2. `GabayTests/PostEventViewModelTests.swift` has a `makeValidViewModel()` helper that does not set `date`. Once `date` is optional and required, `canSubmit` returns false and the existing test `canSubmitOnceEveryFieldIsFilledCorrectly` fails, along with every other test built on that helper. Step 1 fixes the helper. Do not skip it and do not weaken `canSubmit` to make the old helper pass.

**Other behavior changes:**

- The GPX parse failure moves from an alert to an `InlineErrorText` inside the Route section, which is the whole point of the slice: a problem with one part of the form is shown where that part is.
- The submit failure moves from an alert to an `InlineErrorText` above the button.
- The "Submitted" confirmation stays an alert, now via `AlertState`, because it is genuinely modal: it reports that the screen's work is finished.
- `isShowingFailure`, `isShowingConfirmation` and `isShowingGPXFailure` are all deleted. `failure`, `didSubmit`, `route` and `gpxError` all stay, because `PostEventViewModelTests` asserts on `gpxError`, `failure` and `route` directly.

- [ ] **Step 1: Fix the test helper and add the new failing tests**

In `GabayTests/PostEventViewModelTests.swift`, add one line to `makeValidViewModel()` so it sets the now-required date. The helper currently ends with `viewModel.eventDescription = ...` followed by `return viewModel`. Insert before the `return`:

```swift
        viewModel.date = Date(timeIntervalSince1970: 1_800_000_000)
```

Then append these tests inside the same `struct PostEventViewModelTests`:

```swift
    @Test func cannotSubmitWithoutADate() {
        let viewModel = makeValidViewModel()
        viewModel.date = nil
        #expect(viewModel.canSubmit == false)
    }

    @Test func anUntouchedFeeShowsNoError() {
        #expect(PostEventViewModel(events: StubEventFetching()).feeError == nil)
    }

    @Test func aNonNumericFeeShowsAnError() {
        let viewModel = makeValidViewModel()
        viewModel.feePHP = "two hundred"
        #expect(viewModel.feeError != nil)
        #expect(viewModel.canSubmit == false)
    }

    @Test func aNumericFeeShowsNoError() {
        let viewModel = makeValidViewModel()
        viewModel.feePHP = "250"
        #expect(viewModel.feeError == nil)
    }

    @Test func aFreeHikeIsAllowed() {
        let viewModel = makeValidViewModel()
        viewModel.feePHP = "0"
        #expect(viewModel.feeError == nil)
        #expect(viewModel.canSubmit)
    }

    @Test func aCapacityOfZeroShowsAnError() {
        let viewModel = makeValidViewModel()
        viewModel.capacity = "0"
        #expect(viewModel.capacityError != nil)
        #expect(viewModel.canSubmit == false)
    }

    @Test func aPositiveCapacityShowsNoError() {
        let viewModel = makeValidViewModel()
        viewModel.capacity = "25"
        #expect(viewModel.capacityError == nil)
    }

    @Test func aJoinLinkWithNoSchemeShowsAnError() {
        let viewModel = makeValidViewModel()
        viewModel.joinURLText = "m.me/pawssionprojectcebu"
        #expect(viewModel.joinURLError != nil)
        #expect(viewModel.canSubmit == false)
    }

    @Test func aFullJoinLinkShowsNoError() {
        let viewModel = makeValidViewModel()
        viewModel.joinURLText = "https://m.me/pawssionprojectcebu"
        #expect(viewModel.joinURLError == nil)
    }

    @Test func anEmptyPhotoLinkShowsNoError() {
        let viewModel = makeValidViewModel()
        viewModel.photoURLText = ""
        #expect(viewModel.photoURLError == nil)
        #expect(viewModel.canSubmit)
    }

    @Test func aPhotoLinkWithNoSchemeShowsAnError() {
        let viewModel = makeValidViewModel()
        viewModel.photoURLText = "example.com/hike.jpg"
        #expect(viewModel.photoURLError != nil)
        #expect(viewModel.canSubmit == false)
    }
```

- [ ] **Step 2: Report that the tests should fail**

Do not run them. Record that the user should run:

```
xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone SE (2nd generation)' -only-testing:GabayTests/PostEventViewModelTests
```

Expected at this point: compile failure, "value of type 'PostEventViewModel' has no member 'feeError'".

- [ ] **Step 3: Update the view model**

Replace the entire contents of `Gabay/Core/Events/PostEventViewModel.swift` with:

```swift
//
//  PostEventViewModel.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation

@Observable
@MainActor
final class PostEventViewModel {

    var title = ""
    var cause = ""
    // Optional and required, rather than defaulted to now. A pre-filled date
    // lets an organizer post a hike starting the instant they tap Submit
    // without ever noticing the field.
    var date: Date?
    var meetingPoint = ""
    var meetingCoordinate: Coordinate?
    var feePHP = ""
    var capacity = ""
    var joinURLText = ""
    var eventDescription = ""
    var photoURLText = ""

    var alert: AlertState?

    private(set) var isSubmitting = false
    private(set) var failure: LoadFailure?
    private(set) var didSubmit = false

    // A GPX is optional. Once picked, it must parse, a bad file blocks
    // only itself, with its own inline error, not the rest of the form.
    private(set) var route: RouteStats?
    private(set) var gpxError: LoadFailure?
    @ObservationIgnored private var gpxFileURL: URL?

    @ObservationIgnored private let events: any EventFetching
    @ObservationIgnored private let parser: GPXParser

    init(events: any EventFetching, parser: GPXParser = GPXParser()) {
        self.events = events
        self.parser = parser
    }

    // Every rule below guards on the field being non-empty first. An empty
    // required field shows as the required marker and a disabled button, so
    // an inline error always means "what you typed is not usable".

    var feeError: String? {
        guard !feePHP.trimmed.isEmpty, Int(feePHP.trimmed) == nil else { return nil }
        return String(
            localized: "Enter the fee as a whole number of pesos.",
            comment: "Validation message shown for a fee that is not a number"
        )
    }

    var capacityError: String? {
        guard !capacity.trimmed.isEmpty, (Int(capacity.trimmed) ?? 0) <= 0 else { return nil }
        return String(
            localized: "Enter how many hikers can join, at least 1.",
            comment: "Validation message shown for a capacity that is not a positive number"
        )
    }

    var joinURLError: String? {
        guard !joinURLText.trimmed.isEmpty, !joinURLText.trimmed.isFullLink else { return nil }
        return String(
            localized: "Enter a full link, starting with https://",
            comment: "Validation message shown for a link with no scheme"
        )
    }

    var photoURLError: String? {
        guard !photoURLText.trimmed.isEmpty, !photoURLText.trimmed.isFullLink else { return nil }
        return String(
            localized: "Enter a full link, starting with https://",
            comment: "Validation message shown for a link with no scheme"
        )
    }

    var gpxErrorMessage: String? {
        guard let gpxError, gpxError.isUserFacing else { return nil }
        return String(
            localized: "That file could not be read. Try a different GPX, or leave the route out, it's optional.",
            comment: "Shown when an attached GPX cannot be parsed"
        )
    }

    var submitErrorMessage: String? {
        guard let failure, failure.isUserFacing else { return nil }
        return String(
            localized: "Check the form and try again.",
            comment: "Shown when posting an event fails"
        )
    }

    // No image upload endpoint exists yet, so a photo is an already-hosted
    // link (the organizer's own upload elsewhere) rather than a picked
    // file, unlike the GPX, which does upload.
    var canSubmit: Bool {
        !isSubmitting
            && !title.trimmed.isEmpty
            && !cause.trimmed.isEmpty
            && date != nil
            && !meetingPoint.trimmed.isEmpty
            && meetingCoordinate != nil
            && !eventDescription.trimmed.isEmpty
            && Int(feePHP.trimmed) != nil
            && (Int(capacity.trimmed) ?? 0) > 0
            && joinURLText.trimmed.isFullLink
            && (photoURLText.trimmed.isEmpty || photoURLText.trimmed.isFullLink)
    }

    func pickGPX(at url: URL) {
        gpxError = nil

        do {
            let data = try Data(contentsOf: url)
            let points = try parser.parse(data).points
            route = RouteStats(points: points)
            gpxFileURL = url
        } catch {
            route = nil
            gpxFileURL = nil
            gpxError = .unavailable
        }
    }

    func removeGPX() {
        route = nil
        gpxFileURL = nil
        gpxError = nil
    }

    func submit() async {
        guard canSubmit,
              let date,
              let fee = Int(feePHP.trimmed),
              let capacity = Int(capacity.trimmed),
              let joinURL = URL(string: joinURLText.trimmed),
              let meetingCoordinate else { return }

        failure = nil
        isSubmitting = true
        defer { isSubmitting = false }

        let draft = EventDraft(
            title: title.trimmed,
            cause: cause.trimmed,
            date: date,
            meetingPoint: meetingPoint.trimmed,
            meetingCoordinate: meetingCoordinate,
            feePHP: fee,
            capacity: capacity,
            joinURL: joinURL,
            description: eventDescription.trimmed,
            photoURL: photoURLText.trimmed.isEmpty ? nil : URL(string: photoURLText.trimmed)
        )

        do {
            let created = try await events.create(draft)

            if let route, let gpxFileURL {
                _ = try await events.uploadGPX(
                    eventID: created.id,
                    fileURL: gpxFileURL,
                    distanceM: Int(route.distanceM),
                    ascentM: route.ascentM.map(Int.init),
                    estimatedMinutes: route.estimatedMinutes
                )
            }

            didSubmit = true
            alert = .notice(
                String(localized: "Submitted", comment: "Title confirming an event was submitted"),
                String(
                    localized: "Your event is pending review before it appears publicly.",
                    comment: "Shown after an organizer submits a new event"
                )
            )
        } catch {
            failure = LoadFailure.classify(error)
        }
    }
}

private extension String {

    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    // A link the app can actually open, not a bare host the organizer typed.
    var isFullLink: Bool { URL(string: self)?.scheme != nil }
}
```

**Note on `isFullLink`:** this replaces three copies of `URL(string: ...)?.scheme != nil` that the old `canSubmit` spelled out inline, and the two link error properties now share it. Both link errors also share the same message, which is correct: the two fields have the same rule, and one string is one translation.

- [ ] **Step 4: Rebuild the view**

Replace the entire contents of `Gabay/Features/Events/PostEventView.swift` with:

```swift
//
//  PostEventView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct PostEventView: View {

    @State var viewModel: PostEventViewModel
    @State private var isPickingLocation = false
    @State private var isPickingGPX = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    basicsSection
                    meetingPointSection
                    registrationSection
                    routeSection
                    photoSection
                    descriptionSection

                    if let message = viewModel.submitErrorMessage {
                        InlineErrorText(message)
                    }

                    AsyncButton(
                        title: Text("Submit for Review",
                                    comment: "Button that submits a new event for moderation"),
                        isRunning: viewModel.isSubmitting,
                        action: { await viewModel.submit() }
                    )
                    .disabled(!viewModel.canSubmit)
                }
                .padding(Theme.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text("Post a Hike", comment: "Title of the organizer event-creation form"))
            .sheet(isPresented: $isPickingLocation) {
                LocationPicker(coordinate: $viewModel.meetingCoordinate)
            }
            .fileImporter(isPresented: $isPickingGPX, allowedContentTypes: [.gpxFile, .xml, .data]) { result in
                if case let .success(url) = result {
                    viewModel.pickGPX(at: url)
                }
            }
            .appAlert($viewModel.alert)
        }
    }

    @ViewBuilder
    private var basicsSection: some View {
        sectionHeader(Text("Basics", comment: "Section header for an event's core details"))

        AppTextField(
            text: $viewModel.title,
            placeholder: String(localized: "Title", comment: "Placeholder for the event title field"),
            label: String(localized: "Title", comment: "Label for the event title field"),
            isRequired: true,
            capitalization: .words
        )

        AppTextField(
            text: $viewModel.cause,
            placeholder: String(localized: "Cause", comment: "Placeholder for the beneficiary/cause field"),
            label: String(localized: "Cause", comment: "Label for the beneficiary/cause field"),
            isRequired: true,
            capitalization: .words
        )

        DateField(
            label: String(localized: "Date", comment: "Label for the event date and time field"),
            date: $viewModel.date,
            format: .monthDayYearTime12,
            isRequired: true
        )
    }

    @ViewBuilder
    private var meetingPointSection: some View {
        sectionHeader(Text("Meeting Point", comment: "Section header for the meeting point label and pin"))

        AppTextField(
            text: $viewModel.meetingPoint,
            placeholder: String(localized: "Meeting point",
                                comment: "Placeholder for the meeting point label field"),
            label: String(localized: "Meeting point", comment: "Label for the meeting point label field"),
            isRequired: true
        )

        Button {
            isPickingLocation = true
        } label: {
            if viewModel.meetingCoordinate != nil {
                Label {
                    Text("Pin set", comment: "Shown once a meeting point pin has been dropped")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
            } else {
                Text("Choose on Map", comment: "Opens the meeting point pin-drop picker")
            }
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private var registrationSection: some View {
        sectionHeader(Text("Registration", comment: "Section header for fee, capacity, and join link"))

        AppTextField(
            text: $viewModel.feePHP,
            placeholder: String(localized: "Fee in pesos",
                                comment: "Placeholder for the registration fee field"),
            label: String(localized: "Fee", comment: "Label for the registration fee field"),
            error: viewModel.feeError,
            isRequired: true,
            keyboard: .numberPad
        )

        AppTextField(
            text: $viewModel.capacity,
            placeholder: String(localized: "Capacity", comment: "Placeholder for the hiker capacity field"),
            label: String(localized: "Capacity", comment: "Label for the hiker capacity field"),
            error: viewModel.capacityError,
            isRequired: true,
            keyboard: .numberPad
        )

        AppTextField(
            text: $viewModel.joinURLText,
            placeholder: String(localized: "https://",
                                comment: "Placeholder for the external join/payment link field"),
            label: String(localized: "Join link", comment: "Label for the external join/payment link field"),
            error: viewModel.joinURLError,
            isRequired: true,
            keyboard: .URL,
            capitalization: .never,
            contentType: .URL,
            disableAutocorrection: true
        )
    }

    @ViewBuilder
    private var routeSection: some View {
        sectionHeader(Text("Route", comment: "Section header for the optional GPX route"))

        if let route = viewModel.route {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Label {
                    Text("Route attached", comment: "Shown once a GPX has been parsed successfully")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }

                Text(routeSummary(route))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(role: .destructive) {
                viewModel.removeGPX()
            } label: {
                Text("Remove Route", comment: "Removes the attached GPX from the form")
            }
            .buttonStyle(.bordered)
        } else {
            Button {
                isPickingGPX = true
            } label: {
                Text("Attach a GPX (Optional)", comment: "Opens the file picker for an optional route")
            }
            .buttonStyle(.bordered)
        }

        if let message = viewModel.gpxErrorMessage {
            InlineErrorText(message)
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        sectionHeader(Text("Photo", comment: "Section header for the optional event photo"))

        AppTextField(
            text: $viewModel.photoURLText,
            placeholder: String(localized: "https:// (optional)",
                                comment: "Placeholder for the optional event photo link field"),
            label: String(localized: "Photo link", comment: "Label for the optional event photo link field"),
            error: viewModel.photoURLError,
            keyboard: .URL,
            capitalization: .never,
            contentType: .URL,
            disableAutocorrection: true
        )

        Text("Link to a photo already hosted somewhere, such as one you've posted elsewhere.",
             comment: "Explains the photo link field, since there's no photo upload yet")
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var descriptionSection: some View {
        sectionHeader(Text("Description", comment: "Section header for the event description"))

        FieldContainer(
            label: String(localized: "Description", comment: "Label for the event description field"),
            isRequired: true,
            error: nil
        ) {
            TextField(
                String(localized: "Description", comment: "Placeholder for the event description field"),
                text: $viewModel.eventDescription,
                axis: .vertical
            )
            .lineLimit(4...8)
        }
    }

    // Section headers are identical everywhere, so they are built once here
    // rather than repeated with their styling at each of the six call sites.
    private func sectionHeader(_ text: Text) -> some View {
        text
            .font(Theme.Font.sectionTitle)
            .foregroundStyle(Theme.Color.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Theme.Spacing.sm)
    }

    private func routeSummary(_ route: RouteStats) -> String {
        let distanceText = Measurement(value: route.distanceM, unit: UnitLength.meters)
            .converted(to: .kilometers)
            .formatted(.measurement(width: .abbreviated, usage: .road))

        var parts = [distanceText]
        if let ascentM = route.ascentM {
            parts.append(Measurement(value: ascentM, unit: UnitLength.meters)
                .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                         numberFormatStyle: .number.precision(.fractionLength(0)))))
        }
        parts.append("~\(route.estimatedMinutes / 60)h \(route.estimatedMinutes % 60)m")
        return parts.joined(separator: " - ")
    }
}

private extension UTType {

    // GPX is not one of Apple's declared types, so the app names it itself.
    // Named `gpxFile`, not `gpx`, to stay clear of any other GPX type
    // declaration elsewhere in the target.
    static let gpxFile = UTType(filenameExtension: "gpx") ?? .xml
}
```

**A note on `routeSummary`:** it is unchanged from the current file, including its "~0h 45m" output for a sub-hour hike and its hardcoded English. That is a known defect, it is duplicated in `EventDetailView`, and it is finding I8 in the architecture audit, already scheduled for Slice 4. Do not fix it here. Fixing one copy would leave the two out of step and make the Slice 4 deduplication harder.

**A note on the description field:** it uses `FieldContainer` directly rather than `AppTextField`, because `AppTextField` has no multi-line axis parameter. Adding one to `AppTextField` for a single call site is the wrong trade; `FieldContainer` is the extension point and this is what it is for.

- [ ] **Step 5: Report the verification command**

Record that the user should run the full suite, since this task touches a shared test helper:

```
xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone SE (2nd generation)'
```

Expected: every existing `PostEventViewModelTests` test still passes, plus the 11 added in Step 1. Do not run it.

- [ ] **Step 6: Commit**

```bash
git add Gabay/Core/Events/PostEventViewModel.swift Gabay/Features/Events/PostEventView.swift GabayTests/PostEventViewModelTests.swift
git commit -m "Rebuild the organizer form with inline field validation"
```

---

## What this slice does not fix

Named here so the final review does not re-litigate them and so Slice 4 keeps its scope:

- `routeSummary` is still duplicated between `PostEventView` and `EventDetailView`, still renders 45 minutes as "~0h 45m", and is still hardcoded English. Audit finding I8, scheduled for Slice 4.
- `PostEventViewModel.pickGPX(at:)` still does not call `startAccessingSecurityScopedResource()`, so a GPX picked from iCloud Drive or Files still fails to read, and it still stores the URL and re-reads it at submit time after the scope is gone. Audit finding I1, scheduled for Slice 4. This slice moves where that failure is displayed, from an alert to an inline error, but does not change whether it happens.
- Server-supplied per-field validation messages. The backend can already reject a field, but `APIError` carries no field detail until Slice 2, so those errors still surface as the whole-form `InlineErrorText`.
- `MyEventsView` and `EventsListView` are untouched. Neither has a form.

## Self-Review

**Spec coverage.** Slice 1 of the spec names seven components plus the inline-validation requirement. `FieldContainer`, `AppTextField`, `EmailField`, `PasswordField`, `DateField` and `AlertState` are Tasks 1 to 3 and are applied in Tasks 4 to 6. `PickerField` is deliberately deferred with a reason recorded under Scope, because no field on the three named screens is a choice from a list, and the spec's own global constraint set treats unused code as a defect. This is the one place the plan departs from the spec text, and it is flagged rather than silent. The inline-per-field-validation requirement is met on sign-up (two rules) and the organizer form (five rules), and deliberately not on sign-in, with the account-lockout reasoning recorded.

**Placeholder scan.** No "TBD", "TODO", "handle edge cases" or "similar to Task N". Every code step carries the full file contents rather than a diff fragment, because the implementer of Task 6 may not have read Task 1.

**Type consistency.** `AlertState.notice` is defined in Task 3 and called in Task 6 with the same two-argument shape. `String.isValidEmail` is defined in Task 1 and called in Task 5. `DateField`'s explicit initializer order (`label`, `date`, `format`, `placeholder`, `error`, `isRequired`, `isEnabled`, `range`) matches its call in Task 6, which passes `label`, `date`, `format`, `isRequired`. `AppTextField`'s memberwise order (`text`, `placeholder`, `label`, `error`, `isRequired`, `keyboard`, `capitalization`, `contentType`, `disableAutocorrection`, `submitLabel`) matches every call in Tasks 4 to 6. `gpxErrorMessage`, `submitErrorMessage`, `feeError`, `capacityError`, `joinURLError` and `photoURLError` are each defined in Task 6 Step 3 and consumed in Task 6 Step 4. `signInErrorMessage` and `signUpErrorMessage` are defined and consumed within Tasks 4 and 5 respectively.

**Signatures verified against the real code, not assumed.** `Session(auth:tokenStore:)`, `StubAuthenticating`, `StubTokenStore`, `EventDraft`'s ten-argument initializer, `EventFetching.create(_:)` and `uploadGPX(eventID:fileURL:distanceM:ascentM:estimatedMinutes:)`, `RouteStats.distanceM/ascentM/estimatedMinutes`, `LoadFailure.isUserFacing`, and every `Theme` token used by the ported components were each read from the current `events-platform` tree while writing this plan. All 14 ported type names were checked against the whole of `Gabay/` and `GabayTests/` and matched nothing, so no file basename or type name in this plan collides.
